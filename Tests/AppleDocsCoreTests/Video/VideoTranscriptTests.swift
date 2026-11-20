import Foundation
import Testing

@testable import AppleDocsCore

@Suite("VideoTranscript")
struct VideoTranscriptTests {

  @Suite("Path Parsing")
  struct PathParsing {
    @Test("Parses valid video path with prefix")
    func validPathWithPrefix() throws {
      let (collection, videoId, url) = try VideoTranscript.parseVideoPath(
        "videos/play/wwdc2024/10001")
      #expect(collection == "wwdc2024")
      #expect(videoId == "10001")
      #expect(url.absoluteString == "https://developer.apple.com/videos/play/wwdc2024/10001/")
    }

    @Test("Parses valid video path without prefix")
    func validPathWithoutPrefix() throws {
      let (collection, videoId, _) = try VideoTranscript.parseVideoPath("wwdc2023/10142")
      #expect(collection == "wwdc2023")
      #expect(videoId == "10142")
    }

    @Test("Parses path with leading slashes")
    func leadingSlashes() throws {
      let (collection, videoId, _) = try VideoTranscript.parseVideoPath(
        "///videos/play/wwdc2024/10001")
      #expect(collection == "wwdc2024")
      #expect(videoId == "10001")
    }

    @Test("Parses path with trailing slash")
    func trailingSlash() throws {
      let (collection, videoId, _) = try VideoTranscript.parseVideoPath("wwdc2024/10001/")
      #expect(collection == "wwdc2024")
      #expect(videoId == "10001")
    }

    @Test("Rejects empty path")
    func emptyPath() {
      #expect(throws: AppleDocsError.self) {
        try VideoTranscript.parseVideoPath("")
      }
    }

    @Test("Rejects path with only collection")
    func onlyCollection() {
      #expect(throws: AppleDocsError.self) {
        try VideoTranscript.parseVideoPath("wwdc2024")
      }
    }

    @Test("Rejects path with too many segments")
    func tooManySegments() {
      #expect(throws: AppleDocsError.self) {
        try VideoTranscript.parseVideoPath("wwdc2024/10001/extra/segment")
      }
    }
  }

  @Suite("Title Extraction")
  struct TitleExtraction {
    @Test("Extracts title from HTML with Apple video suffix")
    func titleWithSuffix() {
      let html =
        "<html><head><title>What's new in SwiftUI - Videos - Apple Developer</title></head><body></body></html>"
      let title = VideoTranscript.extractVideoTitleFromHtml(html: html)
      #expect(title == "What's new in SwiftUI")
    }

    @Test("Extracts title without Apple video suffix")
    func titleWithoutSuffix() {
      let html = "<html><head><title>Custom Video Title</title></head><body></body></html>"
      let title = VideoTranscript.extractVideoTitleFromHtml(html: html)
      #expect(title == "Custom Video Title")
    }

    @Test("Returns nil for missing title")
    func missingTitle() {
      let html = "<html><head></head><body></body></html>"
      let title = VideoTranscript.extractVideoTitleFromHtml(html: html)
      #expect(title == nil)
    }

    @Test("Returns nil for empty title")
    func emptyTitle() {
      let html = "<html><head><title></title></head><body></body></html>"
      let title = VideoTranscript.extractVideoTitleFromHtml(html: html)
      #expect(title == nil)
    }
  }

  @Suite("Transcript Line Extraction")
  struct TranscriptLineExtraction {
    @Test("Extracts transcript lines from fixture HTML")
    func fixtureExtraction() throws {
      let fixtureURL = Bundle.module.url(
        forResource: "video-transcript", withExtension: "html", subdirectory: "Fixtures")!
      let html = try String(contentsOf: fixtureURL, encoding: .utf8)

      let lines = VideoTranscript.extractTranscriptLinesFromHtml(html: html)
      #expect(lines.count == 5)
      #expect(lines[0].startSeconds == 0.5)
      #expect(lines[0].text == "Welcome to What's new in SwiftUI.")
      #expect(lines[1].startSeconds == 3.2)
      #expect(lines[3].startSeconds == 62.0)
      #expect(lines[4].startSeconds == 125.5)
    }

    @Test("Returns empty for HTML without transcript section")
    func noTranscriptSection() {
      let html = "<html><body><p>No transcript here</p></body></html>"
      let lines = VideoTranscript.extractTranscriptLinesFromHtml(html: html)
      #expect(lines.isEmpty)
    }

    @Test("Returns empty for transcript section without spans")
    func noSpans() {
      let html = """
        <html><body>
        <section id="transcript-content">
        <p>No spans here</p>
        </section>
        </body></html>
        """
      let lines = VideoTranscript.extractTranscriptLinesFromHtml(html: html)
      #expect(lines.isEmpty)
    }

    @Test("Skips spans with empty text")
    func emptySpanText() {
      let html = """
        <html><body>
        <section id="transcript-content">
        <span data-start="1.0">   </span>
        <span data-start="2.0">Valid text</span>
        </section>
        </body></html>
        """
      let lines = VideoTranscript.extractTranscriptLinesFromHtml(html: html)
      #expect(lines.count == 1)
      #expect(lines[0].text == "Valid text")
    }

    @Test("Collapses whitespace in span text")
    func whitespaceCollapsing() {
      let html = """
        <html><body>
        <section id="transcript-content">
        <span data-start="1.0">Hello    world   from    here</span>
        </section>
        </body></html>
        """
      let lines = VideoTranscript.extractTranscriptLinesFromHtml(html: html)
      #expect(lines.count == 1)
      #expect(lines[0].text == "Hello world from here")
    }
  }

  @Suite("Timestamp Formatting")
  struct TimestampFormatting {
    @Test("Formats zero seconds")
    func zero() {
      #expect(VideoTranscript.formatTimestamp(seconds: 0) == "00:00")
    }

    @Test("Formats seconds under a minute")
    func underAMinute() {
      #expect(VideoTranscript.formatTimestamp(seconds: 30) == "00:30")
    }

    @Test("Formats exactly one minute")
    func oneMinute() {
      #expect(VideoTranscript.formatTimestamp(seconds: 60) == "01:00")
    }

    @Test("Formats mixed minutes and seconds")
    func mixed() {
      #expect(VideoTranscript.formatTimestamp(seconds: 125.5) == "02:05")
    }

    @Test("Formats large values")
    func largeValue() {
      #expect(VideoTranscript.formatTimestamp(seconds: 3661) == "61:01")
    }

    @Test("Handles negative values as zero")
    func negative() {
      #expect(VideoTranscript.formatTimestamp(seconds: -5) == "00:00")
    }

    @Test("Truncates fractional seconds")
    func fractional() {
      #expect(VideoTranscript.formatTimestamp(seconds: 5.9) == "00:05")
    }
  }

  @Suite("Markdown Rendering")
  struct MarkdownRendering {
    @Test("Renders complete transcript markdown")
    func completeRendering() {
      let lines: [VideoTranscript.TranscriptLine] = [
        .init(startSeconds: 0, text: "Hello everyone."),
        .init(startSeconds: 5.5, text: "Welcome to the session."),
        .init(startSeconds: 65.0, text: "Let's get started."),
      ]

      let result = VideoTranscript.renderVideoTranscriptMarkdown(
        title: "Test Video",
        sourceUrl: "https://developer.apple.com/videos/play/wwdc2024/10001/",
        collection: "wwdc2024",
        videoId: "10001",
        transcriptLines: lines
      )

      #expect(result.contains("title: Test Video"))
      #expect(result.contains("# Test Video"))
      #expect(result.contains("**Collection:** wwdc2024"))
      #expect(result.contains("**Video:** 10001"))
      #expect(result.contains("## Transcript"))
      #expect(result.contains("- [00:00] Hello everyone."))
      #expect(result.contains("- [00:05] Welcome to the session."))
      #expect(result.contains("- [01:05] Let's get started."))
      #expect(result.contains("---"))
      #expect(result.contains("swift-developer-docs-mcp"))
    }
  }

  @Suite("Code Samples")
  struct CodeSamples {
    private static func loadFixture(_ name: String) throws -> String {
      let fixtureURL = Bundle.module.url(
        forResource: name, withExtension: "html", subdirectory: "Fixtures")!
      return try String(contentsOf: fixtureURL, encoding: .utf8)
    }

    private static func mockFetcher(html: String) -> @Sendable (URL) async throws -> (
      Data, URLResponse
    ) {
      { url in
        let response = HTTPURLResponse(
          url: url, statusCode: 200, httpVersion: nil,
          headerFields: ["Content-Type": "text/html; charset=utf-8"])!
        return (Data(html.utf8), response)
      }
    }

    @Test("Extracts code samples with titles and start times from a session page")
    func extractsFromSessionPage() throws {
      let html = try Self.loadFixture("wwdc2026-271")
      let samples = VideoTranscript.extractCodeSamplesFromHtml(html: html)

      #expect(samples.count == 3)
      #expect(samples[0].title == "Add reorderable to the preview")
      #expect(samples[0].startSeconds == 220)
      #expect(samples[1].title == "Add reorder container to the GameView")
      #expect(samples[1].startSeconds == 280)
      #expect(samples[2].title == "Add reorderable to PileView")
      #expect(samples[2].startSeconds == 358)

      let preview = samples[0]
      #expect(preview.code.hasPrefix("#Preview {\n    @Previewable @State var cards = ["))
      #expect(preview.code.hasSuffix("    .background(.green.gradient)\n}"))
      #expect(!preview.code.contains("<span"))
      #expect(preview.code.contains(".reorderContainer(for: CardValue.self) { difference in"))
    }

    @Test("Decodes HTML entities in code")
    func decodesHtmlEntities() {
      let html = """
        <li class="supplement sample-code" data-supplement-id="sample-code">
          <section>
            <ul>
              <li class="sample-code-main-container">
                <p>0:05 - <a class="jump-to-time-sample" data-start-time="5">Compare &amp; swap</a></p>
                <pre class="code-source"><code><span class="syntax-keyword">let</span> ok <span class="syntax-operator">=</span> a &lt; b &amp;&amp; b &gt; c</code></pre>
              </li>
            </ul>
          </section>
        </li>
        """

      let samples = VideoTranscript.extractCodeSamplesFromHtml(html: html)
      #expect(samples.count == 1)
      #expect(samples[0].title == "Compare & swap")
      #expect(samples[0].startSeconds == 5)
      #expect(samples[0].code == "let ok = a < b && b > c")
    }

    @Test("Returns no code samples for a session page with an empty Code tab")
    func emptyCodeTab() throws {
      let html = try Self.loadFixture("wwdc2026-101")
      #expect(VideoTranscript.extractCodeSamplesFromHtml(html: html).isEmpty)
    }

    @Test("Returns no code samples for a page without a Code tab")
    func noCodeTab() {
      let html =
        "<section id=\"transcript-content\"><span data-start=\"1.0\">Hi</span></section>"
      #expect(VideoTranscript.extractCodeSamplesFromHtml(html: html).isEmpty)
    }

    @Test("Renders code samples after the transcript")
    func rendersAfterTranscript() async throws {
      let html = try Self.loadFixture("wwdc2026-271")
      let markdown = try await VideoTranscript.fetchVideoTranscriptMarkdown(
        path: "videos/play/wwdc2026/271/",
        fetcher: Self.mockFetcher(html: html)
      )

      #expect(markdown.contains("# Code-along: Build powerful drag and drop in SwiftUI - WWDC26"))
      #expect(
        markdown.contains(
          [
            "- [00:19] Since iOS 16, SwiftUI has provided drag and drop",
            "",
            "## Code",
            "",
            "### [03:40] Add reorderable to the preview",
            "",
            "```swift",
            "#Preview {",
          ].joined(separator: "\n")))
      #expect(
        markdown.contains(
          ["    .background(.green.gradient)", "}", "```", "", "### [04:40] Add reorder"].joined(
            separator: "\n")))
      #expect(markdown.contains("### [05:58] Add reorderable to PileView"))
      #expect(
        markdown.range(of: "## Code")!.lowerBound
          < markdown.range(of: "*Generated by")!.lowerBound)
    }

    @Test("Leaves the output unchanged for a session without code samples")
    func unchangedWithoutCodeSamples() async throws {
      let html = try Self.loadFixture("wwdc2026-101")
      let markdown = try await VideoTranscript.fetchVideoTranscriptMarkdown(
        path: "videos/play/wwdc2026/101/",
        fetcher: Self.mockFetcher(html: html)
      )

      #expect(!markdown.contains("## Code"))
      #expect(
        markdown.contains(
          "- [00:31] and welcome to WWDC.\n\n---\n\n*Generated by [swift-developer-docs-mcp]"))
    }

    @Test("Uses a longer fence when the code contains backticks")
    func longerFenceForBackticks() async throws {
      let html = """
        <title>Raw identifiers - WWDC26 - Videos - Apple Developer</title>
        <section id="transcript-content"><span data-start="1.0">Hello.</span></section>
        <li class="supplement sample-code">
          <section>
            <ul>
              <li class="sample-code-main-container">
                <p>Raw identifiers</p>
                <pre class="code-source"><code>/// ```swift
        func `test something`() {}</code></pre>
              </li>
            </ul>
          </section>
        </li>
        """

      let markdown = try await VideoTranscript.fetchVideoTranscriptMarkdown(
        path: "videos/play/wwdc2026/999/",
        fetcher: Self.mockFetcher(html: html)
      )

      #expect(
        markdown.contains(
          "### Raw identifiers\n\n````swift\n/// ```swift\nfunc `test something`() {}\n````\n"))
    }

  }
}
