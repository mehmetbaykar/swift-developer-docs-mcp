import Foundation

public struct TextFragment: Codable, Sendable {
  public let text: String?
  public let type: String?
  public let inlineContent: [TextFragment]?

  public init(text: String? = nil, type: String? = nil, inlineContent: [TextFragment]? = nil) {
    self.text = text
    self.type = type
    self.inlineContent = inlineContent
  }
}

public struct Token: Codable, Sendable {
  public let text: String?
  public let kind: String?

  public init(text: String? = nil, kind: String? = nil) {
    self.text = text
    self.kind = kind
  }
}

public enum CodeValue: Codable, Sendable {
  case single(String)
  case multiple([String])

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let string = try? container.decode(String.self) {
      self = .single(string)
    } else if let array = try? container.decode([String].self) {
      self = .multiple(array)
    } else {
      self = .single("")
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .single(let string):
      try container.encode(string)
    case .multiple(let array):
      try container.encode(array)
    }
  }
}

public struct ContentItem: Codable, Sendable {
  public let text: String?
  public let type: String?
  public let title: String?
  public let name: String?
  public let tokens: [Token]?
  public let content: [ContentItem]?
  public let inlineContent: [ContentItem]?
  public let items: [ContentItem]?
  public let code: CodeValue?
  public let syntax: String?
  public let level: Int?
  public let style: String?
  public let identifier: String?
  public let identifiers: [String]?
  public let url: String?
  public let abstract: [TextFragment]?
  public let role: String?
  public let kind: String?
  public let fragments: [FragmentItem]?
  public let conformance: ConformanceInfo?

  public init(
    text: String? = nil, type: String? = nil, title: String? = nil, name: String? = nil,
    tokens: [Token]? = nil, content: [ContentItem]? = nil, inlineContent: [ContentItem]? = nil,
    items: [ContentItem]? = nil, code: CodeValue? = nil, syntax: String? = nil,
    level: Int? = nil, style: String? = nil, identifier: String? = nil,
    identifiers: [String]? = nil, url: String? = nil, abstract: [TextFragment]? = nil,
    role: String? = nil, kind: String? = nil, fragments: [FragmentItem]? = nil,
    conformance: ConformanceInfo? = nil
  ) {
    self.text = text
    self.type = type
    self.title = title
    self.name = name
    self.tokens = tokens
    self.content = content
    self.inlineContent = inlineContent
    self.items = items
    self.code = code
    self.syntax = syntax
    self.level = level
    self.style = style
    self.identifier = identifier
    self.identifiers = identifiers
    self.url = url
    self.abstract = abstract
    self.role = role
    self.kind = kind
    self.fragments = fragments
    self.conformance = conformance
  }
}

public struct FragmentItem: Codable, Sendable {
  public let kind: String
  public let text: String?
  public let preciseIdentifier: String?
}

public struct ConformanceInfo: Codable, Sendable {
  public let constraints: [ConformanceConstraint]?
  public let conformancePrefix: [TextFragment]?
  public let availabilityPrefix: [TextFragment]?
}

public struct ConformanceConstraint: Codable, Sendable {
  public let code: String?
  public let type: String
  public let text: String?
}

public struct Declaration: Codable, Sendable {
  public let tokens: [Token]?

  public init(tokens: [Token]? = nil) {
    self.tokens = tokens
  }
}

public struct Parameter: Codable, Sendable {
  public let name: String
  public let content: [ContentItem]?

  public init(name: String, content: [ContentItem]? = nil) {
    self.name = name
    self.content = content
  }
}

public struct TopicSection: Codable, Sendable {
  public let title: String
  public let identifiers: [String]?
  public let children: [TopicSection]?
  public let abstract: [ContentItem]?
  public let anchor: String?

  public init(
    title: String, identifiers: [String]? = nil, children: [TopicSection]? = nil,
    abstract: [ContentItem]? = nil, anchor: String? = nil
  ) {
    self.title = title
    self.identifiers = identifiers
    self.children = children
    self.abstract = abstract
    self.anchor = anchor
  }
}

public struct SeeAlsoSection: Codable, Sendable {
  public let title: String
  public let identifiers: [String]?

  public init(title: String, identifiers: [String]? = nil) {
    self.title = title
    self.identifiers = identifiers
  }
}

public struct PrimaryContentSection: Codable, Sendable {
  public let kind: String
  public let content: [ContentItem]?
  public let declarations: [Declaration]?
  public let parameters: [Parameter]?

  public init(
    kind: String, content: [ContentItem]? = nil, declarations: [Declaration]? = nil,
    parameters: [Parameter]? = nil
  ) {
    self.kind = kind
    self.content = content
    self.declarations = declarations
    self.parameters = parameters
  }
}

public struct IndexContentItem: Codable, Sendable {
  public let type: String?
  public let title: String?
  public let path: String?
  public let beta: Bool?
  public let children: [IndexContentItem]?
}

public struct SwiftInterfaceItem: Codable, Sendable {
  public let path: String?
  public let title: String?
  public let type: String?
  public let children: [SwiftInterfaceItem]?
  public let external: Bool?
  public let beta: Bool?
}

public struct InterfaceLanguages: Codable, Sendable {
  public let swift: [SwiftInterfaceItem]?
}

public struct Platform: Codable, Sendable {
  public let name: String
  public let introducedAt: String
  public let beta: Bool?

  public init(name: String, introducedAt: String, beta: Bool? = nil) {
    self.name = name
    self.introducedAt = introducedAt
    self.beta = beta
  }
}

public struct DocumentationMetadata: Codable, Sendable {
  public let title: String?
  public let platforms: [Platform]?
  public let roleHeading: String?
  public let symbolKind: String?

  public init(
    title: String? = nil, platforms: [Platform]? = nil,
    roleHeading: String? = nil, symbolKind: String? = nil
  ) {
    self.title = title
    self.platforms = platforms
    self.roleHeading = roleHeading
    self.symbolKind = symbolKind
  }
}

public struct DocumentationIdentifier: Codable, Sendable {
  public let url: String
  public let interfaceLanguage: String?
}

public struct AppleDocJSON: Codable, Sendable {
  public let metadata: DocumentationMetadata?
  public let kind: String?
  public let identifier: DocumentationIdentifier?
  public let abstract: [TextFragment]?
  public let sections: [ContentItem]?
  public let primaryContentSections: [PrimaryContentSection]?
  public let topicSections: [TopicSection]?
  public let seeAlsoSections: [SeeAlsoSection]?
  public let variants: [ContentItem]?
  public let relationshipsSections: [ContentItem]?
  public let references: [String: ContentItem]?
  public let interfaceLanguages: InterfaceLanguages?

  public init(
    metadata: DocumentationMetadata? = nil, kind: String? = nil,
    identifier: DocumentationIdentifier? = nil, abstract: [TextFragment]? = nil,
    sections: [ContentItem]? = nil, primaryContentSections: [PrimaryContentSection]? = nil,
    topicSections: [TopicSection]? = nil, seeAlsoSections: [SeeAlsoSection]? = nil,
    variants: [ContentItem]? = nil, relationshipsSections: [ContentItem]? = nil,
    references: [String: ContentItem]? = nil, interfaceLanguages: InterfaceLanguages? = nil
  ) {
    self.metadata = metadata
    self.kind = kind
    self.identifier = identifier
    self.abstract = abstract
    self.sections = sections
    self.primaryContentSections = primaryContentSections
    self.topicSections = topicSections
    self.seeAlsoSections = seeAlsoSections
    self.variants = variants
    self.relationshipsSections = relationshipsSections
    self.references = references
    self.interfaceLanguages = interfaceLanguages
  }
}
