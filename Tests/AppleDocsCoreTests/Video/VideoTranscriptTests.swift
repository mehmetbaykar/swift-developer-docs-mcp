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
}
