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

  public static let searchServiceURL = "https://devintserv.msc.sbz.apple.com/api/v1/query"
  static let includedResponses = ["quickSearch", "search"]
  static let defaultTargetResultLocale = "en"

  private static let targetResultLocales: [String: String] = [
    "en": "en",
    "zh-CN": "zh-CN",
    "ja-JP": "ja-JP",
    "ko-KR": "ko-KR",
    "fr-FR": "fr-FR",
    "de-DE": "de-DE",
    "pt-BR": "pt-BR",
    "es-LA": "es-lamr",
    "es-419": "es-lamr",
    "it-IT": "it-IT",
  ]

  public static func search(query: String) async throws -> SearchResponse {
    guard let url = URL(string: searchServiceURL) else {
      throw AppleDocsError.invalidURL(searchServiceURL)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue(Fetcher.randomUserAgent(), forHTTPHeaderField: "User-Agent")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/jsonl", forHTTPHeaderField: "Accept")
    // The backend rejects requests without a browser-style Origin/Referer pair.
    request.setValue("https://developer.apple.com", forHTTPHeaderField: "Origin")
    request.setValue("https://developer.apple.com/search/", forHTTPHeaderField: "Referer")
    request.httpBody = try makeRequestBody(query: query)

    let (data, response) = try await URLSession.shared.data(for: request)

    if let httpResponse = response as? HTTPURLResponse,
      !(200..<300).contains(httpResponse.statusCode)
    {
      throw AppleDocsError.httpError(
        statusCode: httpResponse.statusCode, url: url.absoluteString)
    }

    guard let payload = String(data: data, encoding: .utf8) else {
      return SearchResponse(query: query, results: [])
    }

    let results = try parseSearchEvents(payload)
    return SearchResponse(query: query, results: results)
  }

  static func makeRequestBody(
    query: String, locale: String = resolveTargetResultLocale()
  ) throws -> Data {
    let body: [String: Any] = [
      "text": query,
      "targetResultLocale": locale,
      "includedResponses": includedResponses,
    ]
    return try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
  }

  static func resolveTargetResultLocale(_ identifier: String = Locale.current.identifier)
    -> String
  {
    var normalized = identifier
    if let at = normalized.firstIndex(of: "@") { normalized = String(normalized[..<at]) }
    if let dot = normalized.firstIndex(of: ".") { normalized = String(normalized[..<dot]) }
    normalized = normalized.replacingOccurrences(of: "_", with: "-")

    let subtags = normalized.split(separator: "-").map(String.init)
    guard let language = subtags.first?.lowercased(), !language.isEmpty,
      language != "c", language != "posix"
    else {
      return defaultTargetResultLocale
    }

    let region = subtags.dropFirst().first { subtag in
      (subtag.count == 2 && subtag.allSatisfy(\.isLetter))
        || (subtag.count == 3 && subtag.allSatisfy(\.isNumber))
    }?.uppercased()

    let languageRegion = region.map { "\(language)-\($0)" } ?? language
    return targetResultLocales[languageRegion]
      ?? targetResultLocales[language]
      ?? defaultTargetResultLocale
  }

  static func parseSearchEvents(_ payload: String) throws -> [SearchResult] {
    var items: [Any] = []
    var streamedSearch = ""

    for line in payload.split(whereSeparator: \.isNewline) {
      let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { continue }

      guard let event = try parseJSON(trimmed) as? [String: Any] else { continue }

      switch event["kind"] as? String {
      case "quickSearch":
        items.append(contentsOf: resultsOf(event["response"]))
      case "search":
        streamedSearch = applySearchDiff(streamedSearch, diff: event["diff"])
      default:
        continue
      }
    }

    if !streamedSearch.isEmpty {
      items.append(contentsOf: resultsOf(try parseJSON(streamedSearch)))
    }

    return extractSearchResults(items)
  }

  private static func applySearchDiff(_ buffer: String, diff: Any?) -> String {
    guard let diff = diff as? [String: Any] else { return buffer }

    let removeLast = (diff["removeLast"] as? NSNumber)?.intValue ?? 0
    let append = diff["append"] as? String ?? ""

    // `removeLast` counts UTF-16 code units (JavaScript string semantics), not Characters.
    let utf16 = Array(buffer.utf16)
    let keptCount = max(0, utf16.count - max(0, removeLast))
    let kept = String(decoding: utf16[..<keptCount], as: UTF16.self)
    return kept + append
  }

  private static func parseJSON(_ text: String) throws -> Any {
    do {
      return try JSONSerialization.jsonObject(with: Data(text.utf8), options: [.fragmentsAllowed])
    } catch {
      throw AppleDocsError.decodingError(
        underlying: NSError(
          domain: "AppleDocsSearcher", code: -1,
          userInfo: [NSLocalizedDescriptionKey: "Search response was not valid JSON"]))
    }
  }

  private static func resultsOf(_ container: Any?) -> [Any] {
    guard let container = container as? [String: Any] else { return [] }
    return container["results"] as? [Any] ?? []
  }

  private static func extractSearchResults(_ items: [Any]) -> [SearchResult] {
    var seen = Set<String>()
    var results: [SearchResult] = []

    for item in items {
      guard let result = normalizeSearchResult(item), !seen.contains(result.url) else { continue }
      seen.insert(result.url)
      results.append(result)
    }

    return results
  }

  static func normalizeSearchResult(_ item: Any) -> SearchResult? {
    guard let record = item as? [String: Any] else { return nil }
    let unwrapped = record["value"] as? [String: Any] ?? record
    guard let metadata = unwrapped["metadata"] as? [String: Any] else { return nil }

    switch metadata["metadataKind"] as? String {
    case "documentation":
      guard let title = stringValue(metadata["title"]),
        let url = stringValue(metadata["permalink"])
      else { return nil }

      return SearchResult(
        title: title,
        url: url,
        description: stringValue(metadata["description"]) ?? "",
        breadcrumbs: splitHierarchy(stringValue(metadata["hierarchy"])),
        tags: [stringValue(metadata["kind"])].compactMap { $0 },
        type: "documentation"
      )

    case "developer":
      guard let title = firstString(metadata["titles"]),
        let url = firstString(metadata["permalinks"])
      else { return nil }

      let itemType = firstString(metadata["itemTypes"])
      return SearchResult(
        title: title,
        url: url,
        description: firstString(metadata["descriptions"]) ?? "",
        breadcrumbs: [firstString(metadata["projectNames"])].compactMap { $0 },
        tags: [itemType, firstString(metadata["deliveryLanguageCodes"])].compactMap { $0 },
        type: (itemType ?? "developer").lowercased()
      )

    case "webPage":
      guard let title = stringValue(metadata["title"]),
        let url = stringValue(metadata["sourceURL"])
      else { return nil }

      return SearchResult(
        title: title,
        url: url,
        description: stringValue(metadata["description"]) ?? "",
        breadcrumbs: [],
        tags: [],
        type: "general"
      )

    default:
      return nil
    }
  }

  private static func stringValue(_ value: Any?) -> String? {
    guard let string = value as? String, !string.isEmpty else { return nil }
    return string
  }

  private static func firstString(_ value: Any?) -> String? {
    guard let array = value as? [Any] else { return nil }
    return array.lazy.compactMap { stringValue($0) }.first
  }

  private static func splitHierarchy(_ hierarchy: String?) -> [String] {
    guard let hierarchy else { return [] }
    return hierarchy.components(separatedBy: " > ")
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
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
