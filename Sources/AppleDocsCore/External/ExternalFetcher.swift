import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public enum ExternalFetcher: Sendable {
  public static let userAgent = "swift-developer-docs-mcp/1.0"

  // MARK: - URL Construction

  public static func extractExternalDocumentationBasePath(_ url: URL) throws -> String {
    let normalizedPath = url.path.replacingOccurrences(
      of: #"/+$"#, with: "", options: .regularExpression)
    let pattern = #"^(.*?)(\/documentation(?:\/.*)?)$"#

    guard let regex = try? NSRegularExpression(pattern: pattern),
      let match = regex.firstMatch(
        in: normalizedPath, range: NSRange(normalizedPath.startIndex..., in: normalizedPath)),
      let baseRange = Range(match.range(at: 1), in: normalizedPath)
    else {
      throw AppleDocsError.invalidURL(
        "External URL must point to a Swift-DocC documentation path.")
    }

    return String(normalizedPath[baseRange])
  }

  public static func buildExternalDocCJsonUrl(_ sourceUrl: URL) throws -> URL {
    let hostBasePath = try extractExternalDocumentationBasePath(sourceUrl)
    let normalizedPath = sourceUrl.path.replacingOccurrences(
      of: #"/+$"#, with: "", options: .regularExpression)
    let documentationPath = String(normalizedPath.dropFirst(hostBasePath.count))
    let jsonPath =
      documentationPath.hasSuffix(".json")
      ? documentationPath
      : "\(documentationPath).json"

    guard let host = sourceUrl.host, let scheme = sourceUrl.scheme else {
      throw AppleDocsError.invalidURL("Missing host or scheme")
    }

    let urlString = "\(scheme)://\(host)\(hostBasePath)/data\(jsonPath)"
    guard let url = URL(string: urlString) else {
      throw AppleDocsError.invalidURL(urlString)
    }

    return url
  }

  // MARK: - Fetching

  public static func fetchExternalDocCJSON(
    url: URL,
    env: ExternalPolicyEnv = ExternalPolicyEnv(),
    robotsCache: RobotsCache = RobotsCache(),
    fetcher: @escaping @Sendable (_ request: URLRequest) async throws -> (Data, URLResponse) = {
      request in
      try await URLSession.shared.data(for: request)
    }
  ) async throws -> AppleDocJSON {
    let validatedUrl = try ExternalPolicy.validateExternalDocumentationUrl(url.absoluteString)

    // Host policy check (SSRF, allowlist/blocklist)
    try ExternalPolicy.assertHostPolicy(url: validatedUrl, env: env)

    // Robots.txt check with in-flight deduplication
    let robotsAllowed = await RobotsPolicy.isAllowedByRobots(
      url: validatedUrl,
      userAgent: Self.userAgent,
      cache: robotsCache
    ) { robotsUrl in
      var request = URLRequest(url: robotsUrl)
      request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
      request.setValue(
        "text/plain, text/*;q=0.9, */*;q=0.1", forHTTPHeaderField: "Accept")
      return try await fetcher(request)
    }

    if !robotsAllowed {
      throw AppleDocsError.robotsBlocked
    }

    let jsonUrl = try buildExternalDocCJsonUrl(validatedUrl)

    var request = URLRequest(url: jsonUrl)
    request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    let (data, response) = try await fetcher(request)

    if let httpResponse = response as? HTTPURLResponse {
      let xRobotsTag = httpResponse.value(forHTTPHeaderField: "X-Robots-Tag")
      if RobotsPolicy.containsRestrictiveXRobotsTag(xRobotsTag) {
        throw AppleDocsError.robotsBlocked
      }

      if httpResponse.statusCode == 404 {
        throw AppleDocsError.notFound
      }

      if httpResponse.statusCode != 200 {
        throw AppleDocsError.httpError(
          statusCode: httpResponse.statusCode, url: jsonUrl.absoluteString)
      }
    }

    do {
      return try JSONDecoder().decode(AppleDocJSON.self, from: data)
    } catch {
      throw AppleDocsError.decodingError(underlying: error)
    }
  }
}
