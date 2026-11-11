import Foundation

public struct DocumentationCandidate: Sendable, Equatable {
  public let path: String
  public let title: String

  public init(path: String, title: String) {
    self.path = path
    self.title = title
  }
}

public struct DocumentationPage: Sendable {
  public let path: String
  public let data: AppleDocJSON

  public init(path: String, data: AppleDocJSON) {
    self.path = path
    self.data = data
  }
}

enum DocumentationPageResolver {
  /// How many missing parent paths resolution may correct.
  private static let MAX_PARENT_RESOLUTION_DEPTH = 1

  static func resolve(
    path: String,
    load: @escaping @Sendable (String) async throws -> AppleDocJSON
  ) async throws -> DocumentationPage {
    try await resolveDocumentationPage(
      normalizedPath: URLUtilities.normalizeDocumentationPath(path),
      depth: 0,
      load: load
    )
  }

  private static func resolveDocumentationPage(
    normalizedPath: String,
    depth: Int,
    load: @escaping @Sendable (String) async throws -> AppleDocJSON
  ) async throws -> DocumentationPage {
    do {
      let data = try await load(normalizedPath)
      return DocumentationPage(path: normalizedPath, data: data)
    } catch {
      guard let docsError = error as? AppleDocsError, docsError.isNotFound else {
        throw error
      }
      return try await resolveMissingPage(
        normalizedPath: normalizedPath,
        depth: depth,
        error: docsError,
        load: load
      )
    }
  }

  private static func resolveMissingPage(
    normalizedPath: String,
    depth: Int,
    error: AppleDocsError,
    load: @escaping @Sendable (String) async throws -> AppleDocJSON
  ) async throws -> DocumentationPage {
    let candidates = try await findSymbolCandidates(
      normalizedPath: normalizedPath,
      depth: depth,
      load: load
    )
    if let candidate = selectCandidate(candidates) {
      let data = try await load(candidate.path)
      return DocumentationPage(path: candidate.path, data: data)
    }
    if candidates.count > 1 {
      throw AppleDocsError.documentationNotFound(
        url: notFoundURL(error, path: normalizedPath),
        candidates: candidates
      )
    }
    throw error
  }

  /// The only candidate, or the Swift symbol when every other candidate is its Objective-C counterpart.
  private static func selectCandidate(
    _ candidates: [DocumentationCandidate]
  ) -> DocumentationCandidate? {
    if candidates.count == 1 {
      return candidates[0]
    }

    let swift = candidates.filter {
      $0.path.range(of: #"-swift\.[a-z.]+$"#, options: .regularExpression) != nil
    }
    let objectiveC = candidates.filter {
      $0.path.range(of: #"-c\.[a-z.]+$"#, options: .regularExpression) != nil
    }
    if swift.count == 1 && swift.count + objectiveC.count == candidates.count {
      return swift[0]
    }
    return nil
  }

  private static func findSymbolCandidates(
    normalizedPath: String,
    depth: Int,
    load: @escaping @Sendable (String) async throws -> AppleDocJSON
  ) async throws -> [DocumentationCandidate] {
    var lowercasedPath = normalizedPath.lowercased()
    while lowercasedPath.hasSuffix("/") {
      lowercasedPath.removeLast()
    }
    guard let separator = lowercasedPath.lastIndex(of: "/"),
      lowercasedPath.distance(from: lowercasedPath.startIndex, to: separator) > 0
    else {
      return []
    }

    var parentPath = String(lowercasedPath[..<separator])
    let name = String(lowercasedPath[lowercasedPath.index(after: separator)...])
    if name.isEmpty {
      return []
    }

    let parent: AppleDocJSON
    var parentWasResolved = false
    do {
      parent = try await load(parentPath)
    } catch {
      // A network failure or a 5xx response must not be reported as a missing page.
      guard let docsError = error as? AppleDocsError, docsError.isNotFound else {
        throw error
      }
      if depth >= MAX_PARENT_RESOLUTION_DEPTH {
        return []
      }
      do {
        let resolvedParent = try await resolveMissingPage(
          normalizedPath: parentPath,
          depth: depth + 1,
          error: docsError,
          load: load
        )
        parent = resolvedParent.data
        parentPath = resolvedParent.path.lowercased()
        parentWasResolved = true
      } catch {
        guard let resolutionError = error as? AppleDocsError, resolutionError.isNotFound else {
          throw error
        }
        return []
      }
    }

    // `messages(of:for:)` also matches signatures that add labels,
    // such as `messages(of:for:buffersize:)`.
    let signaturePrefix: String? = name.hasSuffix(":)") ? String(name.dropLast()) : nil
    let parentPrefix = "/documentation/\(parentPath)/"
    var candidates: [DocumentationCandidate] = []
    var seen = Set<String>()
    let references = (parent.references ?? [:]).sorted { $0.key < $1.key }
    for (_, reference) in references {
      guard let rawURL = reference.url else { continue }
      let url = rawURL.lowercased()
      guard url.hasPrefix(parentPrefix) else { continue }
      let component = String(url.dropFirst(parentPrefix.count))
      if component.contains("/") {
        continue
      }

      let matches =
        (parentWasResolved && component == name)
        || component.hasPrefix("\(name)-")
        || (!name.contains("(") && component.hasPrefix("\(name)("))
        || (signaturePrefix.map { component.hasPrefix($0) } ?? false)
      if matches {
        let candidatePath = String(url.dropFirst("/documentation/".count))
        if seen.insert(candidatePath).inserted {
          candidates.append(
            DocumentationCandidate(path: candidatePath, title: reference.title ?? component)
          )
        }
      }
    }
    return candidates
  }

  private static func notFoundURL(_ error: AppleDocsError, path: String) -> String {
    if case .documentationNotFound(let url, _) = error {
      return url
    }
    return "https://developer.apple.com/tutorials/data/documentation/\(path).json"
  }
}
