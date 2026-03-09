import Foundation
import Testing

@testable import AppleDocsCore

/// Tests for CLI router logic.
///
/// CLIRouter and CLICommand live in the executable target (`swift-developer-docs-mcp`)
/// which depends on FastMCP and Hummingbird. The test target only links AppleDocsCore,
/// so we cannot `@testable import swift_developer_docs_mcp` to test CLIRouter directly.
///
/// Instead, we test the routing logic that CLIRouter delegates to:
/// `AppleDocsClient.resolveFetchEndpoint` dispatches to the correct handler based on
/// the resolved endpoint prefix, which is equivalent to testing that the router
/// dispatches to the correct command.
///
/// Mapped from sosumi.ai `tests/cli-endpoints.test.ts` -> `parseCliArgs` and routing.
@Suite("CLI Router Logic (via AppleDocsClient)")
struct CLIRouterTests {

  // MARK: - Dispatch routing (equivalent to "Router dispatches to correct command")

  @Suite("Dispatch routing via unifiedFetch")
  struct DispatchRouting {

    @Test("Routes documentation input to fetch handler")
    func dispatchesToFetch() async throws {
      nonisolated(unsafe) var handler = ""

      let client = AppleDocsClient(
        fetch: { _ in
          handler = "fetch"
          return "ok"
        },
        search: { _ in .init(formatted: "", json: "") },
        fetchHIG: { _ in
          handler = "hig"
          return "ok"
        },
        fetchHIGTableOfContents: {
          handler = "hig-toc"
          return "ok"
        },
        fetchVideo: { _ in
          handler = "video"
          return "ok"
        },
        fetchExternal: { _ in
          handler = "external"
          return "ok"
        }
      )

      _ = try await client.unifiedFetch(input: "swift/array")
      #expect(handler == "fetch")
    }

    @Test("Routes video input to video handler")
    func dispatchesToVideo() async throws {
      nonisolated(unsafe) var handler = ""

      let client = AppleDocsClient(
        fetch: { _ in
          handler = "fetch"
          return "ok"
        },
        search: { _ in .init(formatted: "", json: "") },
        fetchHIG: { _ in
          handler = "hig"
          return "ok"
        },
        fetchHIGTableOfContents: {
          handler = "hig-toc"
          return "ok"
        },
        fetchVideo: { _ in
          handler = "video"
          return "ok"
        },
        fetchExternal: { _ in
          handler = "external"
          return "ok"
        }
      )

      _ = try await client.unifiedFetch(input: "/videos/play/wwdc2024/10001")
      #expect(handler == "video")
    }

    @Test("Routes HIG input to HIG handler")
    func dispatchesToHIG() async throws {
      nonisolated(unsafe) var handler = ""

      let client = AppleDocsClient(
        fetch: { _ in
          handler = "fetch"
          return "ok"
        },
        search: { _ in .init(formatted: "", json: "") },
        fetchHIG: { _ in
          handler = "hig"
          return "ok"
        },
        fetchHIGTableOfContents: {
          handler = "hig-toc"
          return "ok"
        },
        fetchVideo: { _ in
          handler = "video"
          return "ok"
        },
        fetchExternal: { _ in
          handler = "external"
          return "ok"
        }
      )

      _ = try await client.unifiedFetch(
        input: "design/human-interface-guidelines/color")
      #expect(handler == "hig")
    }

    @Test("Routes HIG root to HIG table of contents handler")
    func dispatchesToHIGTableOfContents() async throws {
      nonisolated(unsafe) var handler = ""

      let client = AppleDocsClient(
        fetch: { _ in
          handler = "fetch"
          return "ok"
        },
        search: { _ in .init(formatted: "", json: "") },
        fetchHIG: { _ in
          handler = "hig"
          return "ok"
        },
        fetchHIGTableOfContents: {
          handler = "hig-toc"
          return "ok"
        },
        fetchVideo: { _ in
          handler = "video"
          return "ok"
        },
        fetchExternal: { _ in
          handler = "external"
          return "ok"
        }
      )

      _ = try await client.unifiedFetch(
        input: "/design/human-interface-guidelines")
      #expect(handler == "hig-toc")
    }

    @Test("Routes external URL to external handler")
    func dispatchesToExternal() async throws {
      nonisolated(unsafe) var handler = ""

      let client = AppleDocsClient(
        fetch: { _ in
          handler = "fetch"
          return "ok"
        },
        search: { _ in .init(formatted: "", json: "") },
        fetchHIG: { _ in
          handler = "hig"
          return "ok"
        },
        fetchHIGTableOfContents: {
          handler = "hig-toc"
          return "ok"
        },
        fetchVideo: { _ in
          handler = "video"
          return "ok"
        },
        fetchExternal: { _ in
          handler = "external"
          return "ok"
        }
      )

      _ = try await client.unifiedFetch(
        input: "https://apple.github.io/swift-argument-parser/documentation/argumentparser")
      #expect(handler == "external")
    }
  }

  // MARK: - Unknown subcommand equivalent (resolveFetchEndpoint error for bad input)

  @Suite("Unknown or invalid input handling")
  struct UnknownInputHandling {

    @Test("Invalid video path throws (equivalent to unknown subcommand returning false)")
    func invalidVideoPathThrows() {
      #expect(throws: AppleDocsError.self) {
        try AppleDocsClient.resolveFetchEndpoint("/videos/play/")
      }
    }

    @Test("Unsupported Apple URL throws")
    func unsupportedAppleURL() {
      #expect(throws: AppleDocsError.self) {
        try AppleDocsClient.resolveFetchEndpoint(
          "https://developer.apple.com/xcode/")
      }
    }
  }

  // MARK: - resolveFetchEndpoint correctly strips trailing slashes

  @Suite("Path normalization")
  struct PathNormalization {

    @Test("Strips trailing slash from video URL")
    func videoURLTrailingSlash() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint(
        "https://developer.apple.com/videos/play/wwdc2021/10133/")
      #expect(result == "/videos/play/wwdc2021/10133")
    }

    @Test("Strips trailing slash from HIG path")
    func higTrailingSlash() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint(
        "/design/human-interface-guidelines/")
      #expect(result == "/design/human-interface-guidelines")
    }
  }
}
