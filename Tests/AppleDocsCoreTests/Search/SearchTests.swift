import Foundation
import Testing

@testable import AppleDocsCore

@Suite("Search Parser Tests")
struct SearchTests {

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
}
