import Foundation
import Testing

@testable import AppleDocsCore

@Suite("ExternalRenderer")
struct ExternalRendererTests {

  @Suite("External URL Rewriting")
  struct URLRewriting {
    @Test("Rewrites documentation paths to external links")
    func documentationPath() {
      let result = ExternalRenderer.rewriteExternalUrl(
        "/documentation/MyLib/MyType",
        externalOrigin: "https://example.com"
      )
      #expect(result == "/external/https://example.com/documentation/MyLib/MyType")
    }

    @Test("Rewrites tutorials paths to external links")
    func tutorialsPath() {
      let result = ExternalRenderer.rewriteExternalUrl(
        "/tutorials/MyLib/GettingStarted",
        externalOrigin: "https://example.com"
      )
      #expect(result == "/external/https://example.com/tutorials/MyLib/GettingStarted")
    }

    @Test("Preserves non-documentation paths")
    func otherPath() {
      let result = ExternalRenderer.rewriteExternalUrl(
        "/some/other/path",
        externalOrigin: "https://example.com"
      )
      #expect(result == "/some/other/path")
    }

    @Test("Handles origin with base path")
    func originWithBasePath() {
      let result = ExternalRenderer.rewriteExternalUrl(
        "/documentation/MyLib/MyType",
        externalOrigin: "https://example.com/api/v1"
      )
      #expect(result == "/external/https://example.com/api/v1/documentation/MyLib/MyType")
    }

    @Test("Handles empty external origin")
    func emptyOrigin() {
      let result = ExternalRenderer.rewriteExternalUrl(
        "/documentation/MyLib/MyType",
        externalOrigin: ""
      )
      #expect(result == "/documentation/MyLib/MyType")
    }
  }

  @Suite("External Identifier Conversion")
  struct IdentifierConversion {
    @Test("Converts doc:// identifiers to external paths")
    func docIdentifier() {
      let result = ExternalRenderer.convertExternalIdentifierToURL(
        "doc://com.example.TestLib/documentation/TestLib/MyType",
        references: nil,
        externalOrigin: "https://example.com"
      )
      #expect(result == "/external/https://example.com/documentation/TestLib/MyType")
    }

    @Test("Uses reference URL when available")
    func withReference() {
      let refs: [String: ContentItem] = [
        "doc://test/ref": ContentItem(url: "/documentation/TestLib/MyType")
      ]
      let result = ExternalRenderer.convertExternalIdentifierToURL(
        "doc://test/ref",
        references: refs,
        externalOrigin: "https://example.com"
      )
      #expect(result == "/external/https://example.com/documentation/TestLib/MyType")
    }

    @Test("Falls back to identifier for non-doc:// scheme")
    func nonDocScheme() {
      let result = ExternalRenderer.convertExternalIdentifierToURL(
        "custom://other/identifier",
        references: nil,
        externalOrigin: "https://example.com"
      )
      #expect(result == "custom://other/identifier")
    }
  }

  @Suite("Full Rendering")
  struct FullRendering {
    @Test("Renders external documentation from fixture JSON")
    func fixtureRendering() throws {
      let fixtureURL = Bundle.module.url(
        forResource: "external-doc", withExtension: "json", subdirectory: "Fixtures")!
      let data = try Data(contentsOf: fixtureURL)
      let jsonData = try JSONDecoder().decode(AppleDocJSON.self, from: data)

      let sourceUrl = URL(string: "https://example.com/documentation/TestLib/ExampleType")!
      let result = ExternalRenderer.renderExternalDocumentation(
        jsonData: jsonData, sourceUrl: sourceUrl)

      #expect(result.contains("title: ExampleType"))
      #expect(result.contains("**Structure**"))
      #expect(result.contains("# ExampleType"))
      #expect(result.contains("**Available on:** iOS 15.0+, macOS 12.0+"))
      #expect(result.contains("## Overview"))
      #expect(result.contains("```swift"))
      #expect(result.contains("struct ExampleType"))
      #expect(result.contains("swift-developer-docs-mcp"))
    }

    @Test("Rewrites internal links to external paths")
    func linkRewriting() throws {
      let fixtureURL = Bundle.module.url(
        forResource: "external-doc", withExtension: "json", subdirectory: "Fixtures")!
      let data = try Data(contentsOf: fixtureURL)
      let jsonData = try JSONDecoder().decode(AppleDocJSON.self, from: data)

      let sourceUrl = URL(string: "https://example.com/documentation/TestLib/ExampleType")!
      let result = ExternalRenderer.renderExternalDocumentation(
        jsonData: jsonData, sourceUrl: sourceUrl)

      #expect(result.contains("/external/https://example.com/documentation/TestLib/RelatedType"))
    }

    @Test("Renders minimal external document")
    func minimalDocument() {
      let jsonData = AppleDocJSON(
        metadata: DocumentationMetadata(title: "Minimal External Type")
      )
      let sourceUrl = URL(string: "https://docs.example.com/documentation/Lib/Minimal")!
      let result = ExternalRenderer.renderExternalDocumentation(
        jsonData: jsonData, sourceUrl: sourceUrl)

      #expect(result.contains("title: Minimal External Type"))
      #expect(result.contains("# Minimal External Type"))
      #expect(result.contains("source: https://docs.example.com/documentation/Lib/Minimal"))
    }
  }
}
