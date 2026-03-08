import Testing

@testable import AppleDocsCore

@Suite("Fetch Endpoint Resolution")
struct FetchEndpointResolutionTests {

  // MARK: - Documentation Paths

  @Suite("Documentation paths")
  struct DocumentationPaths {
    @Test("Treats bare path as documentation")
    func barePathBecomesDocumentation() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint("swift/array")
      #expect(result.hasPrefix("/documentation/"))
    }

    @Test("Preserves /documentation/ prefix")
    func preservesDocumentationPrefix() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint("/documentation/swift/array")
      #expect(result == "/documentation/swift/array")
    }
  }

  // MARK: - HIG Paths

  @Suite("HIG paths")
  struct HIGPaths {
    @Test("Routes design/human-interface-guidelines to HIG")
    func routesHIGPath() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint(
        "design/human-interface-guidelines/color")
      #expect(result == "/design/human-interface-guidelines/color")
    }

    @Test("Routes /design/human-interface-guidelines root")
    func routesHIGRoot() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint(
        "/design/human-interface-guidelines")
      #expect(result == "/design/human-interface-guidelines")
    }

    @Test("Strips trailing slash from HIG path")
    func stripsTrailingSlashFromHIG() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint(
        "/design/human-interface-guidelines/")
      #expect(result == "/design/human-interface-guidelines")
    }

    @Test("Routes HIG subpath without leading slash")
    func routesHIGSubpath() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint(
        "design/human-interface-guidelines")
      #expect(result == "/design/human-interface-guidelines")
    }
  }

  // MARK: - Video Paths

  @Suite("Video paths")
  struct VideoPaths {
    @Test("Routes /videos/play/ paths")
    func routesVideoPath() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint(
        "/videos/play/wwdc2021/10133")
      #expect(result == "/videos/play/wwdc2021/10133")
    }

    @Test("Routes videos/play/ without leading slash")
    func routesVideoPathNoLeadingSlash() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint(
        "videos/play/wwdc2021/10133")
      #expect(result == "/videos/play/wwdc2021/10133")
    }

    @Test("Strips trailing slash from video path")
    func stripsVideoTrailingSlash() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint(
        "/videos/play/wwdc2021/10133/")
      #expect(result == "/videos/play/wwdc2021/10133")
    }
  }

  // MARK: - External Paths

  @Suite("External paths")
  struct ExternalPaths {
    @Test("Routes /external/ paths")
    func routesExternalPath() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint(
        "/external/https://example.com/docs")
      #expect(result == "/external/https://example.com/docs")
    }
  }

  // MARK: - Full URL handling

  @Suite("Full URL handling")
  struct FullURLHandling {
    @Test("Routes developer.apple.com /documentation/ URLs")
    func routesAppleDocURL() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint(
        "https://developer.apple.com/documentation/swift/array")
      #expect(result == "/documentation/swift/array")
    }

    @Test("Routes developer.apple.com HIG URLs")
    func routesAppleHIGURL() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint(
        "https://developer.apple.com/design/human-interface-guidelines/color")
      #expect(result == "/design/human-interface-guidelines/color")
    }

    @Test("Routes developer.apple.com video URLs")
    func routesAppleVideoURL() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint(
        "https://developer.apple.com/videos/play/wwdc2021/10133/")
      #expect(result == "/videos/play/wwdc2021/10133")
    }

    @Test("Routes non-Apple HTTPS URLs to external")
    func routesExternalURL() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint(
        "https://apple.github.io/swift-argument-parser/documentation/argumentparser")
      #expect(
        result
          == "/external/https://apple.github.io/swift-argument-parser/documentation/argumentparser"
      )
    }

    @Test("Rejects HTTP URLs")
    func rejectsHTTPURL() throws {
      #expect(throws: AppleDocsError.self) {
        try AppleDocsClient.resolveFetchEndpoint(
          "http://developer.apple.com/documentation/swift")
      }
    }
  }

  // MARK: - Edge cases

  @Suite("Edge cases")
  struct EdgeCases {
    @Test("Rejects empty input")
    func rejectsEmpty() throws {
      #expect(throws: AppleDocsError.self) {
        try AppleDocsClient.resolveFetchEndpoint("")
      }
    }

    @Test("Rejects whitespace-only input")
    func rejectsWhitespace() throws {
      #expect(throws: AppleDocsError.self) {
        try AppleDocsClient.resolveFetchEndpoint("   ")
      }
    }

    @Test("Trims whitespace from input")
    func trimsWhitespace() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint("  swift/array  ")
      #expect(result.hasPrefix("/documentation/"))
    }
  }
}
