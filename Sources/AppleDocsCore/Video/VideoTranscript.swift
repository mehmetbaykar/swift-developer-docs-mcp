import Foundation
import SwiftSoup

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public enum VideoTranscript: Sendable {
  private static let appleVideoSuffix = " - Videos - Apple Developer"

  public struct TranscriptLine: Sendable, Equatable {
    public let startSeconds: Double
    public let text: String

    public init(startSeconds: Double, text: String) {
      self.startSeconds = startSeconds
      self.text = text
    }
  }

  public static func fetchVideoTranscriptMarkdown(
    path: String,
    fetcher: @Sendable (_ url: URL) async throws -> (Data, URLResponse) =
      { url in try await URLSession.shared.data(for: URLRequest(url: url)) }
  ) async throws -> String {
    let (collection, videoId, sourceUrl) = try parseVideoPath(path)
    let html = try await fetchVideoTranscriptHtml(url: sourceUrl, fetcher: fetcher)
    let title = extractVideoTitleFromHtml(html: html) ?? "Video \(videoId)"
    let transcriptLines = extractTranscriptLinesFromHtml(html: html)

    if transcriptLines.isEmpty {
      throw AppleDocsError.notFound
    }

    return renderVideoTranscriptMarkdown(
      title: title,
      sourceUrl: sourceUrl.absoluteString,
      collection: collection,
      videoId: videoId,
      transcriptLines: transcriptLines
    )
  }

  static func parseVideoPath(_ path: String) throws -> (
    collection: String, videoId: String, url: URL
  ) {
    let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: #"^/+"#, with: "", options: .regularExpression)

    let pattern = #"^(?:videos/play/)?([^/]+)/([^/]+)/?$"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
      let match = regex.firstMatch(
        in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
      let collectionRange = Range(match.range(at: 1), in: trimmed),
      let videoIdRange = Range(match.range(at: 2), in: trimmed)
    else {
      throw AppleDocsError.invalidPath
    }

    let collection = String(trimmed[collectionRange])
    let videoId = String(trimmed[videoIdRange])
    let urlString = "https://developer.apple.com/videos/play/\(collection)/\(videoId)/"

    guard let url = URL(string: urlString) else {
      throw AppleDocsError.invalidURL(urlString)
    }

    return (collection, videoId, url)
  }

  static func fetchVideoTranscriptHtml(
    url: URL,
    fetcher: @Sendable (_ url: URL) async throws -> (Data, URLResponse)
  ) async throws -> String {
    let (data, response) = try await fetcher(url)

    if let httpResponse = response as? HTTPURLResponse {
      if httpResponse.statusCode == 404 {
        throw AppleDocsError.notFound
      }
      if httpResponse.statusCode != 200 {
        throw AppleDocsError.httpError(
          statusCode: httpResponse.statusCode, url: url.absoluteString)
      }
    }

    guard let html = String(data: data, encoding: .utf8) else {
      throw AppleDocsError.decodingError(
        underlying: NSError(
          domain: "VideoTranscript", code: 0,
          userInfo: [NSLocalizedDescriptionKey: "Failed to decode HTML as UTF-8"]))
    }

    return html
  }

  public static func extractVideoTitleFromHtml(html: String) -> String? {
    guard let doc = try? SwiftSoup.parse(html),
      let titleElement = try? doc.select("title").first(),
      let titleText = try? titleElement.text()
    else {
      return nil
    }

    let title = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
    if title.isEmpty { return nil }

    if title.hasSuffix(appleVideoSuffix) {
      let trimmed = String(title.dropLast(appleVideoSuffix.count))
        .trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.isEmpty ? nil : trimmed
    }

    return title
  }

  public static func extractTranscriptLinesFromHtml(html: String) -> [TranscriptLine] {
    guard let doc = try? SwiftSoup.parse(html),
      let transcriptSection = try? doc.select("section#transcript-content").first()
    else {
      return []
    }

    guard let spans = try? transcriptSection.select("span[data-start]") else {
      return []
    }

    var lines: [TranscriptLine] = []

    for span in spans {
      guard let dataStart = try? span.attr("data-start"),
        let startSeconds = Double(dataStart),
        startSeconds.isFinite
      else {
        continue
      }

      let text: String
      do {
        text =
          try span.text()
          .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
          .trimmingCharacters(in: .whitespacesAndNewlines)
      } catch {
        continue
      }

      if !text.isEmpty {
        lines.append(TranscriptLine(startSeconds: startSeconds, text: text))
      }
    }

    return lines
  }

  public static func renderVideoTranscriptMarkdown(
    title: String,
    sourceUrl: String,
    collection: String,
    videoId: String,
    transcriptLines: [TranscriptLine]
  ) -> String {
    let transcriptBody =
      transcriptLines
      .map { "- [\(formatTimestamp(seconds: $0.startSeconds))] \($0.text)" }
      .joined(separator: "\n")

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    return [
      "---",
      "title: \(title)",
      "source: \(sourceUrl)",
      "timestamp: \(formatter.string(from: Date()))",
      "---",
      "",
      "# \(title)",
      "",
      "**Collection:** \(collection)",
      "",
      "**Video:** \(videoId)",
      "",
      "## Transcript",
      "",
      transcriptBody,
      "",
      "---",
      "",
      "*Generated by [swift-developer-docs-mcp](https://github.com/mehmetbaykar/swift-developer-docs-mcp) - Making Apple docs AI-readable.*",
      "*This is unofficial content. All transcripts belong to Apple Inc.*",
      "",
    ].joined(separator: "\n")
  }

  public static func formatTimestamp(seconds: Double) -> String {
    let rounded = max(0, Int(seconds))
    let minutes = rounded / 60
    let remainingSeconds = rounded % 60
    return String(format: "%02d:%02d", minutes, remainingSeconds)
  }
}
