import Foundation
import Testing

@testable import AppleDocsCore

@Suite("Search Parser Tests")
struct SearchTests {

  /// A `quickSearch` event followed by a `search` payload split into diff events the way
  /// Apple's backend streams them: each event appends to a buffer after dropping
  /// `removeLast` characters from its end.
  private let jsonlPayload: String = {
    let quickSearch = """
      {"kind":"quickSearch","response":{"results":[{"metadata":{"title":"SchemaMigrationPlan","permalink":"https://developer.apple.com/documentation/swiftdata/schemamigrationplan","description":"An interface for describing the evolution of a schema and how to migrate between specific versions.","hierarchy":"SwiftData > SchemaMigrationPlan","kind":"symbol","metadataKind":"documentation"},"origin":"documentation"},{"metadata":{"title":"Get Started - SwiftUI","sourceURL":"https://developer.apple.com/swiftui/get-started/","description":"SwiftUI provides everything you need to begin designing.","metadataKind":"webPage"},"origin":"developerWeb"}]}}
      """

    let streamedSearch = """
      {"results":[{"excerpt":"An interface for describing the evolution of a schema","value":{"metadata":{"title":"SchemaMigrationPlan","permalink":"https://developer.apple.com/documentation/swiftdata/schemamigrationplan","description":"An interface for describing the evolution of a schema and how to migrate between specific versions.","hierarchy":"SwiftData > SchemaMigrationPlan","kind":"symbol","metadataKind":"documentation"},"origin":"documentation"}},{"excerpt":"Learn how to use schema macros","value":{"metadata":{"titles":["Model your schema with SwiftData"],"permalinks":["https://developer.apple.com/videos/play/wwdc2023/10195"],"descriptions":["Learn how to use schema macros and migration plans with SwiftData."],"projectNames":["WWDC23"],"itemTypes":["Video"],"deliveryLanguageCodes":["eng"],"metadataKind":"developer"},"origin":"developerWWDC"}},{"excerpt":"","value":{"metadata":{"title":"Swift.org - The Swift Programming Language","sourceURL":"https://www.swift.org/documentation/","description":"Documentation for the Swift programming language.","metadataKind":"webPage"},"origin":"swift"}}]}
      """

    let midpoint = streamedSearch.index(streamedSearch.startIndex, offsetBy: streamedSearch.count / 2)
    let head = String(streamedSearch[..<midpoint])
    let tail = String(streamedSearch[midpoint...])

    func diffEvent(append: String, removeLast: Int) -> String {
      let escaped = append
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
      return "{\"kind\":\"search\",\"diff\":{\"append\":\"\(escaped)\",\"removeLast\":\(removeLast)}}"
    }

    return [
      quickSearch,
      "{\"kind\":\"quickSearchFinished\"}",
      "",
      diffEvent(append: head, removeLast: 0),
      diffEvent(append: "PARTIAL", removeLast: 0),
      diffEvent(append: tail, removeLast: "PARTIAL".count),
      "{\"kind\":\"searchFinished\"}",
    ].joined(separator: "\n")
  }()

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

  @Test("Parses the JSONL response from Apple's MSC query backend")
  func parseSearchEventsFromJSONL() throws {
    let results = try AppleDocsSearcher.parseSearchEvents(jsonlPayload)

    // The documentation result appears in both channels and is reported once.
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
    #expect(results[1].breadcrumbs.isEmpty)
    #expect(results[1].tags.isEmpty)
    #expect(results[1].type == "general")

    #expect(results[2].title == "Model your schema with SwiftData")
    #expect(results[2].url == "https://developer.apple.com/videos/play/wwdc2023/10195")
    #expect(
      results[2].description == "Learn how to use schema macros and migration plans with SwiftData.")
    #expect(results[2].breadcrumbs == ["WWDC23"])
    #expect(results[2].tags == ["Video", "eng"])
    #expect(results[2].type == "video")

    #expect(results[3].title == "Swift.org - The Swift Programming Language")
    #expect(results[3].url == "https://www.swift.org/documentation/")
    #expect(results[3].type == "general")
  }

  @Test("Ignores results carried by response kinds that were not requested")
  func ignoresUnrequestedResponseKinds() throws {
    let payload = """
      {"kind":"ask","response":{"results":[{"metadata":{"title":"Generated answer","permalink":"https://developer.apple.com/generated","metadataKind":"documentation"},"origin":"documentation"}]}}
      {"kind":"quickSearch","response":{"results":[{"metadata":{"title":"WKWebView","permalink":"https://developer.apple.com/documentation/webkit/wkwebview","description":"An object that displays interactive web content.","hierarchy":"WebKit > WKWebView","kind":"symbol","metadataKind":"documentation"},"origin":"documentation"}]}}
      """

    let results = try AppleDocsSearcher.parseSearchEvents(payload)

    #expect(results.count == 1)
    #expect(results[0].title == "WKWebView")
  }

  @Test("Returns empty results when Apple search has no matches or omits the results array")
  func emptyJSONLResults() throws {
    let noMatches = """
      {"kind":"quickSearch","response":{"results":[]}}
      {"kind":"quickSearchFinished"}
      {"kind":"searchFinished"}
      """
    #expect(try AppleDocsSearcher.parseSearchEvents(noMatches).isEmpty)

    let noResultsArray = """
      {"kind":"quickSearch","response":{"featuredResults":[]}}
      """
    #expect(try AppleDocsSearcher.parseSearchEvents(noResultsArray).isEmpty)
  }

  @Test("Skips results that lack a title or URL")
  func skipsIncompleteResults() throws {
    let payload = """
      {"kind":"quickSearch","response":{"results":[{"metadata":{"title":"","permalink":"https://developer.apple.com/documentation/foo","metadataKind":"documentation"}},{"metadata":{"titles":["Untitled"],"permalinks":[],"metadataKind":"developer"}},{"metadata":{"title":"Unknown kind","permalink":"https://developer.apple.com/x","metadataKind":"mystery"}}]}}
      """

    #expect(try AppleDocsSearcher.parseSearchEvents(payload).isEmpty)
  }

  @Test("Throws when Apple's backend returns malformed JSONL")
  func throwsOnMalformedJSONL() {
    #expect(throws: AppleDocsError.self) {
      try AppleDocsSearcher.parseSearchEvents("not json")
    }
  }

  @Test("Builds the request body Apple's query endpoint expects")
  func buildsRequestBody() throws {
    let data = try AppleDocsSearcher.makeRequestBody(query: "SchemaMigrationPlan", locale: "en")
    let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

    #expect(body["text"] as? String == "SchemaMigrationPlan")
    #expect(body["targetResultLocale"] as? String == "en")
    #expect(body["includedResponses"] as? [String] == ["quickSearch", "search"])
  }

  @Test("Maps system locales to Apple's accepted target result locales")
  func resolvesTargetResultLocale() {
    #expect(AppleDocsSearcher.resolveTargetResultLocale("en-US-u-hc-h23") == "en")
    #expect(AppleDocsSearcher.resolveTargetResultLocale("en_US") == "en")
    #expect(AppleDocsSearcher.resolveTargetResultLocale("en_GB@calendar=gregorian") == "en")
    #expect(AppleDocsSearcher.resolveTargetResultLocale("ja-JP") == "ja-JP")
    #expect(AppleDocsSearcher.resolveTargetResultLocale("ja_JP.UTF-8") == "ja-JP")
    #expect(AppleDocsSearcher.resolveTargetResultLocale("es-419") == "es-lamr")
    #expect(AppleDocsSearcher.resolveTargetResultLocale("zh-Hans-CN") == "zh-CN")
    #expect(AppleDocsSearcher.resolveTargetResultLocale("nl-NL") == "en")
    #expect(AppleDocsSearcher.resolveTargetResultLocale("C") == "en")
    #expect(AppleDocsSearcher.resolveTargetResultLocale("") == "en")
  }
}
