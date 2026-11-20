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

  public struct CodeSample: Sendable, Equatable {
    public let title: String?
    public let startSeconds: Double?
    public let code: String

    public init(title: String?, startSeconds: Double?, code: String) {
      self.title = title
      self.startSeconds = startSeconds
      self.code = code
    }
  }

  public static func fetchVideoTranscriptMarkdown(
    path: String,
    fetcher: @Sendable (_ url: URL) async throws -> (Data, URLResponse) =
      { url in try await URLSession.shared.data(for: makeVideoPageRequest(url: url)) }
  ) async throws -> String {
    let (collection, videoId, sourceUrl) = try parseVideoPath(path)
    let html = try await fetchVideoTranscriptHtml(url: sourceUrl, fetcher: fetcher)
    let title = extractVideoTitleFromHtml(html: html) ?? "Video \(videoId)"
    let transcriptLines = extractTranscriptLinesFromHtml(html: html)
    let codeSamples = extractCodeSamplesFromHtml(html: html)

    if transcriptLines.isEmpty {
      throw AppleDocsError.notFound
    }

    return renderVideoTranscriptMarkdown(
      title: title,
      sourceUrl: sourceUrl.absoluteString,
      collection: collection,
      videoId: videoId,
      transcriptLines: transcriptLines,
      codeSamples: codeSamples
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

  public static func makeVideoPageRequest(url: URL) -> URLRequest {
    var request = URLRequest(url: url)
    request.setValue(Fetcher.randomUserAgent(), forHTTPHeaderField: "User-Agent")
    request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
    request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
    return request
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

  /// Extracts the code samples that Apple shows in the Code tab of a session page.
  ///
  /// Each sample is an `li.sample-code-main-container` inside `li.supplement.sample-code`,
  /// with a title line such as `3:40 - <a data-start-time="220">Title</a>`
  /// and the code in `<pre class="code-source"><code>` with syntax-highlighting spans.
  public static func extractCodeSamplesFromHtml(html: String) -> [CodeSample] {
    // Match the `sample-code` class itself, not `sample-code-main-container`.
    guard
      let supplementStart = html.range(
        of: #"<li[^>]*class=["'][^"']*(?<![\w-])sample-code(?![\w-])[^"']*["'][^>]*>"#,
        options: [.regularExpression, .caseInsensitive]
      )?.lowerBound
    else {
      return []
    }

    // The escaped code can't contain a literal `</section>`, so it ends the list.
    let supplementEnd =
      html.range(of: "</section>", range: supplementStart..<html.endIndex)?.lowerBound
      ?? html.endIndex
    let supplement = html[supplementStart..<supplementEnd]

    let containerPattern =
      #"<li[^>]*class=["'][^"']*\bsample-code-main-container\b[^"']*["'][^>]*>([\s\S]*?)</li>"#
    guard
      let containerRegex = try? NSRegularExpression(
        pattern: containerPattern, options: [.caseInsensitive])
    else {
      return []
    }

    let supplementString = String(supplement)
    let nsSupplement = supplementString as NSString
    let matches = containerRegex.matches(
      in: supplementString, range: NSRange(location: 0, length: nsSupplement.length))

    var samples: [CodeSample] = []
    for match in matches {
      guard match.numberOfRanges >= 2,
        let containerRange = Range(match.range(at: 1), in: supplementString)
      else {
        continue
      }
      let container = String(supplementString[containerRange])

      guard
        let codeRegex = try? NSRegularExpression(
          pattern: #"<pre[^>]*>\s*<code[^>]*>([\s\S]*?)</code>\s*</pre>"#,
          options: [.caseInsensitive]),
        let codeRegexMatch = codeRegex.firstMatch(
          in: container, range: NSRange(container.startIndex..., in: container)),
        codeRegexMatch.numberOfRanges >= 2,
        let innerRange = Range(codeRegexMatch.range(at: 1), in: container)
      else {
        continue
      }
      var code = decodeHtmlEntities(stripHtml(String(container[innerRange])))
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
      if let trimmedLeading = code.range(of: #"^\s*\n"#, options: .regularExpression) {
        code.removeSubrange(trimmedLeading)
      }
      while let last = code.last, last.isWhitespace {
        code.removeLast()
      }

      if code.isEmpty {
        continue
      }

      let heading = extractCodeSampleHeading(container: container)
      samples.append(
        CodeSample(title: heading.title, startSeconds: heading.startSeconds, code: code))
    }

    return samples
  }

  private static func extractCodeSampleHeading(container: String) -> (
    title: String?, startSeconds: Double?
  ) {
    guard
      let paragraphRegex = try? NSRegularExpression(
        pattern: #"<p[^>]*>([\s\S]*?)</p>"#, options: [.caseInsensitive]),
      let paragraphMatch = paragraphRegex.firstMatch(
        in: container, range: NSRange(container.startIndex..., in: container)),
      paragraphMatch.numberOfRanges >= 2,
      let paragraphRange = Range(paragraphMatch.range(at: 1), in: container)
    else {
      return (nil, nil)
    }

    let paragraph = String(container[paragraphRange])

    var startSeconds: Double? = nil
    var titleSource = paragraph

    if let anchorRegex = try? NSRegularExpression(
      pattern: #"<a([^>]*)>([\s\S]*?)</a>"#, options: [.caseInsensitive]),
      let anchorMatch = anchorRegex.firstMatch(
        in: paragraph, range: NSRange(paragraph.startIndex..., in: paragraph)),
      anchorMatch.numberOfRanges >= 3,
      let attrsRange = Range(anchorMatch.range(at: 1), in: paragraph),
      let textRange = Range(anchorMatch.range(at: 2), in: paragraph)
    {
      let attrs = String(paragraph[attrsRange])
      if let startTimeRegex = try? NSRegularExpression(
        pattern: #"data-start-time=["']([\d.]+)["']"#, options: [.caseInsensitive]),
        let startTimeMatch = startTimeRegex.firstMatch(
          in: attrs, range: NSRange(attrs.startIndex..., in: attrs)),
        startTimeMatch.numberOfRanges >= 2,
        let valueRange = Range(startTimeMatch.range(at: 1), in: attrs),
        let parsed = Double(attrs[valueRange]), parsed.isFinite
      {
        startSeconds = parsed
        titleSource = String(paragraph[textRange])
      }
    }

    let title =
      decodeHtmlEntities(stripHtml(titleSource))
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)

    return (title.isEmpty ? nil : title, startSeconds)
  }

  private static func renderCodeSamplesMarkdown(codeSamples: [CodeSample]) -> [String] {
    if codeSamples.isEmpty {
      return []
    }

    var lines = ["## Code", ""]
    for (index, sample) in codeSamples.enumerated() {
      let timestamp: String? =
        sample.startSeconds.map { "[\(formatTimestamp(seconds: $0))]" }
      let parts = [timestamp, sample.title].compactMap { $0 }
      let heading = parts.isEmpty ? "Sample \(index + 1)" : parts.joined(separator: " ")
      let fence = codeFenceFor(code: sample.code)
      lines.append(contentsOf: ["### \(heading)", "", "\(fence)swift", sample.code, fence, ""])
    }
    return lines
  }

  private static func codeFenceFor(code: String) -> String {
    var longestRun = 0
    var currentRun = 0
    for character in code {
      if character == "`" {
        currentRun += 1
        longestRun = max(longestRun, currentRun)
      } else {
        currentRun = 0
      }
    }
    return String(repeating: "`", count: max(3, longestRun + 1))
  }

  public static func renderVideoTranscriptMarkdown(
    title: String,
    sourceUrl: String,
    collection: String,
    videoId: String,
    transcriptLines: [TranscriptLine],
    codeSamples: [CodeSample] = []
  ) -> String {
    let transcriptBody =
      transcriptLines
      .map { "- [\(formatTimestamp(seconds: $0.startSeconds))] \($0.text)" }
      .joined(separator: "\n")

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    var parts: [String] = [
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
    ]
    parts.append(contentsOf: renderCodeSamplesMarkdown(codeSamples: codeSamples))
    parts.append(contentsOf: [
      "---",
      "",
      "*Generated by [swift-developer-docs-mcp](https://github.com/mehmetbaykar/swift-developer-docs-mcp) - Making Apple docs AI-readable.*",
      "*This is unofficial content. All transcripts belong to Apple Inc.*",
      "",
    ])
    return parts.joined(separator: "\n")
  }

  public static func formatTimestamp(seconds: Double) -> String {
    let rounded = max(0, Int(seconds))
    let minutes = rounded / 60
    let remainingSeconds = rounded % 60
    return String(format: "%02d:%02d", minutes, remainingSeconds)
  }

  private static func stripHtml(_ input: String) -> String {
    input.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
  }

  private static func decodeHtmlEntities(_ input: String) -> String {
    guard
      let regex = try? NSRegularExpression(pattern: #"&(#x?[0-9a-fA-F]+|[a-zA-Z]+);"#)
    else {
      return input
    }

    let nsInput = input as NSString
    let matches = regex.matches(in: input, range: NSRange(location: 0, length: nsInput.length))
    var result = input
    for match in matches.reversed() {
      guard match.numberOfRanges >= 2,
        let fullRange = Range(match.range(at: 0), in: result),
        let entityRange = Range(match.range(at: 1), in: result)
      else {
        continue
      }
      let entity = String(result[entityRange])
      let replacement: String
      if entity.first == "#" {
        let isHex = entity.dropFirst().first?.lowercased() == "x"
        let digits = entity.dropFirst(isHex ? 2 : 1)
        if let codePoint = Int(digits, radix: isHex ? 16 : 10),
          let scalar = Unicode.Scalar(codePoint)
        {
          replacement = String(Character(scalar))
        } else {
          replacement = ""
        }
      } else {
        switch entity {
        case "amp": replacement = "&"
        case "lt": replacement = "<"
        case "gt": replacement = ">"
        case "quot": replacement = "\""
        case "apos": replacement = "'"
        case "nbsp": replacement = " "
        default: replacement = "&\(entity);"
        }
      }
      result.replaceSubrange(fullRange, with: replacement)
    }
    return result
  }
}
