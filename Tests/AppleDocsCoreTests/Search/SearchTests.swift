import Foundation
import Testing

@testable import AppleDocsCore

@Suite("Search Parser Tests")
struct SearchTests {

  private struct SearchDiffEvent: Encodable {
    struct Diff: Encodable {
      let append: String
      let removeLast: Int
    }

    let kind = "search"
    let diff: Diff
  }

  private func loadFixture(_ name: String) throws -> String {
    let fixtureURL = Bundle.module.url(
      forResource: name, withExtension: nil, subdirectory: "Fixtures")!
    return try String(contentsOf: fixtureURL, encoding: .utf8)
  }

  @Test("Parses search results from fixture HTML")
  func parseSearchResultsFromFixture() throws {
    let html = try loadFixture("search-results.html")
    let results = try AppleDocsSearcher.parseSearchResults(html: html)

    #expect(results.count == 4)
  }

  @Test("Extracts documentation type from CSS class")
  func extractDocumentationType() throws {
    let html = try loadFixture("search-results.html")
    let results = try AppleDocsSearcher.parseSearchResults(html: html)

    #expect(results[0].type == "documentation")
    #expect(results[1].type == "documentation")
    #expect(results[2].type == "general")
    #expect(results[3].type == "other")
  }

  @Test("Extracts title and URL correctly")
  func extractTitleAndURL() throws {
    let html = try loadFixture("search-results.html")
    let results = try AppleDocsSearcher.parseSearchResults(html: html)

    #expect(results[0].title == "View")
    #expect(results[0].url == "https://developer.apple.com/documentation/swiftui/view")

    // Already absolute URL should remain unchanged
    #expect(results[1].title == "ViewModifier")
    #expect(results[1].url == "https://developer.apple.com/documentation/swiftui/viewmodifier")
  }

  @Test("Prepends base URL to relative hrefs")
  func prependBaseURLToRelativeHrefs() throws {
    let html = try loadFixture("search-results.html")
    let results = try AppleDocsSearcher.parseSearchResults(html: html)

    // First result has relative href "/documentation/swiftui/view"
    #expect(results[0].url.hasPrefix("https://developer.apple.com"))
    // Third result has relative href "/tutorials/swiftui"
    #expect(results[2].url == "https://developer.apple.com/tutorials/swiftui")
  }

  @Test("Extracts description")
  func extractDescription() throws {
    let html = try loadFixture("search-results.html")
    let results = try AppleDocsSearcher.parseSearchResults(html: html)

    #expect(results[0].description == "A type that represents part of your app's user interface.")
    #expect(results[2].description == "SwiftUI is a modern way to declare user interfaces.")
  }

  @Test("Extracts breadcrumbs")
  func extractBreadcrumbs() throws {
    let html = try loadFixture("search-results.html")
    let results = try AppleDocsSearcher.parseSearchResults(html: html)

    #expect(results[0].breadcrumbs == ["SwiftUI", "Views"])
    #expect(results[1].breadcrumbs == ["SwiftUI"])
    #expect(results[2].breadcrumbs == ["Tutorials"])
  }

  @Test("Extracts tags from spans and language items")
  func extractTags() throws {
    let html = try loadFixture("search-results.html")
    let results = try AppleDocsSearcher.parseSearchResults(html: html)

    #expect(results[0].tags == ["Swift"])
    #expect(results[1].tags == ["Swift", "Protocol"])
    #expect(results[2].tags.isEmpty)
  }

  @Test("Returns empty results for HTML without search results")
  func emptyResultsForNoSearchResults() throws {
    let html = "<html><body><p>No results</p></body></html>"
    let results = try AppleDocsSearcher.parseSearchResults(html: html)

    #expect(results.isEmpty)
  }

  @Test("Formats search summary with Sosumi-compatible text output")
  func formatSearchSummary() {
    let response = SearchResponse(
      query: "SwiftUI View",
      results: [
        SearchResult(
          title: "View",
          url: "https://developer.apple.com/documentation/swiftui/view",
          description: "A type that represents part of your app's user interface.",
          breadcrumbs: ["SwiftUI", "Views"],
          tags: ["Swift"],
          type: "documentation"
        )
      ]
    )

    let formatted = AppleDocsActions.formatSearchResponse(response)

    #expect(
      formatted
        == """
        Found 1 result(s) for "SwiftUI View":

        1. View
           https://developer.apple.com/documentation/swiftui/view
           A type that represents part of your app's user interface.
        """
    )
  }

  @Test("Formats empty search results with quoted query")
  func formatEmptySearchSummary() {
    let response = SearchResponse(query: "missing symbol", results: [])
    #expect(
      AppleDocsActions.formatSearchResponse(response) == "No results found for \"missing symbol\"")
  }

  @Test("Encodes empty search responses as structured JSON")
  func encodeEmptySearchResponse() throws {
    let response = SearchResponse(query: "missing symbol", results: [])
    let json = try AppleDocsActions.encodeSearchResponse(response)
    #expect(json.contains("\"query\""))
    #expect(json.contains("\"missing symbol\""))
    #expect(json.contains("\"results\""))
  }

  @Test("Decodes structured search output from JSON payload")
  func decodeStructuredSearchOutput() throws {
    let response = SearchResponse(
      query: "SwiftUI View",
      results: [
        SearchResult(
          title: "View",
          url: "https://developer.apple.com/documentation/swiftui/view",
          description: "A type that represents part of your app's user interface.",
          breadcrumbs: ["SwiftUI", "Views"],
          tags: ["Swift"],
          type: "documentation"
        )
      ]
    )
    let json = try AppleDocsActions.encodeSearchResponse(response)
    let output = AppleDocsClient.SearchOutput(
      formatted: AppleDocsActions.formatSearchResponse(response),
      json: json
    )

    let decoded = try #require(output.response)
    #expect(decoded.query == "SwiftUI View")
    #expect(decoded.results.count == 1)
    #expect(decoded.results[0].title == "View")
    #expect(decoded.results[0].breadcrumbs == ["SwiftUI", "Views"])
  }

  @Test("Skips results without title or href")
  func skipResultsWithoutTitleOrHref() throws {
    let html = """
      <html><body><ul>
      <li class="search-result documentation">
        <a class="click-analytics-result" href="">
        </a>
      </li>
      <li class="search-result documentation">
        <a class="other-class" href="/documentation/foo">Foo</a>
      </li>
      </ul></body></html>
      """
    let results = try AppleDocsSearcher.parseSearchResults(html: html)
    #expect(results.isEmpty)
  }

  @Test("Parses JSONL quickSearch results and streamed search diffs")
  func parseQueryJSONL() throws {
    let streamed = """
      {"results":[{"excerpt":"An interface for describing the evolution of a schema","value":{"metadata":{"title":"SchemaMigrationPlan","permalink":"https://developer.apple.com/documentation/swiftdata/schemamigrationplan","description":"An interface for describing the evolution of a schema and how to migrate between specific versions.","hierarchy":"SwiftData > SchemaMigrationPlan","kind":"symbol","metadataKind":"documentation"},"origin":"documentation"}},{"excerpt":"Learn how to use schema macros","value":{"metadata":{"titles":["Model your schema with SwiftData"],"permalinks":["https://developer.apple.com/videos/play/wwdc2023/10195"],"descriptions":["Learn how to use schema macros and migration plans with SwiftData."],"projectNames":["WWDC23"],"itemTypes":["Video"],"deliveryLanguageCodes":["eng"],"metadataKind":"developer"},"origin":"developerWWDC"}},{"excerpt":"","value":{"metadata":{"title":"Swift.org - The Swift Programming Language","sourceURL":"https://www.swift.org/documentation/","description":"Documentation for the Swift programming language.","metadataKind":"webPage"},"origin":"swift"}}]}
      """
    let payload = """
      {"kind":"quickSearch","response":{"results":[{"metadata":{"title":"SchemaMigrationPlan","permalink":"https://developer.apple.com/documentation/swiftdata/schemamigrationplan","description":"An interface for describing the evolution of a schema and how to migrate between specific versions.","hierarchy":"SwiftData > SchemaMigrationPlan","kind":"symbol","metadataKind":"documentation"},"origin":"documentation"},{"metadata":{"title":"Get Started - SwiftUI","sourceURL":"https://developer.apple.com/swiftui/get-started/","description":"SwiftUI provides everything you need to begin designing.","metadataKind":"webPage"},"origin":"developerWeb"}]}}
      {"kind":"quickSearchFinished"}

      \(try searchDiffLines(for: streamed))
      {"kind":"searchFinished"}
      """

    let results = try AppleDocsSearcher.parseSearchServicePayload(payload)

    #expect(results.count == 4)
    #expect(results[0].title == "SchemaMigrationPlan")
    #expect(
      results[0].url == "https://developer.apple.com/documentation/swiftdata/schemamigrationplan")
    #expect(
      results[0].description
        == "An interface for describing the evolution of a schema and how to migrate between specific versions."
    )
    #expect(results[0].breadcrumbs == ["SwiftData", "SchemaMigrationPlan"])
    #expect(results[0].tags == ["symbol"])
    #expect(results[0].type == "documentation")

    #expect(results[1].title == "Get Started - SwiftUI")
    #expect(results[1].url == "https://developer.apple.com/swiftui/get-started/")
    #expect(results[1].description == "SwiftUI provides everything you need to begin designing.")
    #expect(results[1].breadcrumbs.isEmpty)
    #expect(results[1].tags.isEmpty)
    #expect(results[1].type == "general")

    #expect(results[2].title == "Model your schema with SwiftData")
    #expect(results[2].url == "https://developer.apple.com/videos/play/wwdc2023/10195")
    #expect(
      results[2].description == "Learn how to use schema macros and migration plans with SwiftData."
    )
    #expect(results[2].breadcrumbs == ["WWDC23"])
    #expect(results[2].tags == ["Video", "eng"])
    #expect(results[2].type == "video")

    #expect(results[3].title == "Swift.org - The Swift Programming Language")
    #expect(results[3].url == "https://www.swift.org/documentation/")
    #expect(results[3].description == "Documentation for the Swift programming language.")
    #expect(results[3].breadcrumbs.isEmpty)
    #expect(results[3].tags.isEmpty)
    #expect(results[3].type == "general")
  }

  @Test("Skips event kinds other than quickSearch and search")
  func skipsUnrequestedEventKinds() throws {
    let payload = """
      {"kind":"ask","response":{"results":[{"metadata":{"title":"Generated answer","permalink":"https://developer.apple.com/generated","metadataKind":"documentation"},"origin":"documentation"}]}}
      {"kind":"quickSearch","response":{"results":[{"metadata":{"title":"WKWebView","permalink":"https://developer.apple.com/documentation/webkit/wkwebview","description":"An object that displays interactive web content.","hierarchy":"WebKit > WKWebView","kind":"symbol","metadataKind":"documentation"},"origin":"documentation"}]}}
      {"kind":"quickSearchFinished"}
      {"kind":"searchFinished"}
      null
      []
      """

    let results = try AppleDocsSearcher.parseSearchServicePayload(payload)

    #expect(results.count == 1)
    #expect(results[0].title == "WKWebView")
    #expect(results[0].breadcrumbs == ["WebKit", "WKWebView"])
    #expect(results[0].tags == ["symbol"])
    #expect(results[0].type == "documentation")
  }

  @Test("removeLast counts UTF-16 code units")
  func removeLastCountsUTF16CodeUnits() throws {
    let marked = "e\u{0301}"
    #expect(marked.count == 1)
    #expect(marked.utf16.count == 2)

    let prefix = "{\"results\":[{\"metadata\":{\"title\":\"\(marked)"
    let suffix =
      "\",\"permalink\":\"https://example.com/a\",\"metadataKind\":\"documentation\"}}]}"
    let payload = """
      \(try encode(SearchDiffEvent(diff: .init(append: prefix, removeLast: 0))))
      \(try encode(SearchDiffEvent(diff: .init(append: suffix, removeLast: 1))))
      """

    let results = try AppleDocsSearcher.parseSearchServicePayload(payload)

    #expect(results.count == 1)
    #expect(results[0].title == "e")
    #expect(results[0].url == "https://example.com/a")
    #expect(results[0].type == "documentation")
  }

  @Test("Returns an empty result set when the service reports no matches")
  func emptyResultsWhenNothingMatches() throws {
    let payload = """
      {"kind":"quickSearch","response":{"results":[]}}
      {"kind":"quickSearchFinished"}
      {"kind":"searchFinished"}
      """
    let results = try AppleDocsSearcher.parseSearchServicePayload(payload)
    #expect(results.isEmpty)
  }

  @Test("Returns an empty result set when the results array is omitted")
  func emptyResultsWhenResultsArrayOmitted() throws {
    let payload = #"{"kind":"quickSearch","response":{"featuredResults":[]}}"#
    let results = try AppleDocsSearcher.parseSearchServicePayload(payload)
    #expect(results.isEmpty)
  }

  @Test("A non-2xx response throws")
  func nonSuccessStatusThrows() {
    for status in [199, 300, 404, 500] {
      do {
        _ = try AppleDocsSearcher.parseSearchServicePayload("not json", statusCode: status)
        Issue.record("Expected status \(status) to throw")
      } catch {
        #expect(error.localizedDescription == "Search request failed: \(status)")
      }
    }
  }

  @Test("A 2xx response with an empty result list does not throw")
  func successStatusReturnsResults() throws {
    let payload = #"{"kind":"quickSearch","response":{"results":[]}}"#
    let results = try AppleDocsSearcher.parseSearchServicePayload(payload, statusCode: 201)
    #expect(results.isEmpty)
  }

  @Test("Invalid JSON throws")
  func invalidJSONThrows() {
    do {
      _ = try AppleDocsSearcher.parseSearchServicePayload("not json")
      Issue.record("Expected invalid JSON to throw")
    } catch {
      #expect(error.localizedDescription == "Search response was not valid JSON")
    }
  }

  @Test("Splits lines only at line feeds")
  func lineSeparatorInsideString() throws {
    let payload =
      "{\"kind\":\"quickSearch\",\"response\":{\"results\":[{\"metadata\":{\"title\":\"A\u{2028}B\",\"permalink\":\"https://example.com/a\",\"metadataKind\":\"documentation\"}}]}}\r\n{\"kind\":\"quickSearchFinished\"}\n"

    let results = try AppleDocsSearcher.parseSearchServicePayload(payload)

    #expect(results.count == 1)
    #expect(results.first?.title == "A\u{2028}B")
  }

  @Test("Resolves Apple target result locales")
  func resolveTargetResultLocale() {
    let cases: [(String, String)] = [
      ("en", "en"),
      ("en-US-u-hc-h23", "en"),
      ("zh-CN", "zh-CN"),
      ("ja-JP", "ja-JP"),
      ("ko-KR", "ko-KR"),
      ("fr-FR", "fr-FR"),
      ("de-DE", "de-DE"),
      ("pt-BR", "pt-BR"),
      ("es-LA", "es-lamr"),
      ("es-419", "es-lamr"),
      ("it-IT", "it-IT"),
      ("zh-Hans-CN", "zh-CN"),
      ("ja-JP-posix", "ja-JP"),
      ("sv-SE", "en"),
      ("", "en"),
      ("nope", "en"),
    ]
    for (identifier, expected) in cases {
      #expect(
        AppleDocsSearcher.resolveTargetResultLocale(identifier) == expected,
        "locale \(identifier)"
      )
    }
  }

  private func searchDiffLines(for serialized: String) throws -> String {
    let units = Array(serialized.utf16)
    let midpoint = units.count / 2
    let head = try utf16Slice(units, from: 0, to: midpoint)
    let tail = try utf16Slice(units, from: midpoint, to: units.count)
    let speculative = "PARTIAL"
    let events = [
      SearchDiffEvent(diff: .init(append: head, removeLast: 0)),
      SearchDiffEvent(diff: .init(append: speculative, removeLast: 0)),
      SearchDiffEvent(diff: .init(append: tail, removeLast: speculative.utf16.count)),
    ]
    return try events.map(encode).joined(separator: "\n")
  }

  private func encode<T: Encodable>(_ value: T) throws -> String {
    let data = try JSONEncoder().encode(value)
    return String(decoding: data, as: UTF8.self)
  }

  private func utf16Slice(_ units: [UInt16], from start: Int, to end: Int) throws -> String {
    if start == end { return "" }
    let slice = Array(units[start..<end])
    return try #require(
      slice.withUnsafeBufferPointer { buffer in
        guard let baseAddress = buffer.baseAddress else { return nil }
        return String(utf16CodeUnits: baseAddress, count: buffer.count)
      })
  }
}
