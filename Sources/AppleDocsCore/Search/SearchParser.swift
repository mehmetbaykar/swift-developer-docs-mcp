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

public enum SearchServiceError: Error, Equatable, CustomStringConvertible, LocalizedError, Sendable
{
  case requestFailed(statusCode: Int)
  case invalidJSON

  public var description: String {
    switch self {
    case .requestFailed(let statusCode):
      return "Search request failed: \(statusCode)"
    case .invalidJSON:
      return "Search response was not valid JSON"
    }
  }

  public var errorDescription: String? { description }
}

public struct AppleDocsSearcher: Sendable {

  private static let searchServiceURL = "https://devintserv.msc.sbz.apple.com/api/v1/query"
  private static let includedResponses = ["quickSearch", "search"]
  private static let defaultTargetResultLocale = "en"
  private static let targetResultLocaleByBaseName: [String: String] = [
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

  private struct SearchQueryBody: Encodable {
    let text: String
    let targetResultLocale: String
    let includedResponses: [String]
  }

  public static func search(query: String) async throws -> SearchResponse {
    guard let url = URL(string: searchServiceURL) else {
      throw AppleDocsError.invalidURL(searchServiceURL)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/jsonl", forHTTPHeaderField: "Accept")
    request.setValue("https://developer.apple.com", forHTTPHeaderField: "Origin")
    request.setValue("https://developer.apple.com/search/", forHTTPHeaderField: "Referer")
    request.setValue(Fetcher.randomUserAgent(), forHTTPHeaderField: "User-Agent")
    request.httpBody = try JSONEncoder().encode(
      SearchQueryBody(
        text: query,
        targetResultLocale: resolveTargetResultLocale(Locale.current.identifier(.bcp47)),
        includedResponses: includedResponses
      ))

    let (data, response) = try await URLSession.shared.data(for: request)
    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
    let payload = String(decoding: data, as: UTF8.self)
    let results = try parseSearchServicePayload(payload, statusCode: statusCode)
    return SearchResponse(query: query, results: results)
  }

  static func parseSearchServicePayload(_ payload: String, statusCode: Int = 200) throws
    -> [SearchResult]
  {
    guard (200..<300).contains(statusCode) else {
      throw SearchServiceError.requestFailed(statusCode: statusCode)
    }
    return extractSearchResults(try readSearchResponseItems(payload))
  }

  static func resolveTargetResultLocale(_ identifier: String) -> String {
    let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return defaultTargetResultLocale }
    let normalized = trimmed.replacingOccurrences(of: "_", with: "-")
    guard let parsed = parseUnicodeLocale(normalized) else { return defaultTargetResultLocale }

    if let match = targetResultLocaleByBaseName[parsed.baseName] {
      return match
    }
    let languageRegion = parsed.region.map { "\(parsed.language)-\($0)" } ?? parsed.language
    if let match = targetResultLocaleByBaseName[languageRegion] {
      return match
    }
    if let match = targetResultLocaleByBaseName[parsed.language] {
      return match
    }
    return defaultTargetResultLocale
  }

  private static func readSearchResponseItems(_ payload: String) throws -> [JSONValue] {
    var items: [JSONValue] = []
    var streamedSearch: [UInt16] = []

    for line in payload.unicodeScalars.split(separator: "\n") {
      let trimmed = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed.isEmpty { continue }

      let event = try parseJSON(trimmed)
      guard event.isRecord else { continue }

      if stringValue(event.property("kind")) == "quickSearch" {
        items.append(contentsOf: resultsOf(event.property("response") ?? .null))
      } else if stringValue(event.property("kind")) == "search" {
        streamedSearch = applySearchDiff(streamedSearch, diff: event.property("diff") ?? .null)
      }
    }

    if !streamedSearch.isEmpty {
      guard let text = string(fromUTF16: streamedSearch) else {
        throw SearchServiceError.invalidJSON
      }
      items.append(contentsOf: resultsOf(try parseJSON(text)))
    }

    return items
  }

  private static func applySearchDiff(_ buffer: [UInt16], diff: JSONValue) -> [UInt16] {
    guard diff.isRecord else { return buffer }

    let removeLast = utf16RemoveCount(diff.property("removeLast"), bufferCount: buffer.count)
    let append: String
    if case .string(let value) = diff.property("append") {
      append = value
    } else {
      append = ""
    }

    var next = buffer
    if removeLast >= next.count {
      next.removeAll(keepingCapacity: true)
    } else if removeLast > 0 {
      next.removeLast(removeLast)
    }
    next.append(contentsOf: append.utf16)
    return next
  }

  private static func utf16RemoveCount(_ value: JSONValue?, bufferCount: Int) -> Int {
    guard case .number(let number) = value, number.isFinite else { return 0 }
    let truncated = number.rounded(.towardZero)
    if truncated <= 0 { return 0 }
    if truncated >= Double(bufferCount) { return bufferCount }
    return Int(truncated)
  }

  private static func parseJSON(_ text: String) throws -> JSONValue {
    guard let data = text.data(using: .utf8) else {
      throw SearchServiceError.invalidJSON
    }
    do {
      return try JSONDecoder().decode(JSONValue.self, from: data)
    } catch {
      throw SearchServiceError.invalidJSON
    }
  }

  private static func resultsOf(_ container: JSONValue) -> [JSONValue] {
    guard container.isRecord, case .array(let results) = container.property("results") else {
      return []
    }
    return results
  }

  private static func extractSearchResults(_ items: [JSONValue]) -> [SearchResult] {
    var seen: Set<String> = []
    var results: [SearchResult] = []

    for item in items {
      guard let result = normalizeSearchResult(item), !seen.contains(result.url) else { continue }
      seen.insert(result.url)
      results.append(result)
    }

    return results
  }

  private static func normalizeSearchResult(_ item: JSONValue) -> SearchResult? {
    guard let record = unwrapResultValue(item),
      let metadata = record.property("metadata"),
      metadata.isRecord
    else {
      return nil
    }

    if stringValue(metadata.property("metadataKind")) == "documentation" {
      guard let title = stringValue(metadata.property("title")),
        let url = stringValue(metadata.property("permalink"))
      else {
        return nil
      }

      return SearchResult(
        title: title,
        url: url,
        description: stringValue(metadata.property("description")) ?? "",
        breadcrumbs: splitHierarchy(stringValue(metadata.property("hierarchy"))),
        tags: compactStrings([stringValue(metadata.property("kind"))]),
        type: "documentation"
      )
    }

    if stringValue(metadata.property("metadataKind")) == "developer" {
      guard let title = firstString(metadata.property("titles")),
        let url = firstString(metadata.property("permalinks"))
      else {
        return nil
      }

      let itemType = firstString(metadata.property("itemTypes"))
      return SearchResult(
        title: title,
        url: url,
        description: firstString(metadata.property("descriptions")) ?? "",
        breadcrumbs: compactStrings([firstString(metadata.property("projectNames"))]),
        tags: compactStrings([
          itemType,
          firstString(metadata.property("deliveryLanguageCodes")),
        ]),
        type: (itemType ?? "developer").lowercased()
      )
    }

    if stringValue(metadata.property("metadataKind")) == "webPage" {
      guard let title = stringValue(metadata.property("title")),
        let url = stringValue(metadata.property("sourceURL"))
      else {
        return nil
      }

      return SearchResult(
        title: title,
        url: url,
        description: stringValue(metadata.property("description")) ?? "",
        breadcrumbs: [],
        tags: [],
        type: "general"
      )
    }

    return nil
  }

  private static func unwrapResultValue(_ item: JSONValue) -> JSONValue? {
    guard item.isRecord else { return nil }
    if let value = item.property("value"), value.isRecord {
      return value
    }
    return item
  }

  private static func stringValue(_ value: JSONValue?) -> String? {
    guard case .string(let text) = value, !text.isEmpty else { return nil }
    return text
  }

  private static func firstString(_ value: JSONValue?) -> String? {
    guard case .array(let items) = value else { return nil }
    return items.compactMap { stringValue($0) }.first
  }

  private static func splitHierarchy(_ hierarchy: String?) -> [String] {
    guard let hierarchy, !hierarchy.isEmpty else { return [] }
    return hierarchy.components(separatedBy: " > ")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  private static func compactStrings(_ values: [String?]) -> [String] {
    values.compactMap { value in
      guard let value, !value.isEmpty else { return nil }
      return value
    }
  }

  private static func string(fromUTF16 units: [UInt16]) -> String? {
    guard !units.isEmpty else { return "" }
    return units.withUnsafeBufferPointer { buffer in
      guard let baseAddress = buffer.baseAddress else { return nil }
      return String(utf16CodeUnits: baseAddress, count: buffer.count)
    }
  }

  private struct ParsedLocale {
    var language: String
    var script: String?
    var region: String?
    var variants: [String]

    var baseName: String {
      var parts = [language]
      if let script { parts.append(script) }
      if let region { parts.append(region) }
      parts.append(contentsOf: variants)
      return parts.joined(separator: "-")
    }
  }

  private static func parseUnicodeLocale(_ identifier: String) -> ParsedLocale? {
    let subtags = identifier.split(separator: "-", omittingEmptySubsequences: false).map(
      String.init)
    guard let languageTag = subtags.first else { return nil }
    let language = languageTag.lowercased()
    guard isLanguage(language) else { return nil }

    var index = 1
    var script: String?
    var region: String?
    var variants: [String] = []

    if index < subtags.count, isScript(subtags[index]) {
      script = canonicalScript(subtags[index])
      index += 1
    }
    if index < subtags.count, isRegion(subtags[index]) {
      region = canonicalRegion(subtags[index])
      index += 1
    }
    while index < subtags.count, isVariant(subtags[index]) {
      variants.append(subtags[index].lowercased())
      index += 1
    }
    if index < subtags.count {
      guard isSingleton(subtags[index]), index + 1 < subtags.count else { return nil }
    }

    return ParsedLocale(language: language, script: script, region: region, variants: variants)
  }

  private static func isLanguage(_ value: String) -> Bool {
    let count = value.count
    let validLength = count == 2 || count == 3 || (5...8).contains(count)
    return validLength && isASCIILetters(value)
  }

  private static func isScript(_ value: String) -> Bool {
    value.count == 4 && isASCIILetters(value)
  }

  private static func isRegion(_ value: String) -> Bool {
    (value.count == 2 && isASCIILetters(value)) || (value.count == 3 && isASCIIDigits(value))
  }

  private static func isVariant(_ value: String) -> Bool {
    let scalars = value.unicodeScalars
    if (5...8).contains(value.count), scalars.allSatisfy(isASCIIAlphanumeric) {
      return true
    }
    guard value.count == 4, let first = scalars.first, isASCIIDigit(first) else { return false }
    return scalars.dropFirst().allSatisfy(isASCIIAlphanumeric)
  }

  private static func isSingleton(_ value: String) -> Bool {
    guard value.count == 1, let scalar = value.unicodeScalars.first else { return false }
    return isASCIIAlphanumeric(scalar)
  }

  private static func isASCIILetters(_ value: String) -> Bool {
    !value.isEmpty && value.unicodeScalars.allSatisfy { $0.isASCII && Character($0).isLetter }
  }

  private static func isASCIIDigits(_ value: String) -> Bool {
    !value.isEmpty && value.unicodeScalars.allSatisfy(isASCIIDigit)
  }

  private static func isASCIIDigit(_ scalar: Unicode.Scalar) -> Bool {
    scalar.isASCII && scalar.value >= 48 && scalar.value <= 57
  }

  private static func isASCIIAlphanumeric(_ scalar: Unicode.Scalar) -> Bool {
    isASCIIDigit(scalar) || (scalar.isASCII && Character(scalar).isLetter)
  }

  private static func canonicalScript(_ value: String) -> String {
    let lower = value.lowercased()
    guard let first = lower.first else { return lower }
    return first.uppercased() + lower.dropFirst()
  }

  private static func canonicalRegion(_ value: String) -> String {
    value.count == 3 ? value : value.uppercased()
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

private enum JSONValue: Sendable {
  case object([String: JSONValue])
  case array([JSONValue])
  case string(String)
  case number(Double)
  case bool(Bool)
  case null

  var isRecord: Bool {
    switch self {
    case .object, .array:
      return true
    case .string, .number, .bool, .null:
      return false
    }
  }

  func property(_ key: String) -> JSONValue? {
    guard case .object(let fields) = self else { return nil }
    return fields[key]
  }
}

extension JSONValue: Decodable {
  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Double.self) {
      self = .number(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([JSONValue].self) {
      self = .array(value)
    } else if let value = try? container.decode([String: JSONValue].self) {
      self = .object(value)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "Unsupported JSON value")
    }
  }
}
