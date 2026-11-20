import Foundation
import Testing

@testable import swift_developer_docs_mcp

@Suite("MCP Tool Parity")
struct MCPToolParityTests {
  @Test("Same resolved path does not add a notice")
  func samePathOmitsNotice() {
    let blocks = FetchAppleDocumentationTool.referenceDocumentationBlocks(
      markdown: "# Canvas",
      requestedPath: "examplekit/canvas",
      resolvedPath: "examplekit/canvas"
    )

    #expect(blocks == ["# Canvas"])
  }

  @Test("Case-only path differences do not add a notice")
  func caseOnlyPathOmitsNotice() {
    let blocks = FetchAppleDocumentationTool.referenceDocumentationBlocks(
      markdown: "# Canvas",
      requestedPath: "ExampleKit/Canvas",
      resolvedPath: "examplekit/canvas"
    )

    #expect(blocks == ["# Canvas"])
  }

  @Test("A different resolved path puts the notice first")
  func otherPathPutsNoticeFirst() {
    let blocks = FetchAppleDocumentationTool.referenceDocumentationBlocks(
      markdown: "# draw(in:options:)",
      requestedPath: "examplekit/canvas/draw(in:)",
      resolvedPath: "examplekit/canvas/draw(in:options:)"
    )

    #expect(blocks.count == 2)
    #expect(
      blocks[0]
        == "No page exists at /documentation/examplekit/canvas/draw(in:). This is the page at /documentation/examplekit/canvas/draw(in:options:)."
    )
    #expect(blocks[1] == "# draw(in:options:)")
  }

  @Test("Tool descriptions name the documentation URLs")
  func toolDescriptions() {
    #expect(
      SearchAppleDocumentationTool().description
        == "Search Apple Developer documentation (https://developer.apple.com/documentation) and return structured results"
    )
    #expect(
      FetchAppleDocumentationTool().description
        == "Fetch a page of Apple Developer documentation (https://developer.apple.com/documentation) or the Human Interface Guidelines (https://developer.apple.com/design/human-interface-guidelines) by path and return it as Markdown"
    )
    #expect(
      FetchExternalDocumentationTool().description
        == "Fetch a page from a public Swift-DocC documentation site (https://www.swift.org/documentation/docc/) by absolute HTTPS URL and return it as Markdown"
    )
    #expect(
      FetchAppleVideoTranscriptTool().description
        == "Fetch the transcript of an Apple Developer video (https://developer.apple.com/videos) by path and return it as Markdown, followed by the session's code samples when it has any"
    )
  }

  @Test("Tool names stay exactly as listed")
  func toolNames() {
    #expect(SearchAppleDocumentationTool().name == "searchAppleDocumentation")
    #expect(FetchAppleDocumentationTool().name == "fetchAppleDocumentation")
    #expect(FetchExternalDocumentationTool().name == "fetchExternalDocumentation")
    #expect(FetchAppleVideoTranscriptTool().name == "fetchAppleVideoTranscript")
  }

  @Test("Tool titles and hints match upstream sosumi.ai")
  func toolTitlesAndHints() {
    let search = SearchAppleDocumentationTool()
    #expect(search.annotations.title == "Search Apple Documentation")
    #expect(search.annotations.readOnly == true)
    #expect(search.annotations.destructive == false)
    #expect(search.annotations.idempotent == true)
    #expect(search.annotations.openWorld == true)

    let fetch = FetchAppleDocumentationTool()
    #expect(fetch.annotations.title == "Fetch Apple Documentation")
    #expect(fetch.annotations.readOnly == true)
    #expect(fetch.annotations.destructive == false)
    #expect(fetch.annotations.idempotent == true)
    #expect(fetch.annotations.openWorld == true)

    let external = FetchExternalDocumentationTool()
    #expect(external.annotations.title == "Fetch External Documentation")
    #expect(external.annotations.readOnly == true)
    #expect(external.annotations.destructive == false)
    #expect(external.annotations.idempotent == true)
    #expect(external.annotations.openWorld == true)

    let video = FetchAppleVideoTranscriptTool()
    #expect(video.annotations.title == "Fetch Apple Video Transcript")
    #expect(video.annotations.readOnly == true)
    #expect(video.annotations.destructive == false)
    #expect(video.annotations.idempotent == true)
    #expect(video.annotations.openWorld == true)
  }

  @Test("Parameter descriptions match the upstream texts")
  func parameterDescriptions() throws {
    let schemas = try AppleDocsMCPServer().toolInputSchemas()

    #expect(
      schemas["searchAppleDocumentation"]?.contains("Search query for Apple documentation") == true
    )
    #expect(
      schemas["fetchAppleDocumentation"]?.contains(
        "Documentation path (e.g., '/documentation/swift', '/documentation/swiftui/view', '/design/human-interface-guidelines/foundations/color')"
      ) == true)
    #expect(
      schemas["fetchExternalDocumentation"]?.contains(
        "External Swift-DocC URL (e.g., 'https://swiftlang.github.io/swift-docc-plugin/documentation/swiftdoccplugin')"
      ) == true)
    #expect(
      schemas["fetchAppleVideoTranscript"]?.contains(
        "Apple video path (e.g., '/videos/play/wwdc2021/10133' or '/videos/play/meet-with-apple/208')"
      ) == true)
  }

  @Test("Instructions include the conformance guidance")
  func instructionsIncludeConformanceGuidance() {
    let instructions = AppleDocsMCPServer().instructions

    #expect(instructions.contains("conformance conditions"))
    #expect(instructions.contains(".swiftinterface"))
    #expect(instructions.contains("Conforms when `Element` conforms to `Hashable`."))
    #expect(!instructions.contains("Sosumi"))
  }
}
