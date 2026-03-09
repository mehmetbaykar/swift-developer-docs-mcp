import Foundation
import Testing

@testable import AppleDocsCore

@Suite("HIG Types Codable Tests")
struct HIGTypesTests {

  // MARK: - HIGTocItem

  @Suite("HIGTocItem")
  struct HIGTocItemTests {
    @Test("Decodes from JSON")
    func decodeTocItem() throws {
      let json = """
        {
          "path": "/design/human-interface-guidelines/color",
          "title": "Color",
          "type": "article"
        }
        """
      let data = Data(json.utf8)
      let item = try JSONDecoder().decode(HIGTocItem.self, from: data)
      #expect(item.path == "/design/human-interface-guidelines/color")
      #expect(item.title == "Color")
      #expect(item.type == "article")
      #expect(item.children == nil)
      #expect(item.icon == nil)
    }

    @Test("Decodes with children")
    func decodeTocItemWithChildren() throws {
      let json = """
        {
          "path": "/design/human-interface-guidelines/foundations",
          "title": "Foundations",
          "type": "symbol",
          "children": [
            {
              "path": "/design/human-interface-guidelines/color",
              "title": "Color",
              "type": "article"
            }
          ]
        }
        """
      let data = Data(json.utf8)
      let item = try JSONDecoder().decode(HIGTocItem.self, from: data)
      #expect(item.title == "Foundations")
      #expect(item.hasChildren == true)
      #expect(item.children?.count == 1)
      #expect(item.children?.first?.title == "Color")
    }

    @Test("hasChildren returns false when children is nil")
    func hasChildrenNil() {
      let item = HIGTocItem(path: "/test", title: "Test", type: "article")
      #expect(item.hasChildren == false)
    }

    @Test("hasChildren returns false when children is empty")
    func hasChildrenEmpty() {
      let item = HIGTocItem(children: [], path: "/test", title: "Test", type: "article")
      #expect(item.hasChildren == false)
    }

    @Test("Encodes and decodes round-trip")
    func roundTrip() throws {
      let original = HIGTocItem(
        children: [
          HIGTocItem(path: "/child", title: "Child", type: "article")
        ],
        icon: "icon-1",
        path: "/parent",
        title: "Parent",
        type: "symbol"
      )
      let data = try JSONEncoder().encode(original)
      let decoded = try JSONDecoder().decode(HIGTocItem.self, from: data)
      #expect(decoded.path == original.path)
      #expect(decoded.title == original.title)
      #expect(decoded.type == original.type)
      #expect(decoded.icon == original.icon)
      #expect(decoded.children?.count == 1)
    }
  }

  // MARK: - HIGTableOfContents

  @Suite("HIGTableOfContents")
  struct HIGTableOfContentsTests {
    @Test("Decodes from JSON")
    func decodeTableOfContents() throws {
      let json = """
        {
          "includedArchiveIdentifiers": ["com.apple.hig"],
          "interfaceLanguages": {
            "swift": [
              {
                "path": "/design/human-interface-guidelines/foundations",
                "title": "Foundations",
                "type": "symbol"
              }
            ]
          },
          "references": {},
          "schemaVersion": {
            "major": 0,
            "minor": 3,
            "patch": 0
          }
        }
        """
      let data = Data(json.utf8)
      let toc = try JSONDecoder().decode(HIGTableOfContents.self, from: data)
      #expect(toc.includedArchiveIdentifiers == ["com.apple.hig"])
      #expect(toc.interfaceLanguages.swift.count == 1)
      #expect(toc.interfaceLanguages.swift.first?.title == "Foundations")
      #expect(toc.schemaVersion.major == 0)
      #expect(toc.schemaVersion.minor == 3)
      #expect(toc.schemaVersion.patch == 0)
    }

    @Test("Encodes and decodes round-trip")
    func roundTrip() throws {
      let original = HIGTableOfContents(
        includedArchiveIdentifiers: ["test"],
        interfaceLanguages: HIGInterfaceLanguages(swift: [
          HIGTocItem(path: "/test", title: "Test", type: "article")
        ]),
        references: [:],
        schemaVersion: SchemaVersion(major: 1, minor: 2, patch: 3)
      )
      let data = try JSONEncoder().encode(original)
      let decoded = try JSONDecoder().decode(HIGTableOfContents.self, from: data)
      #expect(decoded.includedArchiveIdentifiers == original.includedArchiveIdentifiers)
      #expect(decoded.interfaceLanguages.swift.count == 1)
      #expect(decoded.schemaVersion.major == 1)
    }
  }

  // MARK: - HIGPageJSON

  @Suite("HIGPageJSON")
  struct HIGPageJSONTests {
    @Test("Decodes minimal HIGPageJSON")
    func decodeMinimal() throws {
      let json = """
        {
          "metadata": {
            "role": "article",
            "title": "Color"
          },
          "kind": "article",
          "identifier": {
            "interfaceLanguage": "swift",
            "url": "/design/human-interface-guidelines/color"
          },
          "hierarchy": {
            "paths": [["/design/human-interface-guidelines"]]
          },
          "sections": [],
          "primaryContentSections": [],
          "abstract": [
            {"text": "Use color wisely.", "type": "text"}
          ],
          "references": {},
          "schemaVersion": {
            "major": 0,
            "minor": 3,
            "patch": 0
          }
        }
        """
      let data = Data(json.utf8)
      let page = try JSONDecoder().decode(HIGPageJSON.self, from: data)
      #expect(page.metadata.title == "Color")
      #expect(page.metadata.role == "article")
      #expect(page.kind == "article")
      #expect(page.identifier.url == "/design/human-interface-guidelines/color")
      #expect(page.abstract.first?.text == "Use color wisely.")
      #expect(page.topicSections == nil)
    }

    @Test("Decodes from hig-color fixture")
    func decodeFixture() throws {
      let fixtureURL = Bundle.module.url(
        forResource: "hig-color", withExtension: "json", subdirectory: "Fixtures")!
      let data = try Data(contentsOf: fixtureURL)
      let page = try JSONDecoder().decode(HIGPageJSON.self, from: data)
      #expect(page.metadata.title == "Color")
      #expect(page.kind == "article")
      #expect(!page.primaryContentSections.isEmpty)
    }
  }

  // MARK: - SchemaVersion

  @Suite("SchemaVersion")
  struct SchemaVersionTests {
    @Test("Decodes version numbers")
    func decodeVersion() throws {
      let json = """
        {"major": 1, "minor": 2, "patch": 3}
        """
      let data = Data(json.utf8)
      let version = try JSONDecoder().decode(SchemaVersion.self, from: data)
      #expect(version.major == 1)
      #expect(version.minor == 2)
      #expect(version.patch == 3)
    }
  }

  // MARK: - HIGReferenceItem

  @Suite("HIGReferenceItem")
  struct HIGReferenceItemTests {
    @Test("Decodes topic reference")
    func decodeTopic() throws {
      let json = """
        {
          "kind": "article",
          "role": "article",
          "title": "Color",
          "url": "/design/human-interface-guidelines/color",
          "identifier": "ref-color",
          "type": "topic"
        }
        """
      let data = Data(json.utf8)
      let item = try JSONDecoder().decode(HIGReferenceItem.self, from: data)
      #expect(item.isTopicReference)
      #expect(!item.isImageReference)
    }

    @Test("Decodes image reference")
    func decodeImage() throws {
      let json = """
        {
          "alt": "An image",
          "identifier": "img-1",
          "type": "image",
          "variants": [
            {"traits": ["2x"], "url": "https://example.com/img.png"}
          ]
        }
        """
      let data = Data(json.utf8)
      let item = try JSONDecoder().decode(HIGReferenceItem.self, from: data)
      #expect(item.isImageReference)
      #expect(!item.isTopicReference)
    }
  }
}
