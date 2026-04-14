import Foundation
import Testing

@testable import AppleDocsCore

@Suite("Search Parser Tests")
struct SearchTests {

  private let streamedResultsPayload = """
    {"type":"results","data":[{"devsite":{"metadata":{"description":"SwiftUI is an innovative, exceptionally simple way to build user interfaces across all Apple platforms with the power of Swift.","title":"SwiftUI","sourceURL":"https://developer.apple.com/swiftui/"}}},{"documentation":{"metadata":{"title":"SwiftUI","availability":"iOS 13.0+ | iPadOS 13.0+ | macOS 10.15+","permalink":"https://developer.apple.com/documentation/swiftui","description":"Declare the user interface and behavior for your app on every platform.","hierarchy":"SwiftUI","kind":"symbol"}}},{"developer":{"metadata":{"itemTypes":["Session"],"titles":["SwiftUI Essentials"],"descriptions":["Take your first deep-dive into building an app with SwiftUI."],"permalinks":["https://developer.apple.com/videos/play/wwdc2019/216"],"projectNames":["WWDC19"]}}}]}
    {"type":"done"}
    """

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

  @Test("Parses streamed search payload from live API shape")
  func parseSearchEventsFromLivePayload() throws {
    let results = try AppleDocsSearcher.parseSearchEvents(streamedResultsPayload)

    #expect(results.count == 3)
    #expect(results[0].title == "SwiftUI")
    #expect(results[0].url == "https://developer.apple.com/swiftui/")
    #expect(results[0].type == "general")

    #expect(results[1].title == "SwiftUI")
    #expect(results[1].url == "https://developer.apple.com/documentation/swiftui")
    #expect(results[1].type == "documentation")
    #expect(results[1].breadcrumbs == ["Documentation", "SwiftUI"])
    #expect(results[1].tags == ["Symbol"])

    #expect(results[2].title == "SwiftUI Essentials")
    #expect(results[2].url == "https://developer.apple.com/videos/play/wwdc2019/216")
    #expect(results[2].type == "video")
    #expect(results[2].tags == ["Session", "WWDC19"])
  }
}
