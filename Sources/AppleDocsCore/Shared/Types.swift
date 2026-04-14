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
  public let itemIdentifiers: [String]?
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
  // Table support
  public let header: String?
  public let rows: [[[ContentItem]]]?
  // Image support
  public let alt: String?
  public let variants: [ImageVariantRef]?
  // Additional fields
  public let destination: String?
  public let overridingSymbol: String?
  public let extendedModule: String?

  public init(
    text: String? = nil, type: String? = nil, title: String? = nil, name: String? = nil,
    tokens: [Token]? = nil, content: [ContentItem]? = nil, inlineContent: [ContentItem]? = nil,
    items: [ContentItem]? = nil, itemIdentifiers: [String]? = nil, code: CodeValue? = nil,
    syntax: String? = nil,
    level: Int? = nil, style: String? = nil, identifier: String? = nil,
    identifiers: [String]? = nil, url: String? = nil, abstract: [TextFragment]? = nil,
    role: String? = nil, kind: String? = nil, fragments: [FragmentItem]? = nil,
    conformance: ConformanceInfo? = nil, header: String? = nil,
    rows: [[[ContentItem]]]? = nil, alt: String? = nil,
    variants: [ImageVariantRef]? = nil, destination: String? = nil,
    overridingSymbol: String? = nil, extendedModule: String? = nil
  ) {
    self.text = text
    self.type = type
    self.title = title
    self.name = name
    self.tokens = tokens
    self.content = content
    self.inlineContent = inlineContent
    self.items = items
    self.itemIdentifiers = itemIdentifiers
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
    self.header = header
    self.rows = rows
    self.alt = alt
    self.variants = variants
    self.destination = destination
    self.overridingSymbol = overridingSymbol
    self.extendedModule = extendedModule
  }

  enum CodingKeys: String, CodingKey {
    case text
    case type
    case title
    case name
    case tokens
    case content
    case inlineContent
    case items
    case code
    case syntax
    case level
    case style
    case identifier
    case identifiers
    case url
    case abstract
    case role
    case kind
    case fragments
    case conformance
    case header
    case rows
    case alt
    case variants
    case destination
    case overridingSymbol
    case extendedModule
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.text = try container.decodeIfPresent(String.self, forKey: .text)
    self.type = try container.decodeIfPresent(String.self, forKey: .type)
    self.title = try container.decodeIfPresent(String.self, forKey: .title)
    self.name = try container.decodeIfPresent(String.self, forKey: .name)
    self.tokens = try container.decodeIfPresent([Token].self, forKey: .tokens)
    self.content = try container.decodeIfPresent([ContentItem].self, forKey: .content)
    self.inlineContent = try container.decodeIfPresent([ContentItem].self, forKey: .inlineContent)

    if let decodedItems = try? container.decode([ContentItem].self, forKey: .items) {
      self.items = decodedItems
      self.itemIdentifiers = nil
    } else if let decodedIdentifiers = try? container.decode([String].self, forKey: .items) {
      self.items = nil
      self.itemIdentifiers = decodedIdentifiers
    } else {
      self.items = nil
      self.itemIdentifiers = nil
    }

    self.code = try container.decodeIfPresent(CodeValue.self, forKey: .code)
    self.syntax = try container.decodeIfPresent(String.self, forKey: .syntax)
    self.level = try container.decodeIfPresent(Int.self, forKey: .level)
    self.style = try container.decodeIfPresent(String.self, forKey: .style)
    self.identifier = try container.decodeIfPresent(String.self, forKey: .identifier)
    self.identifiers = try container.decodeIfPresent([String].self, forKey: .identifiers)
    self.url = try container.decodeIfPresent(String.self, forKey: .url)
    self.abstract = try container.decodeIfPresent([TextFragment].self, forKey: .abstract)
    self.role = try container.decodeIfPresent(String.self, forKey: .role)
    self.kind = try container.decodeIfPresent(String.self, forKey: .kind)
    self.fragments = try container.decodeIfPresent([FragmentItem].self, forKey: .fragments)
    self.conformance = try container.decodeIfPresent(ConformanceInfo.self, forKey: .conformance)
    self.header = try container.decodeIfPresent(String.self, forKey: .header)
    self.rows = try container.decodeIfPresent([[[ContentItem]]].self, forKey: .rows)
    self.alt = try container.decodeIfPresent(String.self, forKey: .alt)
    self.variants = try container.decodeIfPresent([ImageVariantRef].self, forKey: .variants)
    self.destination = try container.decodeIfPresent(String.self, forKey: .destination)
    self.overridingSymbol = try container.decodeIfPresent(String.self, forKey: .overridingSymbol)
    self.extendedModule = try container.decodeIfPresent(String.self, forKey: .extendedModule)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encodeIfPresent(text, forKey: .text)
    try container.encodeIfPresent(type, forKey: .type)
    try container.encodeIfPresent(title, forKey: .title)
    try container.encodeIfPresent(name, forKey: .name)
    try container.encodeIfPresent(tokens, forKey: .tokens)
    try container.encodeIfPresent(content, forKey: .content)
    try container.encodeIfPresent(inlineContent, forKey: .inlineContent)
    if let items {
      try container.encode(items, forKey: .items)
    } else {
      try container.encodeIfPresent(itemIdentifiers, forKey: .items)
    }
    try container.encodeIfPresent(code, forKey: .code)
    try container.encodeIfPresent(syntax, forKey: .syntax)
    try container.encodeIfPresent(level, forKey: .level)
    try container.encodeIfPresent(style, forKey: .style)
    try container.encodeIfPresent(identifier, forKey: .identifier)
    try container.encodeIfPresent(identifiers, forKey: .identifiers)
    try container.encodeIfPresent(url, forKey: .url)
    try container.encodeIfPresent(abstract, forKey: .abstract)
    try container.encodeIfPresent(role, forKey: .role)
    try container.encodeIfPresent(kind, forKey: .kind)
    try container.encodeIfPresent(fragments, forKey: .fragments)
    try container.encodeIfPresent(conformance, forKey: .conformance)
    try container.encodeIfPresent(header, forKey: .header)
    try container.encodeIfPresent(rows, forKey: .rows)
    try container.encodeIfPresent(alt, forKey: .alt)
    try container.encodeIfPresent(variants, forKey: .variants)
    try container.encodeIfPresent(destination, forKey: .destination)
    try container.encodeIfPresent(overridingSymbol, forKey: .overridingSymbol)
    try container.encodeIfPresent(extendedModule, forKey: .extendedModule)
  }
}

public struct ImageVariantRef: Codable, Sendable {
  public let url: String
  public let traits: [String]?

  public init(url: String, traits: [String]? = nil) {
    self.url = url
    self.traits = traits
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
  public let items: [PropertyItem]?

  public init(
    kind: String, content: [ContentItem]? = nil, declarations: [Declaration]? = nil,
    parameters: [Parameter]? = nil, items: [PropertyItem]? = nil
  ) {
    self.kind = kind
    self.content = content
    self.declarations = declarations
    self.parameters = parameters
    self.items = items
  }
}

// MARK: - Property Item (data dictionary pages)

public struct PropertyItem: Codable, Sendable {
  public let name: String
  public let required: Bool?
  public let content: [ContentItem]?
  public let type: [PropertyTypeItem]?
  public let attributes: [PropertyAttribute]?

  public init(
    name: String, required: Bool? = nil, content: [ContentItem]? = nil,
    type: [PropertyTypeItem]? = nil, attributes: [PropertyAttribute]? = nil
  ) {
    self.name = name
    self.required = required
    self.content = content
    self.type = type
    self.attributes = attributes
  }
}

public struct PropertyTypeItem: Codable, Sendable {
  public let text: String?
  public let kind: String?
  public let identifier: String?

  public init(text: String? = nil, kind: String? = nil, identifier: String? = nil) {
    self.text = text
    self.kind = kind
    self.identifier = identifier
  }
}

public struct PropertyAttribute: Codable, Sendable {
  public let kind: String?
  public let values: [String]?

  public init(kind: String? = nil, values: [String]? = nil) {
    self.kind = kind
    self.values = values
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

// MARK: - External Origin

public struct ExternalOrigin: Codable, Sendable {
  public let url: String
  public let title: String

  public init(url: String, title: String) {
    self.url = url
    self.title = title
  }
}

// MARK: - Apple Documentation JSON

public struct AppleDocJSON: Codable, Sendable {
  public let metadata: DocumentationMetadata?
  public let kind: String?
  public let identifier: DocumentationIdentifier?
  public let abstract: [TextFragment]?
  public let sections: [ContentItem]?
  public let primaryContentSections: [PrimaryContentSection]?
  public let topicSections: [TopicSection]?
  public let seeAlsoSections: [SeeAlsoSection]?
  public let variants: [Variant]?
  public let relationshipsSections: [ContentItem]?
  public let references: [String: ContentItem]?
  public let interfaceLanguages: InterfaceLanguages?
  public let externalOrigin: ExternalOrigin?

  public init(
    metadata: DocumentationMetadata? = nil, kind: String? = nil,
    identifier: DocumentationIdentifier? = nil, abstract: [TextFragment]? = nil,
    sections: [ContentItem]? = nil, primaryContentSections: [PrimaryContentSection]? = nil,
    topicSections: [TopicSection]? = nil, seeAlsoSections: [SeeAlsoSection]? = nil,
    variants: [Variant]? = nil, relationshipsSections: [ContentItem]? = nil,
    references: [String: ContentItem]? = nil, interfaceLanguages: InterfaceLanguages? = nil,
    externalOrigin: ExternalOrigin? = nil
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
    self.externalOrigin = externalOrigin
  }
}
