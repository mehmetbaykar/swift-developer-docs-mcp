import Foundation

public struct ContentRenderer: Sendable {
  private static let languageTabTitles: Set<String> = ["Swift", "Objective-C"]

  // MARK: - Inline Content Rendering

  public static func renderInlineContent(
    _ inlineContent: [ContentItem], references: [String: ContentItem]?, depth: Int = 0,
    externalOrigin: String? = nil
  ) -> String {
    if depth > MarkdownFormatting.maxInlineDepth {
      return MarkdownFormatting.inlineContentTooDeep
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
        let reference = item.identifier.flatMap { references?[$0] }
        let title =
          nonEmpty(item.title)
          ?? nonEmpty(item.text)
          ?? resolveReferenceTitle(
            reference, references: references, depth: depth, externalOrigin: externalOrigin)
          ?? item.identifier.map { extractTitleFromIdentifier($0) }
          ?? ""
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

  public static func resolveReferenceTitle(
    _ reference: ContentItem?,
    references: [String: ContentItem]?,
    depth: Int = 0,
    externalOrigin: String? = nil
  ) -> String? {
    if let titleInlineContent = reference?.titleInlineContent {
      let rendered = renderInlineContent(
        titleInlineContent, references: references, depth: depth + 1,
        externalOrigin: externalOrigin)
      if !rendered.isEmpty {
        return rendered
      }
    }
    if let title = nonEmpty(reference?.title), reference?.role == "symbol" {
      return "`\(title)`"
    }
    return nonEmpty(reference?.title)
  }

  public static func renderPlainText(
    _ inlineContent: [ContentItem],
    references: [String: ContentItem]?,
    depth: Int = 0
  ) -> String {
    if depth > MarkdownFormatting.maxInlineDepth {
      return ""
    }

    return inlineContent.map { item in
      if item.type == "codeVoice" {
        return plainCode(item.code)
      }
      if item.type == "reference" {
        let reference = item.identifier.flatMap { references?[$0] }
        return nonEmpty(item.title)
          ?? nonEmpty(item.text)
          ?? nonEmpty(reference?.title)
          ?? item.identifier.map { extractTitleFromIdentifier($0) }
          ?? ""
      }
      if let nested = item.inlineContent {
        return renderPlainText(nested, references: references, depth: depth + 1)
      }
      return item.text ?? ""
    }.joined()
  }

  public static func renderAbstractQuote(
    _ abstract: [ContentItem]?,
    references: [String: ContentItem]?,
    externalOrigin: String? = nil
  ) -> String {
    guard let abstract else { return "" }
    let abstractText = renderInlineContent(
      abstract, references: references, depth: 0, externalOrigin: externalOrigin)
    if abstractText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return ""
    }
    return "> \(abstractText)\n\n"
  }

  public static func formatPlatforms(_ platforms: [Platform]) -> String {
    platforms.map { platform in
      let version: String
      if let introducedAt = platform.introducedAt, !introducedAt.isEmpty {
        version = " \(introducedAt)+"
      } else {
        version = ""
      }
      let beta = platform.beta == true ? " Beta" : ""
      return "\(platform.name)\(version)\(beta)"
    }.joined(separator: ", ")
  }

  public static func renderLanguageNotice(
    _ jsonData: AppleDocJSON, externalOrigin: String? = nil
  ) -> String {
    guard jsonData.identifier?.interfaceLanguage == "occ" else { return "" }

    let swiftPath = jsonData.variants?
      .compactMap { variant -> LanguageVariant? in
        if case .language(let language) = variant { return language }
        return nil
      }
      .first { language in
        language.traits.contains { $0.interfaceLanguage == "swift" }
      }?
      .paths.first

    if let swiftPath {
      let url = rewriteDocumentationPath(swiftPath, externalOrigin: externalOrigin)
      let link = "[\(url)](\(url))"
      return MarkdownFormatting.formatCallout(
        type: "NOTE",
        content: "This page documents the Objective-C API. For the Swift API, see \(link)."
      )
    }

    return MarkdownFormatting.formatCallout(
      type: "NOTE",
      content:
        "This page documents the Objective-C API. Apple's documentation doesn't link a Swift version of this symbol, which may have a different name or type in Swift."
    )
  }

  private static func nonEmpty(_ value: String?) -> String? {
    guard let value, !value.isEmpty else { return nil }
    return value
  }

  private static func plainCode(_ code: CodeValue?) -> String {
    switch code {
    case .single(let string):
      return string
    case .multiple(let lines):
      return lines.joined()
    case nil:
      return ""
    }
  }

  // MARK: - Content Array Rendering

  public static func renderContentArray(
    _ content: [ContentItem], references: [String: ContentItem]?, depth: Int = 0,
    externalOrigin: String? = nil
  ) -> String {
    if depth > MarkdownFormatting.maxContentDepth {
      return MarkdownFormatting.contentTooDeep
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
      inlineContent, references: references, depth: 0, externalOrigin: externalOrigin)
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

    return MarkdownFormatting.formatCodeBlock(code, syntax: item.syntax)
  }

  private static func renderList(
    _ item: ContentItem,
    ordered: Bool,
    references: [String: ContentItem]?,
    depth: Int,
    externalOrigin: String?
  ) -> String {
    guard let items = item.items else { return "" }

    let itemContents = items.map { listItem in
      renderContentArray(
        listItem.content ?? [],
        references: references,
        depth: depth + 1,
        externalOrigin: externalOrigin
      )
    }
    return MarkdownFormatting.formatList(itemContents, ordered: ordered)
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
    guard let tabs = item.tabs, !tabs.isEmpty else { return "" }
    let allLanguageTabs = tabs.allSatisfy { tab in
      guard let title = tab.title?.trimmingCharacters(in: .whitespacesAndNewlines) else {
        return false
      }
      return languageTabTitles.contains(title)
    }
    let swiftTabs = tabs.filter {
      $0.title?.trimmingCharacters(in: .whitespacesAndNewlines) == "Swift"
    }
    let tabsToRender = allLanguageTabs && !swiftTabs.isEmpty ? swiftTabs : tabs
    let showLabel = tabsToRender.count > 1

    var markdown = ""
    for tab in tabsToRender {
      if showLabel, let tabTitle = tab.title?.trimmingCharacters(in: .whitespacesAndNewlines),
        !tabTitle.isEmpty
      {
        markdown += "**\(tabTitle)**\n\n"
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

  public static func renderPossibleValues(
    _ values: [PossibleValueItem], references: [String: ContentItem]?,
    externalOrigin: String? = nil
  ) -> String {
    if values.isEmpty { return "" }

    var markdown = "## Possible Values\n\n"
    for value in values {
      if value.name.isEmpty { continue }
      markdown += "### `\(value.name)`\n\n"

      if let content = value.content {
        let rendered = renderContentArray(
          content, references: references, externalOrigin: externalOrigin
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        if !rendered.isEmpty {
          markdown += "\(rendered)\n\n"
        }
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

    let renderedRows = rows.map { row in
      row.map { cell in
        renderContentArray(
          cell, references: references, depth: depth + 1, externalOrigin: externalOrigin)
      }
    }
    return MarkdownFormatting.formatTable(renderedRows, hasHeaderRow: item.header == "row")
  }

  // MARK: - Aside Rendering

  public static func renderAside(
    _ item: ContentItem, references: [String: ContentItem]?, depth: Int = 0,
    externalOrigin: String? = nil
  ) -> String {
    let style = item.style ?? "note"
    let asideContent =
      item.content != nil
      ? renderContentArray(
        item.content!, references: references, depth: depth + 1, externalOrigin: externalOrigin)
      : ""
    let lead = style.lowercased() == "deprecated" ? "**Deprecated**" : nil
    return MarkdownFormatting.formatCallout(
      type: mapAsideStyleToCallout(style),
      content: asideContent,
      lead: lead
    )
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
      guard let title = nonEmpty(rel.title), let identifiers = rel.identifiers else { continue }
      markdown += "## \(title)\n\n"
      for id in identifiers {
        let link = resolveLink(
          id, variants: variants, refs: refs, externalOrigin: externalOrigin)
        let condition = renderCondition(
          refs?[id], prefix: .conformance, refs: refs, externalOrigin: externalOrigin)
        markdown += "- [\(link.title)](\(link.url))"
        if !condition.isEmpty {
          markdown += " \(condition)"
        }
        markdown += "\n"
      }
      markdown += "\n"
    }
    return markdown
  }

  public static func renderTopicSections(
    _ topics: [TopicSection], variants: [Variant]?, refs: [String: ContentItem]?,
    externalOrigin: String? = nil
  ) -> String {
    var markdown = ""
    for topic in topics {
      if !topic.title.isEmpty {
        markdown += "## \(topic.title)\n\n"
      }
      if let identifiers = topic.identifiers {
        for id in identifiers {
          let link = resolveLink(
            id, variants: variants, refs: refs, externalOrigin: externalOrigin)
          let deprecatedLabel = link.deprecated ? " *(Deprecated)*" : ""
          markdown += "- [\(link.title)](\(link.url))\(deprecatedLabel)"
          if !link.abstract.isEmpty {
            markdown += " \(link.abstract)"
          }
          let condition = renderCondition(
            refs?[id], prefix: .availability, refs: refs, externalOrigin: externalOrigin)
          if !condition.isEmpty {
            markdown += " \(condition)"
          }
          markdown += "\n"
        }
        markdown += "\n"
      }
    }
    return markdown
  }

  public static func renderSeeAlso(
    _ sections: [SeeAlsoSection], variants: [Variant]?, refs: [String: ContentItem]?,
    externalOrigin: String? = nil
  ) -> String {
    var markdown = ""
    for section in sections {
      guard let identifiers = section.identifiers, !section.title.isEmpty else { continue }
      markdown += "## \(section.title)\n\n"
      for id in identifiers {
        let link = resolveLink(
          id, variants: variants, refs: refs, externalOrigin: externalOrigin)
        let condition = renderCondition(
          refs?[id], prefix: .availability, refs: refs, externalOrigin: externalOrigin)
        markdown += "- [\(link.title)](\(link.url))"
        if !condition.isEmpty {
          markdown += " \(condition)"
        }
        markdown += "\n"
      }
      markdown += "\n"
    }
    return markdown
  }

  private struct ResolvedLink {
    let title: String
    let url: String
    let abstract: String
    let deprecated: Bool
  }

  private enum ConditionPrefix {
    case conformance
    case availability
  }

  private static func resolveLink(
    _ id: String, variants: [Variant]?, refs: [String: ContentItem]?,
    externalOrigin: String?
  ) -> ResolvedLink {
    let info = variants?.first { $0.identifier == id }
    let reference = refs?[id]
    let title =
      nonEmpty(info?.title)
      ?? resolveReferenceTitle(
        reference, references: refs, depth: 0, externalOrigin: externalOrigin)
      ?? extractTitleFromIdentifier(id)
    let url = convertIdentifierToURL(id, references: refs, externalOrigin: externalOrigin)
    let abstractContent = info?.abstract ?? reference?.abstract
    let abstract =
      abstractContent.map {
        renderInlineContent($0, references: refs, depth: 0, externalOrigin: externalOrigin)
      } ?? ""
    return ResolvedLink(
      title: title, url: url, abstract: abstract, deprecated: reference?.deprecated == true)
  }

  private static func renderCondition(
    _ reference: ContentItem?,
    prefix: ConditionPrefix,
    refs: [String: ContentItem]?,
    externalOrigin: String?
  ) -> String {
    guard let constraints = reference?.conformance?.constraints, !constraints.isEmpty else {
      return ""
    }
    let prefixItems: [ContentItem]
    switch prefix {
    case .conformance:
      prefixItems = reference?.conformance?.conformancePrefix ?? []
    case .availability:
      prefixItems = reference?.conformance?.availabilityPrefix ?? []
    }
    let inlineContent: [ContentItem]
    if prefixItems.isEmpty {
      inlineContent = constraints
    } else {
      inlineContent = prefixItems + [ContentItem(text: " ", type: "text")] + constraints
    }
    return renderInlineContent(
      inlineContent, references: refs, depth: 0, externalOrigin: externalOrigin
    ).trimmingCharacters(in: .whitespacesAndNewlines)
  }

  public static func normalizeFenceLanguage(_ syntax: String) -> String {
    syntax == "occ" ? "objc" : syntax
  }

  // MARK: - Utility Functions

  public static func mapAsideStyleToCallout(_ style: String) -> String {
    MarkdownFormatting.mapAsideStyleToCallout(style)
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
