import Foundation
import Testing

@testable import AppleDocsCore

@Suite("RenderingContext Tests")
struct RenderingContextTests {

  @Test("Live context renderInline produces correct output for text fragments")
  func liveRenderInline() {
    let ctx = RenderingContext.live
    let items: [ContentItem] = [
      ContentItem(text: "Hello ", type: "text"),
      ContentItem(type: "codeVoice", code: .single("world")),
    ]
    let result = ctx.renderInline(items, nil, 0)
    #expect(result == "Hello `world`")
  }

  @Test("Live context renderContent produces correct output for paragraph")
  func liveRenderContent() {
    let ctx = RenderingContext.live
    let items: [ContentItem] = [
      ContentItem(
        type: "paragraph",
        inlineContent: [ContentItem(text: "A paragraph.", type: "text")])
    ]
    let result = ctx.renderContent(items, nil, 0)
    #expect(result == "A paragraph.\n\n")
  }

  @Test("Live context convertIdentifierToURL resolves doc:// references")
  func liveConvertIdentifierToURL() {
    let ctx = RenderingContext.live
    let result = ctx.convertIdentifierToURL(
      "doc://com.apple.Swift/documentation/Swift/Array", nil)
    #expect(result == "/documentation/Swift/Array")
  }

  @Test("Live context convertIdentifierToURL uses reference when available")
  func liveConvertWithReference() {
    let ctx = RenderingContext.live
    let refs: [String: ContentItem] = [
      "doc://test": ContentItem(url: "/test/path")
    ]
    let result = ctx.convertIdentifierToURL("doc://test", refs)
    #expect(result == "/test/path")
  }

  @Test("Custom context uses provided closures")
  func customContext() {
    let ctx = RenderingContext(
      renderInline: { _, _, _ in "custom inline" },
      renderContent: { _, _, _ in "custom content" },
      convertIdentifierToURL: { _, _ in "custom url" }
    )
    #expect(ctx.renderInline([], nil, 0) == "custom inline")
    #expect(ctx.renderContent([], nil, 0) == "custom content")
    #expect(ctx.convertIdentifierToURL("id", nil) == "custom url")
  }

  @Test("Live context handles empty inline content")
  func emptyInlineContent() {
    let ctx = RenderingContext.live
    let result = ctx.renderInline([], nil, 0)
    #expect(result == "")
  }

  @Test("Live context handles empty content array")
  func emptyContentArray() {
    let ctx = RenderingContext.live
    let result = ctx.renderContent([], nil, 0)
    #expect(result == "")
  }
}
