import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public struct HIGFetcher: Sendable {

  private static let higBaseURL = "https://developer.apple.com/tutorials/data"

  // MARK: - Fetching

  public static func fetchHIGTableOfContents() async throws -> HIGTableOfContents {
    let tocUrl = "\(higBaseURL)/index/design--human-interface-guidelines"

    guard let url = URL(string: tocUrl) else {
      throw AppleDocsError.invalidURL(tocUrl)
    }

    var request = URLRequest(url: url)
    request.setValue(Fetcher.randomUserAgent(), forHTTPHeaderField: "User-Agent")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

    let (data, response) = try await URLSession.shared.data(for: request)

    if let httpResponse = response as? HTTPURLResponse {
      if httpResponse.statusCode == 404 {
        throw AppleDocsError.notFound
      }
      if httpResponse.statusCode != 200 {
        throw AppleDocsError.httpError(statusCode: httpResponse.statusCode, url: tocUrl)
      }
    }

    do {
      return try JSONDecoder().decode(HIGTableOfContents.self, from: data)
    } catch {
      throw AppleDocsError.decodingError(underlying: error)
    }
  }

  public static func fetchHIGPageData(path: String) async throws -> HIGPageJSON {
    let normalizedPath =
      path
      .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

    let jsonUrl = "\(higBaseURL)/design/human-interface-guidelines/\(normalizedPath).json"

    guard let url = URL(string: jsonUrl) else {
      throw AppleDocsError.invalidURL(jsonUrl)
    }

    var request = URLRequest(url: url)
    request.setValue(Fetcher.randomUserAgent(), forHTTPHeaderField: "User-Agent")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

    let (data, response) = try await URLSession.shared.data(for: request)

    if let httpResponse = response as? HTTPURLResponse {
      if httpResponse.statusCode == 404 {
        throw AppleDocsError.notFound
      }
      if httpResponse.statusCode != 200 {
        throw AppleDocsError.httpError(statusCode: httpResponse.statusCode, url: jsonUrl)
      }
    }

    do {
      return try JSONDecoder().decode(HIGPageJSON.self, from: data)
    } catch {
      throw AppleDocsError.decodingError(underlying: error)
    }
  }

  // MARK: - Utility

  public static func extractHIGPaths(toc: HIGTableOfContents) -> [String] {
    var paths: [String] = []

    func extractFromItems(_ items: [HIGTocItem]) {
      for item in items {
        let normalizedPath = item.path.replacingOccurrences(
          of: #"^/design/human-interface-guidelines/"#,
          with: "",
          options: .regularExpression
        )
        if !normalizedPath.isEmpty {
          paths.append(normalizedPath)
        }
        if let children = item.children {
          extractFromItems(children)
        }
      }
    }

    extractFromItems(toc.interfaceLanguages.swift)
    return paths
  }

  public static func findHIGItemByPath(
    _ targetPath: String, in toc: HIGTableOfContents
  ) -> HIGTocItem? {
    let normalizedTarget =
      targetPath
      .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

    func searchInItems(_ items: [HIGTocItem]) -> HIGTocItem? {
      for item in items {
        let normalizedItemPath =
          item.path
          .replacingOccurrences(
            of: #"^/design/human-interface-guidelines/"#,
            with: "",
            options: .regularExpression
          )
          .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if normalizedItemPath == normalizedTarget {
          return item
        }

        if let children = item.children {
          if let found = searchInItems(children) {
            return found
          }
        }
      }
      return nil
    }

    return searchInItems(toc.interfaceLanguages.swift)
  }

  public static func getHIGBreadcrumbs(
    for targetPath: String, in toc: HIGTableOfContents
  ) -> [String] {
    let normalizedTarget =
      targetPath
      .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

    func findBreadcrumbs(
      _ items: [HIGTocItem], currentPath: [String] = []
    ) -> [String]? {
      for item in items {
        let normalizedItemPath =
          item.path
          .replacingOccurrences(
            of: #"^/design/human-interface-guidelines/"#,
            with: "",
            options: .regularExpression
          )
          .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        let newPath = currentPath + [item.title]

        if normalizedItemPath == normalizedTarget {
          return newPath
        }

        if let children = item.children {
          if let found = findBreadcrumbs(children, currentPath: newPath) {
            return found
          }
        }
      }
      return nil
    }

    return findBreadcrumbs(toc.interfaceLanguages.swift) ?? []
  }
}
