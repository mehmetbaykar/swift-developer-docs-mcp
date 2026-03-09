import Foundation
import Testing

@testable import AppleDocsCore

@Suite("ContentRenderer Tests")
struct ContentRendererTests {

  // MARK: - renderInlineContent

  @Suite("Inline Content Rendering")
  struct InlineContent {
    @Test("Renders plain text")
    func plainText() {
      let items = [ContentItem(text: "Hello world", type: "text")]
      let result = ContentRenderer.renderInlineContent(items, references: nil)
      #expect(result == "Hello world")
    }

    @Test("Renders codeVoice with single string")
    func codeVoiceSingle() {
      let items = [ContentItem(type: "codeVoice", code: .single("Array"))]
      let result = ContentRenderer.renderInlineContent(items, references: nil)
      #expect(result == "`Array`")
    }

    @Test("Renders codeVoice with multiple strings")
    func codeVoiceMultiple() {
      let items = [ContentItem(type: "codeVoice", code: .multiple(["let ", "x"]))]
      let result = ContentRenderer.renderInlineContent(items, references: nil)
      #expect(result == "`let x`")
    }

    @Test("Renders emphasis")
    func emphasis() {
      let items = [
        ContentItem(
          type: "emphasis",
          inlineContent: [ContentItem(text: "italic", type: "text")])
      ]
      let result = ContentRenderer.renderInlineContent(items, references: nil)
      #expect(result == "*italic*")
    }

    @Test("Renders strong")
    func strong() {
      let items = [
        ContentItem(
          type: "strong",
          inlineContent: [ContentItem(text: "bold", type: "text")])
      ]
      let result = ContentRenderer.renderInlineContent(items, references: nil)
      #expect(result == "**bold**")
    }

    @Test("Renders mixed inline content")
    func mixedInline() {
      let items: [ContentItem] = [
        ContentItem(text: "Use ", type: "text"),
        ContentItem(type: "codeVoice", code: .single("Array")),
        ContentItem(text: " for ", type: "text"),
        ContentItem(
          type: "emphasis",
          inlineContent: [ContentItem(text: "ordered", type: "text")]),
        ContentItem(text: " collections.", type: "text"),
      ]
      let result = ContentRenderer.renderInlineContent(items, references: nil)
      #expect(result == "Use `Array` for *ordered* collections.")
    }

    @Test("Renders superscript")
    func superscript() {
      let items = [
        ContentItem(
          type: "superscript",
          inlineContent: [ContentItem(text: "2", type: "text")])
      ]
      let result = ContentRenderer.renderInlineContent(items, references: nil)
      #expect(result == "<sup>2</sup>")
    }

    @Test("Renders strikethrough")
    func strikethrough() {
      let items = [
        ContentItem(
          type: "strikethrough",
          inlineContent: [ContentItem(text: "removed", type: "text")])
      ]
      let result = ContentRenderer.renderInlineContent(items, references: nil)
      #expect(result == "~~removed~~")
    }

    @Test("Returns empty string for empty array")
    func emptyArray() {
      let result = ContentRenderer.renderInlineContent([], references: nil)
      #expect(result == "")
    }

    @Test("Handles nil inlineContent in emphasis")
    func emphasisNilContent() {
      let items = [ContentItem(type: "emphasis")]
      let result = ContentRenderer.renderInlineContent(items, references: nil)
      #expect(result == "**")
    }

    @Test("Returns depth-exceeded message for deeply nested content")
    func depthExceeded() {
      let items = [ContentItem(text: "deep", type: "text")]
      let result = ContentRenderer.renderInlineContent(items, references: nil, depth: 11)
      #expect(result == "[Inline content too deeply nested]")
    }
  }

  // MARK: - renderContentArray

  @Suite("Content Array Rendering")
  struct ContentArray {
    @Test("Renders heading with correct level")
    func heading() {
      let items = [
        ContentItem(
          type: "heading",
          inlineContent: [ContentItem(text: "Overview", type: "text")],
          level: 2)
      ]
      let result = ContentRenderer.renderContentArray(items, references: nil)
      #expect(result.contains("## Overview"))
    }

    @Test("Renders heading level capped at 6")
    func headingMaxLevel() {
      let items = [
        ContentItem(text: "Deep heading", type: "heading", level: 10)
      ]
      let result = ContentRenderer.renderContentArray(items, references: nil)
      #expect(result.hasPrefix("###### Deep heading"))
    }

    @Test("Renders paragraph")
    func paragraph() {
      let items = [
        ContentItem(
          type: "paragraph",
          inlineContent: [ContentItem(text: "Hello world.", type: "text")])
      ]
      let result = ContentRenderer.renderContentArray(items, references: nil)
      #expect(result == "Hello world.\n\n")
    }

    @Test("Renders codeListing")
    func codeListing() {
      let items = [
        ContentItem(
          type: "codeListing", code: .multiple(["let x = 1", "print(x)"]), syntax: "swift")
      ]
      let result = ContentRenderer.renderContentArray(items, references: nil)
      #expect(result.contains("```swift\nlet x = 1\nprint(x)\n```"))
    }

    @Test("Renders codeListing with default syntax")
    func codeListingDefaultSyntax() {
      let items = [
        ContentItem(type: "codeListing", code: .single("let x = 1"))
      ]
      let result = ContentRenderer.renderContentArray(items, references: nil)
      #expect(result.contains("```swift\nlet x = 1\n```"))
    }

    @Test("Renders unordered list")
    func unorderedList() {
      let items = [
        ContentItem(
          type: "unorderedList",
          items: [
            ContentItem(
              content: [
                ContentItem(
                  type: "paragraph",
                  inlineContent: [ContentItem(text: "Item 1", type: "text")])
              ]),
            ContentItem(
              content: [
                ContentItem(
                  type: "paragraph",
                  inlineContent: [ContentItem(text: "Item 2", type: "text")])
              ]),
          ])
      ]
      let result = ContentRenderer.renderContentArray(items, references: nil)
      #expect(result.contains("- Item 1"))
      #expect(result.contains("- Item 2"))
    }

    @Test("Renders ordered list")
    func orderedList() {
      let items = [
        ContentItem(
          type: "orderedList",
          items: [
            ContentItem(
              content: [
                ContentItem(
                  type: "paragraph",
                  inlineContent: [ContentItem(text: "First", type: "text")])
              ]),
            ContentItem(
              content: [
                ContentItem(
                  type: "paragraph",
                  inlineContent: [ContentItem(text: "Second", type: "text")])
              ]),
          ])
      ]
      let result = ContentRenderer.renderContentArray(items, references: nil)
      #expect(result.contains("1. First"))
      #expect(result.contains("2. Second"))
    }

    @Test("Returns empty string for empty content array")
    func emptyContentArray() {
      let result = ContentRenderer.renderContentArray([], references: nil)
      #expect(result == "")
    }

    @Test("Returns depth-exceeded message for deeply nested content")
    func contentDepthExceeded() {
      let items = [
        ContentItem(
          type: "paragraph",
          inlineContent: [ContentItem(text: "deep", type: "text")])
      ]
      let result = ContentRenderer.renderContentArray(items, references: nil, depth: 11)
      #expect(result == "[Content too deeply nested]")
    }
  }

  // MARK: - renderTable

  @Suite("Table Rendering")
  struct TableRendering {
    @Test("Renders table with header row")
    func tableWithHeader() {
      let item = ContentItem(
        type: "table",
        header: "row",
        rows: [
          [
            [
              ContentItem(
                type: "paragraph", inlineContent: [ContentItem(text: "Name", type: "text")])
            ],
            [
              ContentItem(
                type: "paragraph", inlineContent: [ContentItem(text: "Type", type: "text")])
            ],
          ],
          [
            [
              ContentItem(
                type: "paragraph", inlineContent: [ContentItem(text: "count", type: "text")])
            ],
            [
              ContentItem(
                type: "paragraph", inlineContent: [ContentItem(text: "Int", type: "text")])
            ],
          ],
        ]
      )
      let result = ContentRenderer.renderTable(item, references: nil)
      #expect(result.contains("| Name | Type |"))
      #expect(result.contains("| --- | --- |"))
      #expect(result.contains("| count | Int |"))
    }

    @Test("Renders table without header row")
    func tableWithoutHeader() {
      let item = ContentItem(
        type: "table",
        rows: [
          [
            [ContentItem(type: "paragraph", inlineContent: [ContentItem(text: "A", type: "text")])],
            [ContentItem(type: "paragraph", inlineContent: [ContentItem(text: "B", type: "text")])],
          ]
        ]
      )
      let result = ContentRenderer.renderTable(item, references: nil)
      #expect(result.contains("| A | B |"))
      #expect(!result.contains("| --- | --- |"))
    }

    @Test("Escapes pipe characters in cell content")
    func pipeEscaping() {
      let item = ContentItem(
        type: "table",
        rows: [
          [
            [
              ContentItem(
                type: "paragraph", inlineContent: [ContentItem(text: "a|b", type: "text")])
            ]
          ]
        ]
      )
      let result = ContentRenderer.renderTable(item, references: nil)
      #expect(result.contains("a\\|b"))
    }

    @Test("Returns empty string for table with no rows")
    func emptyTable() {
      let item = ContentItem(type: "table", rows: [])
      let result = ContentRenderer.renderTable(item, references: nil)
      #expect(result == "")
    }

    @Test("Returns empty string for table with nil rows")
    func nilRowsTable() {
      let item = ContentItem(type: "table")
      let result = ContentRenderer.renderTable(item, references: nil)
      #expect(result == "")
    }
  }

  // MARK: - renderAside

  @Suite("Aside Rendering")
  struct AsideRendering {
    @Test("Renders note aside")
    func noteAside() {
      let item = ContentItem(
        type: "aside",
        content: [
          ContentItem(
            type: "paragraph",
            inlineContent: [ContentItem(text: "This is a note.", type: "text")])
        ],
        style: "note")
      let result = ContentRenderer.renderAside(item, references: nil)
      #expect(result.contains("> [!NOTE]"))
      #expect(result.contains("> This is a note."))
    }

    @Test("Renders warning aside")
    func warningAside() {
      let item = ContentItem(
        type: "aside",
        content: [
          ContentItem(
            type: "paragraph",
            inlineContent: [ContentItem(text: "Be careful!", type: "text")])
        ],
        style: "warning")
      let result = ContentRenderer.renderAside(item, references: nil)
      #expect(result.contains("> [!WARNING]"))
    }

    @Test("Renders important aside")
    func importantAside() {
      let item = ContentItem(
        type: "aside",
        content: [
          ContentItem(
            type: "paragraph",
            inlineContent: [ContentItem(text: "Important info.", type: "text")])
        ],
        style: "important")
      let result = ContentRenderer.renderAside(item, references: nil)
      #expect(result.contains("> [!IMPORTANT]"))
    }

    @Test("Renders tip aside")
    func tipAside() {
      let item = ContentItem(
        type: "aside",
        content: [
          ContentItem(
            type: "paragraph",
            inlineContent: [ContentItem(text: "A helpful tip.", type: "text")])
        ],
        style: "tip")
      let result = ContentRenderer.renderAside(item, references: nil)
      #expect(result.contains("> [!TIP]"))
    }

    @Test("Defaults to note when style is nil")
    func defaultStyle() {
      let item = ContentItem(
        type: "aside",
        content: [
          ContentItem(
            type: "paragraph",
            inlineContent: [ContentItem(text: "Default note.", type: "text")])
        ])
      let result = ContentRenderer.renderAside(item, references: nil)
      #expect(result.contains("> [!NOTE]"))
    }
  }

  // MARK: - convertIdentifierToURL

  @Suite("Identifier to URL Conversion")
  struct IdentifierToURL {
    @Test("Converts SwiftUI doc identifier")
    func swiftUI() {
      let result = ContentRenderer.convertIdentifierToURL(
        "doc://com.apple.SwiftUI/documentation/SwiftUI/View",
        references: nil)
      #expect(result == "/documentation/SwiftUI/View")
    }

    @Test("Converts other Apple framework identifiers")
    func otherFrameworks() {
      let result = ContentRenderer.convertIdentifierToURL(
        "doc://com.apple.Swift/documentation/Swift/Array",
        references: nil)
      #expect(result == "/documentation/Swift/Array")
    }

    @Test("Uses reference URL when available")
    func referenceURL() {
      let refs: [String: ContentItem] = [
        "doc://test/ref": ContentItem(url: "/custom/path")
      ]
      let result = ContentRenderer.convertIdentifierToURL(
        "doc://test/ref", references: refs)
      #expect(result == "/custom/path")
    }

    @Test("Falls back to identifier when no reference found")
    func fallbackToIdentifier() {
      let result = ContentRenderer.convertIdentifierToURL(
        "unknown://id/format", references: nil)
      #expect(result == "unknown://id/format")
    }

    @Test("Handles generic doc:// prefix")
    func genericDocPrefix() {
      let result = ContentRenderer.convertIdentifierToURL(
        "doc://com.example.MyLib/documentation/MyLib/MyType",
        references: nil)
      #expect(result == "/documentation/MyLib/MyType")
    }
  }

  // MARK: - mapAsideStyleToCallout

  @Suite("Aside Style Mapping")
  struct AsideStyleMapping {
    @Test("Maps all known styles correctly")
    func knownStyles() {
      #expect(ContentRenderer.mapAsideStyleToCallout("warning") == "WARNING")
      #expect(ContentRenderer.mapAsideStyleToCallout("important") == "IMPORTANT")
      #expect(ContentRenderer.mapAsideStyleToCallout("caution") == "CAUTION")
      #expect(ContentRenderer.mapAsideStyleToCallout("tip") == "TIP")
      #expect(ContentRenderer.mapAsideStyleToCallout("experiment") == "NOTE")
      #expect(ContentRenderer.mapAsideStyleToCallout("deprecated") == "WARNING")
    }

    @Test("Defaults unknown styles to NOTE")
    func unknownStyle() {
      #expect(ContentRenderer.mapAsideStyleToCallout("custom") == "NOTE")
      #expect(ContentRenderer.mapAsideStyleToCallout("") == "NOTE")
    }

    @Test("Is case-insensitive")
    func caseInsensitive() {
      #expect(ContentRenderer.mapAsideStyleToCallout("WARNING") == "WARNING")
      #expect(ContentRenderer.mapAsideStyleToCallout("Tip") == "TIP")
    }
  }

  // MARK: - extractTitleFromIdentifier

  @Suite("Title Extraction")
  struct TitleExtraction {
    @Test("Extracts method signatures")
    func methodSignatures() {
      let result = ContentRenderer.extractTitleFromIdentifier(
        "doc://test/init(exactly:)-63925")
      #expect(result == "init(exactly:)")
    }

    @Test("Extracts simple property name")
    func simpleProperty() {
      let result = ContentRenderer.extractTitleFromIdentifier(
        "doc://test/documentation/Swift/Array/count")
      #expect(result == "count")
    }

    @Test("Returns identifier when no parts")
    func emptyIdentifier() {
      let result = ContentRenderer.extractTitleFromIdentifier("")
      #expect(result == "")
    }
  }
}
