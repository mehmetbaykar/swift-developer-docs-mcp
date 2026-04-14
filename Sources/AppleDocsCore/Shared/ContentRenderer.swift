import Foundation

public struct ContentRenderer: Sendable {
  private static let maxContentDepth = 50
  private static let maxInlineDepth = 20

  // MARK: - Inline Content Rendering

  public static func renderInlineContent(
    _ inlineContent: [ContentItem], references: [String: ContentItem]?, depth: Int = 0,
    externalOrigin: String? = nil
  ) -> String {
    if depth > maxInlineDepth {
      return "[Inline content too deeply nested]"
    }

    return inlineContent.map { item in
      switch item.type {
      case "text":
        return item.text ?? ""
      case "codeVoice":
        if let codeValue = item.code {
          switch codeValue {
          case .single(let s): return "`\(s)`"
          case .multiple(let arr): return "`\(arr.joined())`"
          }
        }
        return ""
      case "reference":
        let title =
          item.title ?? item.text
          ?? (item.identifier.map { extractTitleFromIdentifier($0) } ?? "")
        let url =
          item.identifier != nil
          ? convertIdentifierToURL(
            item.identifier!, references: references, externalOrigin: externalOrigin)
          : ""
        return "[\(title)](\(url))"
      case "emphasis":
        let inner =
          item.inlineContent != nil
          ? renderInlineContent(
            item.inlineContent!, references: references, depth: depth + 1,
            externalOrigin: externalOrigin)
          : ""
        return "*\(inner)*"
      case "strong":
        let inner =
          item.inlineContent != nil
          ? renderInlineContent(
            item.inlineContent!, references: references, depth: depth + 1,
            externalOrigin: externalOrigin)
          : ""
        return "**\(inner)**"
      case "image":
        return renderInlineImage(item, references: references)
      case "superscript":
        let inner =
          item.inlineContent != nil
          ? renderInlineContent(
            item.inlineContent!, references: references, depth: depth + 1,
            externalOrigin: externalOrigin)
          : (item.text ?? "")
        return "<sup>\(inner)</sup>"
      case "subscript":
        let inner =
          item.inlineContent != nil
          ? renderInlineContent(
            item.inlineContent!, references: references, depth: depth + 1,
            externalOrigin: externalOrigin)
          : (item.text ?? "")
        return "<sub>\(inner)</sub>"
      case "strikethrough":
        let inner =
          item.inlineContent != nil
          ? renderInlineContent(
            item.inlineContent!, references: references, depth: depth + 1,
            externalOrigin: externalOrigin)
          : (item.text ?? "")
        return "~~\(inner)~~"
      case "newTerm":
        let inner =
          item.inlineContent != nil
          ? renderInlineContent(
            item.inlineContent!, references: references, depth: depth + 1,
            externalOrigin: externalOrigin)
          : (item.text ?? "")
        return "*\(inner)*"
      default:
        return item.text ?? ""
      }
    }.joined()
  }

  // MARK: - Content Array Rendering

  public static func renderContentArray(
    _ content: [ContentItem], references: [String: ContentItem]?, depth: Int = 0,
    externalOrigin: String? = nil
  ) -> String {
    if depth > maxContentDepth {
      return "[Content too deeply nested]"
    }

    var markdown = ""
    for item in content {
      markdown += renderBlock(
        item, references: references, depth: depth, externalOrigin: externalOrigin)
    }
    return markdown
  }

  private static func renderBlock(
    _ item: ContentItem, references: [String: ContentItem]?, depth: Int,
    externalOrigin: String?
  ) -> String {
    switch item.type {
    case "heading":
      return renderHeading(
        item, references: references, depth: depth, externalOrigin: externalOrigin)
    case "paragraph":
      return renderParagraph(
        item, references: references, depth: depth, externalOrigin: externalOrigin)
    case "codeListing":
      return renderCodeListing(item)
    case "unorderedList":
      return renderList(
        item,
        ordered: false,
        references: references,
        depth: depth,
        externalOrigin: externalOrigin
      )
    case "orderedList":
      return renderList(
        item,
        ordered: true,
        references: references,
        depth: depth,
        externalOrigin: externalOrigin
      )
    case "aside":
      return renderAside(item, references: references, depth: depth, externalOrigin: externalOrigin)
    case "table":
      return renderTable(item, references: references, depth: depth, externalOrigin: externalOrigin)
    case "row":
      return renderRow(item, references: references, depth: depth, externalOrigin: externalOrigin)
    case "small":
      return renderSmall(item, references: references, depth: depth, externalOrigin: externalOrigin)
    case "tabNavigator":
      return renderTabNavigator(
        item, references: references, depth: depth, externalOrigin: externalOrigin)
    case "links":
      return renderLinks(item, references: references, externalOrigin: externalOrigin)
    case "termList":
      return renderTermList(
        item, references: references, depth: depth, externalOrigin: externalOrigin)
    case "dictionaryExample":
      return renderDictionaryExample(
        item, references: references, depth: depth, externalOrigin: externalOrigin)
    default:
      return ""
    }
  }

  private static func renderHeading(
    _ item: ContentItem, references: [String: ContentItem]?, depth: Int,
    externalOrigin: String?
  ) -> String {
    let level = min(item.level ?? 2, 6)
    let hashes = String(repeating: "#", count: level)
    let text =
      item.text
      ?? (item.inlineContent.map {
        renderInlineContent(
          $0, references: references, depth: depth, externalOrigin: externalOrigin)
      } ?? "")
    return "\(hashes) \(text)\n\n"
  }

  private static func renderParagraph(
    _ item: ContentItem, references: [String: ContentItem]?, depth: Int,
    externalOrigin: String?
  ) -> String {
    guard let inlineContent = item.inlineContent else { return "" }
    let text = renderInlineContent(
      inlineContent, references: references, depth: depth, externalOrigin: externalOrigin)
    return "\(text)\n\n"
  }

  private static func renderCodeListing(_ item: ContentItem) -> String {
    let code: String
    switch item.code {
    case .single(let string):
      code = string
    case .multiple(let lines):
      code = lines.joined(separator: "\n")
    case nil:
      code = ""
    }

    let syntax = item.syntax ?? "swift"
    return "```\(syntax)\n\(code)\n```\n\n"
  }

  private static func renderList(
    _ item: ContentItem,
    ordered: Bool,
    references: [String: ContentItem]?,
    depth: Int,
    externalOrigin: String?
  ) -> String {
    guard let items = item.items else { return "" }

    var markdown = ""
    for (index, listItem) in items.enumerated() {
      let itemText = renderContentArray(
        listItem.content ?? [],
        references: references,
        depth: depth + 1,
        externalOrigin: externalOrigin
      )
      let normalized = itemText.replacingOccurrences(
        of: "\\n\\n$",
        with: "",
        options: .regularExpression
      )
      if ordered {
        markdown += "\(index + 1). \(normalized)\n"
      } else {
        markdown += "- \(normalized)\n"
      }
    }

    return markdown.isEmpty ? "" : "\(markdown)\n"
  }

  private static func renderRow(
    _ item: ContentItem, references: [String: ContentItem]?, depth: Int,
    externalOrigin: String?
  ) -> String {
    guard let columns = item.content else { return "" }

    var markdown = ""
    for column in columns {
      guard let colContent = column.content else { continue }
      markdown += renderContentArray(
        colContent,
        references: references,
        depth: depth + 1,
        externalOrigin: externalOrigin
      )
    }
    return markdown
  }

  private static func renderSmall(
    _ item: ContentItem, references: [String: ContentItem]?, depth: Int,
    externalOrigin: String?
  ) -> String {
    guard let inlineContent = item.inlineContent else { return "" }
    let text = renderInlineContent(
      inlineContent, references: references, depth: depth, externalOrigin: externalOrigin)
    return "<small>\(text)</small>\n\n"
  }

  private static func renderTabNavigator(
    _ item: ContentItem, references: [String: ContentItem]?, depth: Int,
    externalOrigin: String?
  ) -> String {
    guard let tabs = item.items else { return "" }

    var markdown = ""
    for tab in tabs {
      if let tabTitle = tab.title {
        markdown += "### \(tabTitle)\n\n"
      }
      if let tabContent = tab.content {
        markdown += renderContentArray(
          tabContent,
          references: references,
          depth: depth + 1,
          externalOrigin: externalOrigin
        )
      }
    }
    return markdown
  }

  private static func renderLinks(
    _ item: ContentItem, references: [String: ContentItem]?,
    externalOrigin: String?
  ) -> String {
    guard let identifiers = item.identifiers ?? item.itemIdentifiers else { return "" }

    let markdown = identifiers.map { identifier in
      let title = extractTitleFromIdentifier(identifier)
      let url = convertIdentifierToURL(
        identifier,
        references: references,
        externalOrigin: externalOrigin
      )
      return "- [\(title)](\(url))"
    }.joined(separator: "\n")

    return markdown.isEmpty ? "" : "\(markdown)\n\n"
  }

  private static func renderTermList(
    _ item: ContentItem, references: [String: ContentItem]?, depth: Int,
    externalOrigin: String?
  ) -> String {
    guard let items = item.items else { return "" }

    var markdown = ""
    for termItem in items {
      if let term = termItem.content?.first {
        let termText =
          term.inlineContent != nil
          ? renderInlineContent(
            term.inlineContent!, references: references, depth: depth,
            externalOrigin: externalOrigin)
          : (term.text ?? "")
        markdown += "**\(termText)**\n"
      }

      if let definition = termItem.content, definition.count > 1 {
        markdown += renderContentArray(
          Array(definition.dropFirst()),
          references: references,
          depth: depth + 1,
          externalOrigin: externalOrigin
        )
      }

      markdown += "\n"
    }

    return markdown
  }

  private static func renderDictionaryExample(
    _ item: ContentItem, references: [String: ContentItem]?, depth: Int,
    externalOrigin: String?
  ) -> String {
    guard let content = item.content else { return "" }
    return renderContentArray(
      content,
      references: references,
      depth: depth + 1,
      externalOrigin: externalOrigin
    )
  }

  // MARK: - Table Rendering

  public static func renderTable(
    _ item: ContentItem, references: [String: ContentItem]?, depth: Int = 0,
    externalOrigin: String? = nil
  ) -> String {
    guard let rows = item.rows, !rows.isEmpty else { return "" }

    let firstRowIsHeader = item.header == "row"
    var markdown = ""

    for (rowIndex, row) in rows.enumerated() {
      let cells = row.map { cell -> String in
        let rendered = renderContentArray(
          cell, references: references, depth: depth + 1, externalOrigin: externalOrigin)
        return escapeTableCell(rendered)
      }
      guard !cells.isEmpty else { continue }
      markdown += "| \(cells.joined(separator: " | ")) |\n"
      if firstRowIsHeader && rowIndex == 0 {
        markdown += "| \(cells.map { _ in "---" }.joined(separator: " | ")) |\n"
      }
    }

    return markdown.isEmpty ? "" : "\(markdown)\n"
  }

  private static func escapeTableCell(_ text: String) -> String {
    text
      .replacingOccurrences(of: "|", with: "\\|")
      .replacingOccurrences(of: "\n", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  // MARK: - Aside Rendering

  public static func renderAside(
    _ item: ContentItem, references: [String: ContentItem]?, depth: Int = 0,
    externalOrigin: String? = nil
  ) -> String {
    let style = item.style ?? "note"
    let calloutType = mapAsideStyleToCallout(style)
    let asideContent =
      item.content != nil
      ? renderContentArray(
        item.content!, references: references, depth: depth + 1, externalOrigin: externalOrigin)
      : ""
    let cleanContent = asideContent.trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "\n", with: "\n> ")
    return "> [!\(calloutType)]\n> \(cleanContent)\n\n"
  }

  // MARK: - Image Rendering

  public static func renderInlineImage(
    _ item: ContentItem, references: [String: ContentItem]?
  ) -> String {
    guard let identifier = item.identifier else { return "" }
    let ref = references?[identifier]
    let url = ref?.variants?.first?.url ?? ref?.url
    let alt = ref?.alt ?? item.alt ?? ""
    guard let url else { return "" }
    return "![\(alt)](\(url))"
  }

  // MARK: - Properties Rendering

  public static func renderProperties(
    _ properties: [PropertyItem], references: [String: ContentItem]?,
    externalOrigin: String? = nil
  ) -> String {
    if properties.isEmpty { return "" }

    var markdown = "## Properties\n\n"

    for property in properties {
      let typeText = renderPropertyType(
        property.type, references: references, externalOrigin: externalOrigin)
      let requiredText = property.required == true ? "required" : "optional"
      var metadata = [String]()
      if !typeText.isEmpty { metadata.append(typeText) }
      metadata.append(requiredText)
      let headingSuffix = metadata.isEmpty ? "" : " *(\(metadata.joined(separator: ", ")))*"
      markdown += "### `\(property.name)`\(headingSuffix)\n\n"

      if let content = property.content {
        markdown += renderContentArray(
          content, references: references, externalOrigin: externalOrigin)
      }

      if let allowedValues = property.attributes?.first(where: { $0.kind == "allowedValues" })?
        .values, !allowedValues.isEmpty
      {
        let possibleValues = allowedValues.map { "`\($0)`" }.joined(separator: ", ")
        markdown += "Possible Values: \(possibleValues)\n\n"
      }
    }

    return markdown
  }

  private static func renderPropertyType(
    _ type: [PropertyTypeItem]?, references: [String: ContentItem]?,
    externalOrigin: String? = nil
  ) -> String {
    guard let type, !type.isEmpty else { return "" }

    return type.map { part in
      if part.kind == "typeIdentifier", let identifier = part.identifier, let text = part.text {
        let url = convertIdentifierToURL(
          identifier, references: references, externalOrigin: externalOrigin)
        return shouldLinkPropertyType(url, originalIdentifier: identifier)
          ? "[\(text)](\(url))" : text
      }
      return part.text ?? ""
    }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func shouldLinkPropertyType(
    _ url: String,
    originalIdentifier: String
  ) -> Bool {
    if url.hasPrefix("/") || url.hasPrefix("https://") || url.hasPrefix("http://") {
      return true
    }

    return originalIdentifier.hasPrefix("doc://") && url != originalIdentifier
  }

  // MARK: - Relationships Rendering

  public static func renderRelationships(
    _ rels: [ContentItem], variants: [Variant]?, refs: [String: ContentItem]?,
    externalOrigin: String? = nil
  ) -> String {
    var markdown = ""
    for rel in rels {
      guard let title = rel.title, let identifiers = rel.identifiers else { continue }
      markdown += "## \(title)\n\n"
      for id in identifiers {
        let info = variants?.first { $0.identifier == id }
        let reference = refs?[id]
        let displayTitle = info?.title ?? reference?.title ?? extractTitleFromIdentifier(id)
        let url = convertIdentifierToURL(id, references: refs, externalOrigin: externalOrigin)
        markdown += "- [\(displayTitle)](\(url))\n"
      }
      markdown += "\n"
    }
    return markdown
  }

  // MARK: - Utility Functions

  public static func mapAsideStyleToCallout(_ style: String) -> String {
    switch style.lowercased() {
    case "warning": return "WARNING"
    case "important": return "IMPORTANT"
    case "caution": return "CAUTION"
    case "tip": return "TIP"
    case "experiment": return "NOTE"
    case "deprecated": return "WARNING"
    default: return "NOTE"
    }
  }

  public static func convertIdentifierToURL(
    _ identifier: String, references: [String: ContentItem]?,
    externalOrigin: String? = nil
  ) -> String {
    if let reference = references?[identifier], let url = reference.url {
      return rewriteDocumentationPath(url, externalOrigin: externalOrigin)
    }

    if identifier.hasPrefix("doc://com.apple.SwiftUI/documentation/") {
      let path = identifier.replacingOccurrences(
        of: "doc://com.apple.SwiftUI/documentation/",
        with: "/documentation/"
      )
      return rewriteDocumentationPath(path, externalOrigin: externalOrigin)
    } else if identifier.hasPrefix("doc://com.apple.") {
      if let range = identifier.range(of: #"\/documentation\/(.+)"#, options: .regularExpression) {
        return rewriteDocumentationPath(String(identifier[range]), externalOrigin: externalOrigin)
      }
    } else if identifier.hasPrefix("doc://") {
      if let range = identifier.range(of: #"\/documentation\/(.+)"#, options: .regularExpression) {
        return rewriteDocumentationPath(String(identifier[range]), externalOrigin: externalOrigin)
      }
    }
    return identifier
  }

  public static func rewriteDocumentationPath(
    _ path: String, externalOrigin: String?
  ) -> String {
    guard let externalOrigin, !externalOrigin.isEmpty else {
      return path
    }
    guard path.hasPrefix("/documentation/") || path.hasPrefix("/tutorials/") else {
      return path
    }
    let normalizedOrigin = externalOrigin.replacingOccurrences(
      of: #"/+$"#, with: "", options: .regularExpression)
    return "/external/\(normalizedOrigin)\(path)"
  }

  public static func extractTitleFromIdentifier(_ identifier: String) -> String {
    let parts = identifier.split(separator: "/")
    guard let lastPart = parts.last else { return identifier }
    let lastStr = String(lastPart)

    if lastStr.range(of: #"^(.+?)(?:-\w+)?$"#, options: .regularExpression) != nil {
      // Try to extract just the part before the disambiguation suffix
      if let dashRange = lastStr.range(of: #"-\w+$"#, options: .regularExpression) {
        let withoutSuffix = String(lastStr[lastStr.startIndex..<dashRange.lowerBound])
        if withoutSuffix.contains("(") && withoutSuffix.contains(")") {
          return withoutSuffix
        }
      }

      if lastStr.contains("(") && lastStr.contains(")") {
        return lastStr
      }
    }

    return
      lastStr
      .replacingOccurrences(of: #"([a-z])([A-Z])"#, with: "$1 $2", options: .regularExpression)
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespaces)
  }
}
