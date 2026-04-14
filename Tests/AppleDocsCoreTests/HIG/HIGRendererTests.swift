import Foundation
import Testing

@testable import AppleDocsCore

@Suite("HIG Renderer Tests")
struct HIGRendererTests {

  private func loadFixtureData() throws -> HIGPageJSON {
    let fixtureURL = Bundle.module.url(
      forResource: "hig-color", withExtension: "json", subdirectory: "Fixtures")!
    let data = try Data(contentsOf: fixtureURL)
    return try JSONDecoder().decode(HIGPageJSON.self, from: data)
  }

  @Test("Renders front matter with title and description")
  func renderFrontMatter() throws {
    let pageData = try loadFixtureData()
    let markdown = HIGRenderer.renderHIGFromJSON(data: pageData, path: "color")

    #expect(markdown.contains("---"))
    #expect(markdown.contains("title: Color"))
    #expect(
      markdown.contains(
        "source: https://developer.apple.com/design/human-interface-guidelines/color"))
  }

  @Test("Renders title as heading")
  func renderTitle() throws {
    let pageData = try loadFixtureData()
    let markdown = HIGRenderer.renderHIGFromJSON(data: pageData, path: "color")

    #expect(markdown.contains("# Color"))
  }

  @Test("Renders abstract as blockquote")
  func renderAbstract() throws {
    let pageData = try loadFixtureData()
    let markdown = HIGRenderer.renderHIGFromJSON(data: pageData, path: "color")

    #expect(markdown.contains("> Judicious use of color"))
  }

  @Test("Renders role heading")
  func renderRoleHeading() throws {
    let pageData = try loadFixtureData()
    let markdown = HIGRenderer.renderHIGFromJSON(data: pageData, path: "color")

    #expect(markdown.contains("**article**"))
  }

  @Test("Renders primary content heading")
  func renderContentHeading() throws {
    let pageData = try loadFixtureData()
    let markdown = HIGRenderer.renderHIGFromJSON(data: pageData, path: "color")

    #expect(markdown.contains("## Best practices"))
  }

  @Test("Renders paragraph content")
  func renderParagraphContent() throws {
    let pageData = try loadFixtureData()
    let markdown = HIGRenderer.renderHIGFromJSON(data: pageData, path: "color")

    #expect(markdown.contains("Use color judiciously"))
  }

  @Test("Renders aside as callout")
  func renderAside() throws {
    let pageData = try loadFixtureData()
    let markdown = HIGRenderer.renderHIGFromJSON(data: pageData, path: "color")

    #expect(markdown.contains("> [!IMPORTANT]"))
    #expect(markdown.contains("Don't rely on color alone"))
  }

  @Test("Renders unordered list items")
  func renderList() throws {
    let pageData = try loadFixtureData()
    let markdown = HIGRenderer.renderHIGFromJSON(data: pageData, path: "color")

    #expect(markdown.contains("- Use system colors when possible."))
    #expect(markdown.contains("- Test your color choices"))
  }

  @Test("Renders topic sections with links")
  func renderTopicSections() throws {
    let pageData = try loadFixtureData()
    let markdown = HIGRenderer.renderHIGFromJSON(data: pageData, path: "color")

    #expect(markdown.contains("## Related Topics"))
    #expect(markdown.contains("[Dark Mode]"))
    #expect(markdown.contains("[Accessibility]"))
  }

  @Test("Renders footer")
  func renderFooter() throws {
    let pageData = try loadFixtureData()
    let markdown = HIGRenderer.renderHIGFromJSON(data: pageData, path: "color")

    #expect(markdown.contains("---"))
    #expect(markdown.contains("swift-developer-docs-mcp"))
    #expect(markdown.contains("Apple Inc."))
  }

  @Test("Renders navigation breadcrumbs for nested path")
  func renderBreadcrumbs() throws {
    let pageData = try loadFixtureData()
    let markdown = HIGRenderer.renderHIGFromJSON(
      data: pageData, path: "foundations/color")

    #expect(markdown.contains("**Navigation:**"))
    #expect(markdown.contains("[Human Interface Guidelines]"))
  }

  // MARK: - Table of Contents

  @Test("Renders table of contents with heading and items")
  func renderTableOfContents() {
    let toc = HIGTableOfContents(
      includedArchiveIdentifiers: [],
      interfaceLanguages: HIGInterfaceLanguages(swift: [
        HIGTocItem(
          children: [
            HIGTocItem(
              path: "/design/human-interface-guidelines/color",
              title: "Color",
              type: "article"
            )
          ],
          path: "/design/human-interface-guidelines/foundations",
          title: "Foundations",
          type: "symbol"
        )
      ]),
      references: [:],
      schemaVersion: SchemaVersion(major: 0, minor: 3, patch: 0)
    )

    let markdown = HIGRenderer.renderHIGTableOfContents(toc: toc)

    #expect(markdown.contains("# Human Interface Guidelines"))
    #expect(markdown.contains("## Foundations"))
    #expect(markdown.contains("- [Color]"))
  }

  // MARK: - Inline content

  @Test("Renders inline emphasis and strong")
  func renderInlineContent() {
    let refs: [String: HIGReferenceItem] = [:]
    let items: [ContentItem] = [
      ContentItem(text: "Hello ", type: "text"),
      ContentItem(
        type: "strong",
        inlineContent: [ContentItem(text: "bold", type: "text")]),
      ContentItem(text: " and ", type: "text"),
      ContentItem(
        type: "emphasis",
        inlineContent: [ContentItem(text: "italic", type: "text")]),
    ]

    let result = HIGRenderer.renderHIGInlineContent(items, references: refs)
    #expect(result == "Hello **bold** and *italic*")
  }

  @Test("Renders code voice inline")
  func renderCodeVoice() {
    let refs: [String: HIGReferenceItem] = [:]
    let items: [ContentItem] = [
      ContentItem(text: "Use ", type: "text"),
      ContentItem(type: "codeVoice", code: .single("UIColor")),
    ]

    let result = HIGRenderer.renderHIGInlineContent(items, references: refs)
    #expect(result == "Use `UIColor`")
  }

  @Test("Renders reference links using references map")
  func renderReferenceLink() {
    let refs: [String: HIGReferenceItem] = [
      "ref-1": .topic(
        HIGReference(
          kind: "article", title: "Color",
          url: "/design/human-interface-guidelines/color",
          identifier: "ref-1"
        ))
    ]

    let items: [ContentItem] = [
      ContentItem(type: "reference", identifier: "ref-1")
    ]

    let result = HIGRenderer.renderHIGInlineContent(items, references: refs)
    #expect(result == "[Color](/design/human-interface-guidelines/color)")
  }

  @Test("Renders links blocks backed by identifier strings")
  func renderStringBackedLinksBlock() {
    let refs: [String: HIGReferenceItem] = [
      "doc://com.apple.hig/documentation/HIG/Color": .topic(
        HIGReference(
          kind: "article",
          title: "Color",
          url: "/design/human-interface-guidelines/color",
          abstract: [TextFragment(text: "Use color intentionally.", type: "text")],
          identifier: "doc://com.apple.hig/documentation/HIG/Color"
        ))
    ]

    let item = ContentItem(
      type: "links",
      itemIdentifiers: ["doc://com.apple.hig/documentation/HIG/Color"],
      style: "compactGrid"
    )

    let result = HIGRenderer.renderHIGContent(sections: [item], references: refs)

    #expect(result.contains("- [Color](/design/human-interface-guidelines/color)"))
    #expect(result.contains("Use color intentionally."))
  }

  // MARK: - Table rendering with rows/header

  @Test("Renders table using rows and header fields")
  func renderTable() {
    let refs: [String: HIGReferenceItem] = [:]
    let item = ContentItem(
      type: "table",
      header: "row",
      rows: [
        // Row 0 (header): two cells
        [
          [
            ContentItem(type: "paragraph", inlineContent: [ContentItem(text: "Name", type: "text")])
          ],
          [
            ContentItem(
              type: "paragraph", inlineContent: [ContentItem(text: "Value", type: "text")])
          ],
        ],
        // Row 1: two cells
        [
          [ContentItem(type: "paragraph", inlineContent: [ContentItem(text: "Red", type: "text")])],
          [
            ContentItem(
              type: "paragraph", inlineContent: [ContentItem(text: "#FF0000", type: "text")])
          ],
        ],
      ]
    )

    let result = HIGRenderer.renderHIGTable(item, references: refs)
    #expect(result.contains("| Name | Value |"))
    #expect(result.contains("| --- | --- |"))
    #expect(result.contains("| Red | #FF0000 |"))
  }

  // MARK: - Row rendering with content columns

  @Test("Renders row columns from item.content")
  func renderRow() {
    let refs: [String: HIGReferenceItem] = [:]
    let item = ContentItem(
      type: "row",
      content: [
        ContentItem(content: [
          ContentItem(
            type: "paragraph", inlineContent: [ContentItem(text: "Column 1", type: "text")])
        ]),
        ContentItem(content: [
          ContentItem(
            type: "paragraph", inlineContent: [ContentItem(text: "Column 2", type: "text")])
        ]),
      ]
    )

    let result = HIGRenderer.renderHIGRow(item, references: refs)
    #expect(result.contains("Column 1"))
    #expect(result.contains("Column 2"))
  }

  // MARK: - Video rendering with abstract

  @Test("Video prefers abstract text over alt for label")
  func renderVideoWithAbstract() {
    let refs: [String: HIGReferenceItem] = [
      "video-1": .image(
        HIGImageReference(
          alt: "Fallback Alt",
          identifier: "video-1",
          type: "image",
          variants: [HIGImageVariant(traits: ["2x"], url: "https://example.com/video.mp4")]
        ))
    ]

    let item = ContentItem(
      type: "video",
      identifier: "video-1",
      abstract: [TextFragment(text: "A demo of color usage", type: "text")]
    )

    let result = HIGRenderer.renderHIGVideo(item, references: refs)
    #expect(result.contains("[A demo of color usage]"))
    #expect(!result.contains("Fallback Alt"))
  }

  @Test("Video falls back to alt when no abstract")
  func renderVideoFallbackToAlt() {
    let refs: [String: HIGReferenceItem] = [
      "video-1": .image(
        HIGImageReference(
          alt: "Alt Text",
          identifier: "video-1",
          type: "image",
          variants: [HIGImageVariant(traits: ["2x"], url: "https://example.com/video.mp4")]
        ))
    ]

    let item = ContentItem(type: "video", identifier: "video-1")

    let result = HIGRenderer.renderHIGVideo(item, references: refs)
    #expect(result.contains("[Alt Text]"))
  }
}
