import Foundation

public struct RenderingContext: Sendable {
  public var renderInline:
    @Sendable (
      _ inlineContent: [ContentItem], _ references: [String: ContentItem]?, _ depth: Int
    ) -> String
  public var renderContent:
    @Sendable (
      _ content: [ContentItem], _ references: [String: ContentItem]?, _ depth: Int
    ) -> String
  public var convertIdentifierToURL:
    @Sendable (
      _ identifier: String, _ references: [String: ContentItem]?
    ) -> String

  public init(
    renderInline: @escaping @Sendable ([ContentItem], [String: ContentItem]?, Int) -> String,
    renderContent: @escaping @Sendable ([ContentItem], [String: ContentItem]?, Int) -> String,
    convertIdentifierToURL: @escaping @Sendable (String, [String: ContentItem]?) -> String
  ) {
    self.renderInline = renderInline
    self.renderContent = renderContent
    self.convertIdentifierToURL = convertIdentifierToURL
  }
}

extension RenderingContext {
  public static let live = RenderingContext(
    renderInline: { inlineContent, references, depth in
      ContentRenderer.renderInlineContent(inlineContent, references: references, depth: depth)
    },
    renderContent: { content, references, depth in
      ContentRenderer.renderContentArray(content, references: references, depth: depth)
    },
    convertIdentifierToURL: { identifier, references in
      ContentRenderer.convertIdentifierToURL(identifier, references: references)
    }
  )
}
