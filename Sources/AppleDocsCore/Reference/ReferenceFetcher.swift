import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public struct ReferenceFetcher: Sendable {
  public var fetchReferenceDoc: @Sendable (_ path: String) async throws -> Data

  public init(
    fetchReferenceDoc: @escaping @Sendable (String) async throws -> Data
  ) {
    self.fetchReferenceDoc = fetchReferenceDoc
  }
}

extension ReferenceFetcher {
  public static let live = ReferenceFetcher(
    fetchReferenceDoc: { path in
      let normalized = URLUtilities.normalizeDocumentationPath(path)
      let jsonData = try await Fetcher.fetchJSONData(path: normalized)
      let encoder = JSONEncoder()
      return try encoder.encode(jsonData)
    }
  )
}
