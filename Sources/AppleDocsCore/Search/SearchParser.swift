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

  public static func search(query: String) async throws -> SearchResponse {
    let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
    let searchUrl = "https://developer.apple.com/search/?q=\(encoded)"

    guard let url = URL(string: searchUrl) else {
      throw AppleDocsError.invalidURL(searchUrl)
    }

    var request = URLRequest(url: url)
    request.setValue(Fetcher.randomUserAgent(), forHTTPHeaderField: "User-Agent")

    let (data, response) = try await URLSession.shared.data(for: request)

    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
      throw AppleDocsError.httpError(
        statusCode: httpResponse.statusCode, url: searchUrl)
    }

    guard let html = String(data: data, encoding: .utf8) else {
      return SearchResponse(query: query, results: [])
    }

    let results = try parseSearchResults(html: html)
    return SearchResponse(query: query, results: results)
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
