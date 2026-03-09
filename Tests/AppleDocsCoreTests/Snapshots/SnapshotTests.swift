import Foundation
import Testing

@testable import AppleDocsCore

@Suite("Snapshot Tests")
struct SnapshotTests {

  private func loadArrayFixture() throws -> AppleDocJSON {
    let fixtureURL = Bundle.module.url(
      forResource: "array", withExtension: "json", subdirectory: "Fixtures")!
    let data = try Data(contentsOf: fixtureURL)
    return try JSONDecoder().decode(AppleDocJSON.self, from: data)
  }

  private func loadHIGFixture() throws -> HIGPageJSON {
    let fixtureURL = Bundle.module.url(
      forResource: "hig-color", withExtension: "json", subdirectory: "Fixtures")!
    let data = try Data(contentsOf: fixtureURL)
    return try JSONDecoder().decode(HIGPageJSON.self, from: data)
  }

  // MARK: - Array fixture snapshots

  @Suite("Array Documentation Snapshot")
  struct ArraySnapshot {
    private func renderArray() throws -> String {
      let fixtureURL = Bundle.module.url(
        forResource: "array", withExtension: "json", subdirectory: "Fixtures")!
      let data = try Data(contentsOf: fixtureURL)
      let json = try JSONDecoder().decode(AppleDocJSON.self, from: data)
      return DocumentRenderer.renderFromJSON(
        json, sourceURL: "https://developer.apple.com/documentation/swift/array")
    }

    @Test("Contains YAML front matter")
    func containsFrontMatter() throws {
      let output = try renderArray()
      #expect(output.hasPrefix("---\n"))
      #expect(output.contains("title: Array"))
      #expect(output.contains("source: https://developer.apple.com/documentation/swift/array"))
    }

    @Test("Contains navigation breadcrumbs")
    func containsBreadcrumbs() throws {
      let output = try renderArray()
      #expect(output.contains("**Navigation:**"))
      #expect(output.contains("[Swift](/documentation/swift)"))
    }

    @Test("Contains title heading")
    func containsTitle() throws {
      let output = try renderArray()
      #expect(output.contains("# Array"))
    }

    @Test("Contains abstract description")
    func containsAbstract() throws {
      let output = try renderArray()
      #expect(output.contains("An ordered, random-access collection."))
    }

    @Test("Contains declaration code block")
    func containsDeclaration() throws {
      let output = try renderArray()
      #expect(output.contains("```swift"))
      #expect(output.contains("@frozen"))
      #expect(output.contains("struct Array"))
    }

    @Test("Contains topic sections")
    func containsTopicSections() throws {
      let output = try renderArray()
      #expect(output.contains("## Creating an Array"))
      #expect(output.contains("## Inspecting an Array"))
      #expect(output.contains("## Accessing Elements"))
      #expect(output.contains("## Adding Elements"))
      #expect(output.contains("## Removing Elements"))
    }

    @Test("Contains topic links with identifiers")
    func containsTopicLinks() throws {
      let output = try renderArray()
      #expect(output.contains("[init()]"))
      #expect(output.contains("[isEmpty]"))
      #expect(output.contains("[count]"))
      #expect(output.contains("[first]"))
      #expect(output.contains("[last]"))
    }

    @Test("Contains footer")
    func containsFooter() throws {
      let output = try renderArray()
      #expect(output.contains("---"))
      #expect(output.contains("swift-developer-docs-mcp"))
    }

    @Test("Output is substantial")
    func outputIsSubstantial() throws {
      let output = try renderArray()
      #expect(output.count > 1000)
    }
  }

  // MARK: - HIG fixture snapshots

  @Suite("HIG Color Documentation Snapshot")
  struct HIGColorSnapshot {
    private func renderHIGColor() throws -> String {
      let fixtureURL = Bundle.module.url(
        forResource: "hig-color", withExtension: "json", subdirectory: "Fixtures")!
      let data = try Data(contentsOf: fixtureURL)
      let pageData = try JSONDecoder().decode(HIGPageJSON.self, from: data)
      return HIGRenderer.renderHIGFromJSON(data: pageData, path: "color")
    }

    @Test("Contains YAML front matter")
    func containsFrontMatter() throws {
      let output = try renderHIGColor()
      #expect(output.hasPrefix("---\n"))
      #expect(output.contains("title: Color"))
    }

    @Test("Contains title heading")
    func containsTitle() throws {
      let output = try renderHIGColor()
      #expect(output.contains("# Color"))
    }

    @Test("Contains abstract")
    func containsAbstract() throws {
      let output = try renderHIGColor()
      #expect(output.contains("Judicious use of color"))
    }

    @Test("Contains best practices heading")
    func containsBestPractices() throws {
      let output = try renderHIGColor()
      #expect(output.contains("## Best practices"))
    }

    @Test("Contains aside callout")
    func containsAside() throws {
      let output = try renderHIGColor()
      #expect(output.contains("> [!IMPORTANT]"))
    }

    @Test("Contains footer")
    func containsFooter() throws {
      let output = try renderHIGColor()
      #expect(output.contains("---"))
      #expect(output.contains("swift-developer-docs-mcp"))
    }

    @Test("Output is substantial")
    func outputIsSubstantial() throws {
      let output = try renderHIGColor()
      #expect(output.count > 500)
    }
  }

  // MARK: - ContentRenderer snapshots

  @Suite("Content Renderer Snapshots")
  struct ContentRendererSnapshot {
    @Test("Renders complex content consistently")
    func complexContent() {
      let content: [ContentItem] = [
        ContentItem(
          type: "heading",
          inlineContent: [ContentItem(text: "Overview", type: "text")],
          level: 2),
        ContentItem(
          type: "paragraph",
          inlineContent: [
            ContentItem(text: "This is a ", type: "text"),
            ContentItem(
              type: "strong",
              inlineContent: [ContentItem(text: "bold", type: "text")]),
            ContentItem(text: " and ", type: "text"),
            ContentItem(
              type: "emphasis",
              inlineContent: [ContentItem(text: "italic", type: "text")]),
            ContentItem(text: " paragraph.", type: "text"),
          ]),
        ContentItem(
          type: "codeListing",
          code: .multiple(["let x = 1", "let y = 2"]),
          syntax: "swift"),
      ]
      let result = ContentRenderer.renderContentArray(content, references: nil)
      #expect(result.contains("## Overview"))
      #expect(result.contains("This is a **bold** and *italic* paragraph."))
      #expect(result.contains("```swift\nlet x = 1\nlet y = 2\n```"))
    }

    @Test("Renders aside with content consistently")
    func asideSnapshot() {
      let content: [ContentItem] = [
        ContentItem(
          type: "aside",
          content: [
            ContentItem(
              type: "paragraph",
              inlineContent: [
                ContentItem(text: "This API is deprecated. Use ", type: "text"),
                ContentItem(type: "codeVoice", code: .single("newAPI()")),
                ContentItem(text: " instead.", type: "text"),
              ])
          ],
          style: "deprecated")
      ]
      let result = ContentRenderer.renderContentArray(content, references: nil)
      #expect(result.contains("> [!WARNING]"))
      #expect(result.contains("> This API is deprecated. Use `newAPI()` instead."))
    }

    @Test("Renders table consistently")
    func tableSnapshot() {
      let table = ContentItem(
        type: "table",
        header: "row",
        rows: [
          [
            [
              ContentItem(
                type: "paragraph", inlineContent: [ContentItem(text: "Property", type: "text")])
            ],
            [
              ContentItem(
                type: "paragraph", inlineContent: [ContentItem(text: "Type", type: "text")])
            ],
            [
              ContentItem(
                type: "paragraph", inlineContent: [ContentItem(text: "Description", type: "text")])
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
            [
              ContentItem(
                type: "paragraph",
                inlineContent: [ContentItem(text: "Number of elements", type: "text")])
            ],
          ],
        ]
      )
      let result = ContentRenderer.renderTable(table, references: nil)
      #expect(result.contains("| Property | Type | Description |"))
      #expect(result.contains("| --- | --- | --- |"))
      #expect(result.contains("| count | Int | Number of elements |"))
    }
  }
}
