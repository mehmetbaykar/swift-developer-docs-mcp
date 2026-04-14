import Foundation
import SwiftSoup

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public struct SearchResult: Codable, Sendable {
  public let title: String
  public let url: String
  public let description: String
  public let breadcrumbs: [String]
  public let tags: [String]
  public let type: String

  public init(
    title: String, url: String, description: String,
    breadcrumbs: [String], tags: [String], type: String
  ) {
    self.title = title
    self.url = url
    self.description = description
    self.breadcrumbs = breadcrumbs
    self.tags = tags
    self.type = type
  }
}

public struct SearchResponse: Codable, Sendable {
  public let query: String
  public let results: [SearchResult]

  public init(query: String, results: [SearchResult]) {
    self.query = query
    self.results = results
  }
}

public struct AppleDocsSearcher: Sendable {

  private struct SearchStreamEvent: Decodable {
    let type: String
    let data: [SearchResultEnvelope]?
  }

  private struct SearchResultEnvelope: Decodable {
    let documentation: DocumentationEntry?
    let developer: DeveloperEntry?
    let devsite: DevsiteEntry?
  }

  private struct DocumentationEntry: Decodable {
    let metadata: DocumentationMetadata
  }

  private struct DocumentationMetadata: Decodable {
    let title: String
    let availability: String?
    let permalink: String
    let description: String?
    let hierarchy: String?
    let kind: String?
  }

  private struct DeveloperEntry: Decodable {
    let metadata: DeveloperMetadata
  }

  private struct DeveloperMetadata: Decodable {
    let titles: [String]?
    let descriptions: [String]?
    let permalinks: [String]?
    let itemTypes: [String]?
    let projectNames: [String]?
  }

  private struct DevsiteEntry: Decodable {
    let metadata: DevsiteMetadata
  }

  private struct DevsiteMetadata: Decodable {
    let title: String
    let description: String?
    let sourceURL: String
  }

  public static func search(query: String) async throws -> SearchResponse {
    guard let url = URL(string: "https://developer.apple.com/search/services/search.php") else {
      throw AppleDocsError.invalidURL("https://developer.apple.com/search/services/search.php")
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue(Fetcher.randomUserAgent(), forHTTPHeaderField: "User-Agent")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode([
      "q": query,
      "targetResultLocale": "en",
    ])

    let (data, response) = try await URLSession.shared.data(for: request)

    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
      throw AppleDocsError.httpError(
        statusCode: httpResponse.statusCode, url: url.absoluteString)
    }

    guard let payload = String(data: data, encoding: .utf8) else {
      return SearchResponse(query: query, results: [])
    }

    let results = try parseSearchEvents(payload)
    return SearchResponse(query: query, results: results)
  }

  static func parseSearchEvents(_ payload: String) throws -> [SearchResult] {
    let decoder = JSONDecoder()

    for line in payload.split(whereSeparator: \.isNewline) {
      let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { continue }

      let event = try decoder.decode(
        SearchStreamEvent.self, from: Data(trimmed.utf8))

      guard event.type == "results", let items = event.data else { continue }
      return items.compactMap(normalizeSearchResult)
    }

    return []
  }

  private static func normalizeSearchResult(_ item: SearchResultEnvelope) -> SearchResult? {
    if let documentation = item.documentation?.metadata {
      var breadcrumbs = ["Documentation"]
      if let hierarchy = documentation.hierarchy?.trimmingCharacters(in: .whitespacesAndNewlines),
        !hierarchy.isEmpty
      {
        breadcrumbs.append(
          contentsOf: hierarchy.split(separator: ">").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
          }.filter { !$0.isEmpty })
      }

      var tags: [String] = []
      if let kind = documentation.kind {
        switch kind {
        case "sampleCode":
          tags.append("Sample Code")
        case "article":
          tags.append("Article")
        case "symbol":
          tags.append("Symbol")
        default:
          tags.append(kind)
        }
      }

      if let availability = documentation.availability {
        let lowered = availability.lowercased()
        if lowered.contains("deprecated") { tags.append("Deprecated") }
        if lowered.contains("beta") { tags.append("Beta") }
      }

      return SearchResult(
        title: documentation.title,
        url: documentation.permalink,
        description: documentation.description ?? "",
        breadcrumbs: breadcrumbs,
        tags: tags,
        type: documentation.kind == "sampleCode" ? "sample_code" : "documentation"
      )
    }

    if let developer = item.developer?.metadata {
      let itemType = developer.itemTypes?.first ?? "Video"
      let normalizedType: String
      switch itemType {
      case "Session", "Special Event", "Video":
        normalizedType = "video"
      case "Lab by Appointment", "Get-Together":
        normalizedType = "lab"
      default:
        normalizedType = "developer"
      }

      var tags: [String] = []
      if !itemType.isEmpty { tags.append(itemType) }
      if let projectName = developer.projectNames?.first, !projectName.isEmpty {
        tags.append(projectName)
      }

      guard let title = developer.titles?.first,
        let url = developer.permalinks?.first,
        !title.isEmpty, !url.isEmpty
      else {
        return nil
      }

      return SearchResult(
        title: title,
        url: url,
        description: developer.descriptions?.first ?? "",
        breadcrumbs: [],
        tags: tags,
        type: normalizedType
      )
    }

    if let devsite = item.devsite?.metadata {
      return SearchResult(
        title: devsite.title,
        url: devsite.sourceURL,
        description: devsite.description ?? "",
        breadcrumbs: [],
        tags: [],
        type: "general"
      )
    }

    return nil
  }

  public static func parseSearchResults(html: String) throws -> [SearchResult] {
    let doc = try SwiftSoup.parse(html)
    let searchResultElements = try doc.select("li.search-result")
    var results: [SearchResult] = []

    for element in searchResultElements {
      let className = try element.className()

      // Extract result type from CSS class
      let type: String
      if className.contains("documentation") {
        type = "documentation"
      } else if className.contains("general") {
        type = "general"
      } else {
        type = "other"
      }

      // Extract title and URL from the result link
      guard let link = try element.select("a.click-analytics-result").first() else {
        continue
      }

      var href = try link.attr("href")
      let title = try link.text().trimmingCharacters(in: .whitespacesAndNewlines)

      guard !href.isEmpty, !title.isEmpty else { continue }

      if href.hasPrefix("/") {
        href = "https://developer.apple.com\(href)"
      }

      // Extract description
      let description =
        try element.select("p.result-description").first()?.text()
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

      // Extract breadcrumbs
      let breadcrumbElements = try element.select("li.breadcrumb-list-item")
      let breadcrumbs: [String] = try breadcrumbElements.compactMap { bc in
        let text = try bc.text().trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
      }

      // Extract tags (from both span inside result-tag and language tags)
      let tagElements = try element.select("li.result-tag span, li.result-tag.language")
      let tags: [String] = try tagElements.compactMap { tag in
        let text = try tag.text().trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
      }

      results.append(
        SearchResult(
          title: title,
          url: href,
          description: description,
          breadcrumbs: breadcrumbs,
          tags: tags,
          type: type
        ))
    }

    return results
  }
}
