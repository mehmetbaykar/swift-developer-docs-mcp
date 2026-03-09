import Foundation
import Testing

@testable import AppleDocsCore

/// Tests for the underlying logic that MCP tools delegate to.
///
/// The MCP tool structs (FetchVideoTranscriptTool, SearchAppleDocsTool, etc.)
/// live in the executable target and depend on FastMCP, which is not linked to
/// the test target. Instead we verify the AppleDocsCore functions they call.
///
/// Mapped from sosumi.ai `tests/mcp-tools.test.ts`.
@Suite("MCP Tool Backing Logic")
struct MCPToolTests {

  // MARK: - fetchAppleVideoTranscript backing logic

  @Suite("Video Transcript (fetchAppleVideoTranscript)")
  struct VideoTranscriptToolTests {

    // Matches: "registers and runs fetchAppleVideoTranscript with path input"
    @Test("Parses WWDC path and builds correct URL")
    func parsesWWDCVideoPath() throws {
      let (collection, videoId, url) = try VideoTranscript.parseVideoPath(
        "/videos/play/wwdc2021/10133")
      #expect(collection == "wwdc2021")
      #expect(videoId == "10133")
      #expect(
        url.absoluteString == "https://developer.apple.com/videos/play/wwdc2021/10133/")
    }

    // Matches: "supports non-WWDC /videos/play collections"
    @Test("Supports non-WWDC video collections (meet-with-apple)")
    func nonWWDCCollection() throws {
      let (collection, videoId, url) = try VideoTranscript.parseVideoPath(
        "/videos/play/meet-with-apple/208")
      #expect(collection == "meet-with-apple")
      #expect(videoId == "208")
      #expect(
        url.absoluteString == "https://developer.apple.com/videos/play/meet-with-apple/208/")
    }

    // Matches: "returns a readable error for invalid video path input"
    @Test("Throws for invalid video path with only one segment")
    func invalidVideoPathThrows() {
      #expect(throws: AppleDocsError.self) {
        try VideoTranscript.parseVideoPath("wwdc2021")
      }
    }

    @Test("Invalid video path error is AppleDocsError.invalidPath")
    func invalidVideoPathErrorType() {
      do {
        _ = try VideoTranscript.parseVideoPath("wwdc2021")
        Issue.record("Expected error to be thrown")
      } catch let error as AppleDocsError {
        if case .invalidPath = error {
          // expected
        } else {
          Issue.record("Expected .invalidPath, got \(error)")
        }
      } catch {
        Issue.record("Expected AppleDocsError, got \(error)")
      }
    }

    @Test("Throws for empty video path")
    func emptyVideoPathThrows() {
      #expect(throws: AppleDocsError.self) {
        try VideoTranscript.parseVideoPath("")
      }
    }

    @Test("resolveFetchEndpoint routes WWDC video path correctly")
    func resolveFetchEndpointRoutesVideo() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint(
        "/videos/play/wwdc2021/10133")
      #expect(result == "/videos/play/wwdc2021/10133")
    }

    @Test("resolveFetchEndpoint routes non-WWDC video collection")
    func resolveFetchEndpointRoutesNonWWDC() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint(
        "/videos/play/meet-with-apple/208")
      #expect(result == "/videos/play/meet-with-apple/208")
    }

    @Test("resolveFetchEndpoint throws for malformed video path")
    func resolveFetchEndpointRejectsBadVideo() {
      #expect(throws: AppleDocsError.self) {
        try AppleDocsClient.resolveFetchEndpoint("/videos/play/wwdc2021/")
      }
    }
  }

  // MARK: - fetchAppleDocumentation backing logic

  @Suite("Unified Fetch Routing (fetchAppleDocumentation)")
  struct UnifiedFetchTests {

    @Test("resolveFetchEndpoint routes documentation URL")
    func routesDocumentationURL() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint(
        "https://developer.apple.com/documentation/swift/array")
      #expect(result == "/documentation/swift/array")
    }

    @Test("resolveFetchEndpoint routes external URL")
    func routesExternalURL() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint(
        "https://apple.github.io/swift-argument-parser/documentation/argumentparser")
      #expect(
        result
          == "/external/https://apple.github.io/swift-argument-parser/documentation/argumentparser"
      )
    }

    @Test("resolveFetchEndpoint routes HIG URL")
    func routesHIGURL() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint(
        "https://developer.apple.com/design/human-interface-guidelines/foundations/color")
      #expect(result == "/design/human-interface-guidelines/foundations/color")
    }

    @Test("unifiedFetch dispatches to video handler for video endpoint")
    func unifiedFetchDispatchesVideo() async throws {
      nonisolated(unsafe) var videoCalled = false
      nonisolated(unsafe) var capturedPath = ""

      let client = AppleDocsClient(
        fetch: { _ in "doc" },
        search: { _ in .init(formatted: "", json: "") },
        fetchHIG: { _ in "hig" },
        fetchHIGTableOfContents: { "toc" },
        fetchVideo: { path in
          videoCalled = true
          capturedPath = path
          return "video transcript"
        },
        fetchExternal: { _ in "external" }
      )

      let result = try await client.unifiedFetch(input: "/videos/play/wwdc2024/10001")
      #expect(videoCalled)
      #expect(capturedPath == "videos/play/wwdc2024/10001")
      #expect(result == "video transcript")
    }

    @Test("unifiedFetch dispatches to external handler for external endpoint")
    func unifiedFetchDispatchesExternal() async throws {
      nonisolated(unsafe) var externalCalled = false
      nonisolated(unsafe) var capturedURL = ""

      let client = AppleDocsClient(
        fetch: { _ in "doc" },
        search: { _ in .init(formatted: "", json: "") },
        fetchHIG: { _ in "hig" },
        fetchHIGTableOfContents: { "toc" },
        fetchVideo: { _ in "video" },
        fetchExternal: { url in
          externalCalled = true
          capturedURL = url
          return "external doc"
        }
      )

      let result = try await client.unifiedFetch(
        input: "https://apple.github.io/swift-argument-parser/documentation/argumentparser")
      #expect(externalCalled)
      #expect(
        capturedURL
          == "https://apple.github.io/swift-argument-parser/documentation/argumentparser")
      #expect(result == "external doc")
    }

    @Test("unifiedFetch dispatches to HIG handler for HIG subpath")
    func unifiedFetchDispatchesHIG() async throws {
      nonisolated(unsafe) var higCalled = false
      nonisolated(unsafe) var capturedPath = ""

      let client = AppleDocsClient(
        fetch: { _ in "doc" },
        search: { _ in .init(formatted: "", json: "") },
        fetchHIG: { path in
          higCalled = true
          capturedPath = path
          return "hig content"
        },
        fetchHIGTableOfContents: { "toc" },
        fetchVideo: { _ in "video" },
        fetchExternal: { _ in "external" }
      )

      let result = try await client.unifiedFetch(
        input: "design/human-interface-guidelines/color")
      #expect(higCalled)
      #expect(capturedPath == "color")
      #expect(result == "hig content")
    }

    @Test("unifiedFetch dispatches to HIG TOC for root HIG path")
    func unifiedFetchDispatchesHIGTableOfContents() async throws {
      nonisolated(unsafe) var tocCalled = false

      let client = AppleDocsClient(
        fetch: { _ in "doc" },
        search: { _ in .init(formatted: "", json: "") },
        fetchHIG: { _ in "hig" },
        fetchHIGTableOfContents: {
          tocCalled = true
          return "toc content"
        },
        fetchVideo: { _ in "video" },
        fetchExternal: { _ in "external" }
      )

      let result = try await client.unifiedFetch(
        input: "/design/human-interface-guidelines")
      #expect(tocCalled)
      #expect(result == "toc content")
    }

    @Test("unifiedFetch dispatches to fetch for documentation path")
    func unifiedFetchDispatchesDoc() async throws {
      nonisolated(unsafe) var fetchCalled = false
      nonisolated(unsafe) var capturedPath = ""

      let client = AppleDocsClient(
        fetch: { path in
          fetchCalled = true
          capturedPath = path
          return "doc content"
        },
        search: { _ in .init(formatted: "", json: "") },
        fetchHIG: { _ in "hig" },
        fetchHIGTableOfContents: { "toc" },
        fetchVideo: { _ in "video" },
        fetchExternal: { _ in "external" }
      )

      let result = try await client.unifiedFetch(input: "swift/array")
      #expect(fetchCalled)
      #expect(capturedPath == "swift/array")
      #expect(result == "doc content")
    }
  }

  // MARK: - AppleDocsClient.live existence

  @Suite("Client Live Instance")
  struct ClientLiveTests {
    @Test("AppleDocsClient.live has all required handlers")
    func liveClientExists() {
      let client = AppleDocsClient.live
      // Verify the live client is constructible and its closures exist.
      // We can't call them without network, but we verify the shape.
      _ = client.fetch
      _ = client.search
      _ = client.fetchHIG
      _ = client.fetchHIGTableOfContents
      _ = client.fetchVideo
      _ = client.fetchExternal
    }
  }
}
