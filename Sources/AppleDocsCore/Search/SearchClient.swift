import Foundation

public struct SearchClient: Sendable {
  public var search: @Sendable (_ query: String) async throws -> SearchResponse
  public var parseHTML: @Sendable (_ html: String) throws -> [SearchResult]

  public init(
    search: @escaping @Sendable (String) async throws -> SearchResponse,
    parseHTML: @escaping @Sendable (String) throws -> [SearchResult]
  ) {
    self.search = search
    self.parseHTML = parseHTML
  }
}

extension SearchClient {
  public static let live = SearchClient(
    search: { query in
      try await AppleDocsSearcher.search(query: query)
    },
    parseHTML: { html in
      try AppleDocsSearcher.parseSearchResults(html: html)
    }
  )
}
