import Foundation

public enum AppleDocsActions {

  public struct SearchOutput: Sendable {
    public let formatted: String
    public let json: String
  }

  public static func search(query: String) async throws -> SearchOutput {
    let response = try await AppleDocsSearcher.search(query: query)

    if response.results.isEmpty {
      return SearchOutput(
        formatted: "No results found for '\(query)'",
        json: "{}"
      )
    }

    var text = "Found \(response.results.count) results for '\(query)':\n\n"
    for (i, result) in response.results.enumerated() {
      text += "\(i + 1). **\(result.title)**\n"
      text += "   URL: \(result.url)\n"
      if !result.description.isEmpty {
        text += "   \(result.description)\n"
      }
      if !result.breadcrumbs.isEmpty {
        text += "   Path: \(result.breadcrumbs.joined(separator: " > "))\n"
      }
      if !result.tags.isEmpty {
        text += "   Tags: \(result.tags.joined(separator: ", "))\n"
      }
      text += "\n"
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let jsonData = try encoder.encode(response)
    let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

    return SearchOutput(formatted: text, json: jsonString)
  }

  public enum FetchError: Error, LocalizedError {
    case invalidPath
    case insufficientContent(path: String)

    public var errorDescription: String? {
      switch self {
      case .invalidPath:
        "Invalid path. Expected format: swift/array"
      case .insufficientContent(let path):
        "Insufficient content returned for path: \(path)"
      }
    }
  }

  public static func fetch(path: String) async throws -> String {
    let normalized = URLUtilities.normalizeDocumentationPath(path)
    guard !normalized.isEmpty else {
      throw FetchError.invalidPath
    }

    let sourceURL = URLUtilities.generateAppleDocURL(normalized)
    let jsonData = try await Fetcher.fetchJSONData(path: normalized)
    let markdown = DocumentRenderer.renderFromJSON(jsonData, sourceURL: sourceURL)

    if markdown.count < DocumentRenderer.minContentLength {
      throw FetchError.insufficientContent(path: normalized)
    }

    return markdown
  }
}
