import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public struct AppleDocsClient: Sendable {
  public var fetch: @Sendable (_ path: String) async throws -> String
  public var search: @Sendable (_ query: String) async throws -> SearchOutput
  public var fetchHIG: @Sendable (_ path: String) async throws -> String
  public var fetchHIGTableOfContents: @Sendable () async throws -> String
  public var fetchVideo: @Sendable (_ path: String) async throws -> String
  public var fetchExternal: @Sendable (_ url: String) async throws -> String

  public init(
    fetch: @escaping @Sendable (String) async throws -> String,
    search: @escaping @Sendable (String) async throws -> SearchOutput,
    fetchHIG: @escaping @Sendable (String) async throws -> String,
    fetchHIGTableOfContents: @escaping @Sendable () async throws -> String,
    fetchVideo: @escaping @Sendable (String) async throws -> String,
    fetchExternal: @escaping @Sendable (String) async throws -> String
  ) {
    self.fetch = fetch
    self.search = search
    self.fetchHIG = fetchHIG
    self.fetchHIGTableOfContents = fetchHIGTableOfContents
    self.fetchVideo = fetchVideo
    self.fetchExternal = fetchExternal
  }

  public struct SearchOutput: Sendable {
    public let formatted: String
    public let json: String

    public var response: SearchResponse? {
      try? JSONDecoder().decode(SearchResponse.self, from: Data(json.utf8))
    }

    public init(formatted: String, json: String) {
      self.formatted = formatted
      self.json = json
    }
  }

  /// Unified fetch that auto-routes based on path pattern:
  /// - `design/human-interface-guidelines` or `design/human-interface-guidelines/...` -> HIG
  /// - `videos/play/...` -> Video transcript
  /// - `external/...` -> External documentation
  /// - Everything else -> Reference documentation
  public func unifiedFetch(input: String) async throws -> String {
    let endpoint = try Self.resolveFetchEndpoint(input)

    if endpoint == "/design/human-interface-guidelines" {
      return try await fetchHIGTableOfContents()
    }

    if endpoint.hasPrefix("/design/human-interface-guidelines/") {
      let higPath = String(
        endpoint.dropFirst("/design/human-interface-guidelines/".count))
      return try await fetchHIG(higPath)
    }

    if endpoint.hasPrefix("/videos/play/") {
      let videoPath = String(endpoint.dropFirst("/".count))
      return try await fetchVideo(videoPath)
    }

    if endpoint.hasPrefix("/external/") {
      let externalUrl = String(endpoint.dropFirst("/external/".count))
      return try await fetchExternal(externalUrl)
    }

    if endpoint.hasPrefix("/documentation/") {
      let docPath = String(endpoint.dropFirst("/documentation/".count))
      return try await fetch(docPath)
    }

    return try await fetch(input)
  }

  /// Resolves user input (URL or path) to a canonical endpoint path.
  public static func resolveFetchEndpoint(_ input: String) throws -> String {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      throw AppleDocsError.invalidPath
    }

    // Handle full URLs
    if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
      guard let url = URL(string: trimmed) else {
        throw AppleDocsError.invalidURL(trimmed)
      }

      guard url.scheme?.lowercased() == "https" else {
        throw AppleDocsError.invalidURL("Only https URLs are supported")
      }

      if url.host?.lowercased() == "developer.apple.com" {
        let pathname = url.path

        if pathname.hasPrefix("/documentation/") {
          return pathname
        }

        if pathname.hasPrefix("/design/human-interface-guidelines") {
          return normalizeHIGPath(pathname)
        }

        if let videoPath = matchVideoPath(pathname) {
          return videoPath
        }

        throw AppleDocsError.invalidURL("Unsupported developer.apple.com URL path: \(pathname)")
      }

      // Non-Apple URL -> external
      return "/external/\(trimmed)"
    }

    // Handle path-style input
    if trimmed.hasPrefix("/documentation/") {
      return trimmed
    }

    if trimmed.hasPrefix("/design/human-interface-guidelines")
      || trimmed.hasPrefix("design/human-interface-guidelines")
    {
      let normalized =
        trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
      return normalizeHIGPath(normalized)
    }

    if trimmed.hasPrefix("/videos/play/") || trimmed.hasPrefix("videos/play/") {
      let normalized =
        trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
      if let videoPath = matchVideoPath(normalized) {
        return videoPath
      }
      throw AppleDocsError.invalidURL(
        "Invalid video path. Expected /videos/play/COLLECTION/VIDEO_ID")
    }

    if trimmed.hasPrefix("/external/") || trimmed.hasPrefix("external/") {
      let normalized =
        trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
      return normalized
    }

    // Default: treat as documentation path
    let normalizedPath = URLUtilities.normalizeDocumentationPath(trimmed)
    return "/documentation/\(normalizedPath)"
  }

  private static func normalizeHIGPath(_ pathname: String) -> String {
    var path = pathname
    if path.hasSuffix("/") {
      path = String(path.dropLast())
    }
    return path
  }

  private static func matchVideoPath(_ pathname: String) -> String? {
    let pattern = #"^/videos/play/([a-zA-Z0-9-]+)/([a-zA-Z0-9-]+)/?$"#
    guard let regex = try? NSRegularExpression(pattern: pattern),
      let match = regex.firstMatch(
        in: pathname, range: NSRange(pathname.startIndex..., in: pathname)),
      let collectionRange = Range(match.range(at: 1), in: pathname),
      let videoIdRange = Range(match.range(at: 2), in: pathname)
    else {
      return nil
    }

    let collection = String(pathname[collectionRange])
    let videoId = String(pathname[videoIdRange])
    return "/videos/play/\(collection)/\(videoId)"
  }
}

extension AppleDocsClient {
  public static let live = AppleDocsClient(
    fetch: { path in
      try await AppleDocsActions.fetch(path: path)
    },
    search: { query in
      try await AppleDocsActions.search(query: query)
    },
    fetchHIG: { path in
      try await AppleDocsActions.fetchHIG(path: path)
    },
    fetchHIGTableOfContents: {
      try await AppleDocsActions.fetchHIGTableOfContents()
    },
    fetchVideo: { path in
      try await AppleDocsActions.fetchVideo(path: path)
    },
    fetchExternal: { url in
      try await AppleDocsActions.fetchExternal(url: url)
    }
  )
}

// MARK: - Legacy static API (backward compatible)

public enum AppleDocsActions {

  public typealias SearchOutput = AppleDocsClient.SearchOutput

  static func formatSearchResponse(_ response: SearchResponse) -> String {
    guard !response.results.isEmpty else {
      return "No results found for \"\(response.query)\""
    }

    let summary = response.results.enumerated().map { index, result in
      """
      \(index + 1). \(result.title)
         \(result.url)
         \(result.description.isEmpty ? "No description" : result.description)
      """
    }.joined(separator: "\n\n")

    return "Found \(response.results.count) result(s) for \"\(response.query)\":\n\n\(summary)"
  }

  static func encodeSearchResponse(_ response: SearchResponse) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let jsonData = try encoder.encode(response)
    return String(data: jsonData, encoding: .utf8) ?? "{}"
  }

  public static func search(query: String) async throws -> SearchOutput {
    let response = try await AppleDocsSearcher.search(query: query)
    let formatted = formatSearchResponse(response)
    let json = try encodeSearchResponse(response)

    return SearchOutput(formatted: formatted, json: json)
  }

  public static func fetch(path: String) async throws -> String {
    let normalized = URLUtilities.normalizeDocumentationPath(path)
    guard !normalized.isEmpty else {
      throw AppleDocsError.invalidPath
    }

    let sourceURL = URLUtilities.generateAppleDocURL(normalized)
    let jsonData = try await Fetcher.fetchJSONData(path: normalized)
    let markdown = DocumentRenderer.renderFromJSON(jsonData, sourceURL: sourceURL)

    if markdown.count < DocumentRenderer.minContentLength {
      throw AppleDocsError.insufficientContent
    }

    return markdown
  }

  public static func fetchHIG(path: String) async throws -> String {
    let toc = try await HIGFetcher.fetchHIGTableOfContents()
    let resolvedPath = HIGPathResolver.resolveHigPathForFetch(path: path, toc: toc)

    do {
      let pageData = try await HIGFetcher.fetchHIGPageData(path: resolvedPath)
      return HIGRenderer.renderHIGFromJSON(data: pageData, path: resolvedPath)
    } catch let error as AppleDocsError where error.isNotFound && resolvedPath != path {
      // Fallback to original path if resolved path fails
      let pageData = try await HIGFetcher.fetchHIGPageData(path: path)
      return HIGRenderer.renderHIGFromJSON(data: pageData, path: path)
    }
  }

  public static func fetchHIGTableOfContents() async throws -> String {
    let toc = try await HIGFetcher.fetchHIGTableOfContents()
    return HIGRenderer.renderHIGTableOfContents(toc: toc)
  }

  public static func fetchVideo(path: String) async throws -> String {
    let markdown = try await VideoTranscript.fetchVideoTranscriptMarkdown(path: path)

    if markdown.trimmingCharacters(in: .whitespacesAndNewlines).count < 100 {
      throw AppleDocsError.insufficientContent
    }

    return markdown
  }

  public static func fetchExternal(url: String) async throws -> String {
    let validatedUrl = try ExternalPolicy.validateExternalDocumentationUrl(url)
    let env = ExternalPolicyEnv(
      hostAllowlist: ProcessInfo.processInfo.environment["EXTERNAL_DOC_HOST_ALLOWLIST"],
      hostBlocklist: ProcessInfo.processInfo.environment["EXTERNAL_DOC_HOST_BLOCKLIST"]
    )

    let jsonData = try await ExternalFetcher.fetchExternalDocCJSON(url: validatedUrl, env: env)
    let markdown = ExternalRenderer.renderExternalDocumentation(
      jsonData: jsonData, sourceUrl: validatedUrl)

    if markdown.trimmingCharacters(in: .whitespacesAndNewlines).count < 100 {
      throw AppleDocsError.insufficientContent
    }

    return markdown
  }
}

// MARK: - AppleDocsError convenience

extension AppleDocsError {
  var isNotFound: Bool {
    if case .notFound = self { return true }
    return false
  }
}
