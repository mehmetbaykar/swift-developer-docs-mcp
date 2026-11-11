import Foundation

public enum MarkdownFormatting: Sendable {
  public static let maxContentDepth = 50
  public static let maxInlineDepth = 20
  public static let contentTooDeep = "[Content too deeply nested]"
  public static let inlineContentTooDeep = "[Inline content too deeply nested]"

  public static func formatList(_ itemContents: [String], ordered: Bool) -> String {
    let items = itemContents.enumerated().map { index, content in
      formatListItem(ordered ? "\(index + 1). " : "- ", content: content)
    }
    return items.joined() + "\n"
  }

  public static func formatCodeBlock(_ code: String, syntax: String?) -> String {
    let language = syntax == "occ" ? "objc" : (syntax.flatMap { $0.isEmpty ? nil : $0 } ?? "swift")
    return "```\(language)\n\(code)\n```\n\n"
  }

  public static func formatTable(_ rows: [[String]], hasHeaderRow: Bool) -> String {
    var markdown = ""
    for (index, row) in rows.enumerated() {
      if row.isEmpty { continue }
      let cells = row.map { cell in
        cell
          .replacingOccurrences(of: "|", with: "\\|")
          .replacingOccurrences(of: "\n", with: " ")
          .trimmingCharacters(in: .whitespacesAndNewlines)
      }
      markdown += "| \(cells.joined(separator: " | ")) |\n"
      if hasHeaderRow && index == 0 {
        markdown += "| \(cells.map { _ in "---" }.joined(separator: " | ")) |\n"
      }
    }
    return markdown.isEmpty ? "" : markdown + "\n"
  }

  public static func formatCallout(type: String, content: String, lead: String? = nil) -> String {
    let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
    let paragraphs = [lead, trimmedContent].compactMap { paragraph -> String? in
      guard let paragraph, !paragraph.isEmpty else { return nil }
      return paragraph
    }
    if paragraphs.isEmpty {
      return ""
    }

    let quoted = paragraphs.joined(separator: "\n\n").split(
      separator: "\n", omittingEmptySubsequences: false
    ).map { line in
      line.isEmpty ? ">" : "> \(line)"
    }.joined(separator: "\n")
    return "> [!\(type)]\n\(quoted)\n\n"
  }

  public static func mapAsideStyleToCallout(_ style: String) -> String {
    switch style.lowercased() {
    case "warning":
      return "WARNING"
    case "important":
      return "IMPORTANT"
    case "caution":
      return "CAUTION"
    case "tip":
      return "TIP"
    case "deprecated":
      return "WARNING"
    default:
      return "NOTE"
    }
  }

  private static func formatListItem(_ marker: String, content: String) -> String {
    let trimmed = content.replacingOccurrences(
      of: #"\n+$"#, with: "", options: .regularExpression)
    if trimmed.isEmpty {
      return trimEnd(marker) + "\n"
    }

    let tightened = trimmed.replacingOccurrences(
      of: #"\n{2,}(?=(?:[-*]|\d+\.) )"#,
      with: "\n",
      options: .regularExpression
    )
    let indent = String(repeating: " ", count: marker.count)
    let lines = tightened.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    let first = lines.first ?? ""
    let continuation = lines.dropFirst().map { line in
      line.isEmpty ? "" : indent + line
    }
    return marker + ([first] + continuation).joined(separator: "\n") + "\n"
  }

  private static func trimEnd(_ value: String) -> String {
    var result = value
    while let last = result.last, last.isWhitespace {
      result.removeLast()
    }
    return result
  }
}
