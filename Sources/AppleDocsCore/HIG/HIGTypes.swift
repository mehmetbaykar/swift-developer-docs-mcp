import Foundation

// MARK: - HIG Icon Reference

public struct HIGIconReference: Codable, Sendable {
  public let alt: String
  public let identifier: String
  public let type: String
  public let variants: [HIGIconVariant]

  public init(
    alt: String, identifier: String, type: String = "image", variants: [HIGIconVariant] = []
  ) {
    self.alt = alt
    self.identifier = identifier
    self.type = type
    self.variants = variants
  }
}

public struct HIGIconVariant: Codable, Sendable {
  public let traits: [String]
  public let url: String

  public init(traits: [String], url: String) {
    self.traits = traits
    self.url = url
  }
}

// MARK: - HIG Table of Contents

public struct HIGTocItem: Codable, Sendable {
  public let children: [HIGTocItem]?
  public let icon: String?
  public let path: String
  public let title: String
  public let type: String

  public init(
    children: [HIGTocItem]? = nil, icon: String? = nil,
    path: String, title: String, type: String
  ) {
    self.children = children
    self.icon = icon
    self.path = path
    self.title = title
    self.type = type
  }

  public var hasChildren: Bool {
    guard let children else { return false }
    return !children.isEmpty
  }
}

public struct HIGTableOfContents: Codable, Sendable {
  public let includedArchiveIdentifiers: [String]
  public let interfaceLanguages: HIGInterfaceLanguages
  public let references: [String: HIGIconReference]
  public let schemaVersion: SchemaVersion

  public init(
    includedArchiveIdentifiers: [String],
    interfaceLanguages: HIGInterfaceLanguages,
    references: [String: HIGIconReference],
    schemaVersion: SchemaVersion
  ) {
    self.includedArchiveIdentifiers = includedArchiveIdentifiers
    self.interfaceLanguages = interfaceLanguages
    self.references = references
    self.schemaVersion = schemaVersion
  }
}

public struct HIGInterfaceLanguages: Codable, Sendable {
  public let swift: [HIGTocItem]

  public init(swift: [HIGTocItem]) {
    self.swift = swift
  }
}

public struct SchemaVersion: Codable, Sendable {
  public let major: Int
  public let minor: Int
  public let patch: Int

  public init(major: Int, minor: Int, patch: Int) {
    self.major = major
    self.minor = minor
    self.patch = patch
  }
}

// MARK: - HIG Image

public struct HIGImage: Codable, Sendable {
  public let identifier: String
  public let type: String

  public init(identifier: String, type: String) {
    self.identifier = identifier
    self.type = type
  }
}

// MARK: - HIG Metadata

public struct HIGMetadata: Codable, Sendable {
  public let role: String
  public let title: String
  public let images: [HIGImage]?
  public let availableLocales: [String]?

  public init(
    role: String, title: String,
    images: [HIGImage]? = nil, availableLocales: [String]? = nil
  ) {
    self.role = role
    self.title = title
    self.images = images
    self.availableLocales = availableLocales
  }
}

// MARK: - HIG Identifier

public struct HIGIdentifier: Codable, Sendable {
  public let interfaceLanguage: String
  public let url: String

  public init(interfaceLanguage: String, url: String) {
    self.interfaceLanguage = interfaceLanguage
    self.url = url
  }
}

// MARK: - HIG Hierarchy

public struct HIGHierarchy: Codable, Sendable {
  public let paths: [[String]]

  public init(paths: [[String]]) {
    self.paths = paths
  }
}

// MARK: - HIG Topic Section

public struct HIGTopicSection: Codable, Sendable {
  public let title: String?
  public let identifiers: [String]
  public let anchor: String?

  public init(title: String? = nil, identifiers: [String], anchor: String? = nil) {
    self.title = title
    self.identifiers = identifiers
    self.anchor = anchor
  }
}

// MARK: - HIG Image Reference

public struct HIGImageVariant: Codable, Sendable {
  public let traits: [String]
  public let url: String

  public init(traits: [String], url: String) {
    self.traits = traits
    self.url = url
  }
}

public struct HIGImageReference: Codable, Sendable {
  public let alt: String?
  public let identifier: String
  public let type: String
  public let variants: [HIGImageVariant]

  public init(
    alt: String? = nil, identifier: String, type: String, variants: [HIGImageVariant] = []
  ) {
    self.alt = alt
    self.identifier = identifier
    self.type = type
    self.variants = variants
  }
}

// MARK: - HIG Reference (topic)

public struct HIGReference: Codable, Sendable {
  public let kind: String
  public let role: String?
  public let title: String
  public let url: String
  public let abstract: [TextFragment]?
  public let identifier: String
  public let images: [HIGImage]?
  public let type: String

  public init(
    kind: String, role: String? = nil, title: String, url: String,
    abstract: [TextFragment]? = nil, identifier: String,
    images: [HIGImage]? = nil, type: String = "topic"
  ) {
    self.kind = kind
    self.role = role
    self.title = title
    self.url = url
    self.abstract = abstract
    self.identifier = identifier
    self.images = images
    self.type = type
  }
}

// MARK: - HIG External Reference

public struct HIGExternalReference: Codable, Sendable {
  public let title: String
  public let identifier: String
  public let titleInlineContent: [TextFragment]?
  public let url: String
  public let type: String

  public init(
    title: String, identifier: String, titleInlineContent: [TextFragment]? = nil,
    url: String, type: String
  ) {
    self.title = title
    self.identifier = identifier
    self.titleInlineContent = titleInlineContent
    self.url = url
    self.type = type
  }
}

// MARK: - HIG Legal Notices

public struct HIGLegalNotices: Codable, Sendable {
  public let copyright: String
  public let termsOfUse: String
  public let privacy: String?
  public let privacyPolicy: String?

  public init(
    copyright: String, termsOfUse: String,
    privacy: String? = nil, privacyPolicy: String? = nil
  ) {
    self.copyright = copyright
    self.termsOfUse = termsOfUse
    self.privacy = privacy
    self.privacyPolicy = privacyPolicy
  }
}

// MARK: - HIG Reference Union (for references map)

public enum HIGReferenceItem: Codable, Sendable {
  case topic(HIGReference)
  case image(HIGImageReference)
  case external(HIGExternalReference)

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    // Try image reference first (has "alt" and "variants")
    if let image = try? container.decode(HIGImageReference.self),
      image.variants.count > 0
    {
      self = .image(image)
      return
    }
    // Try topic reference (type == "topic")
    if let topic = try? container.decode(HIGReference.self),
      topic.type == "topic"
    {
      self = .topic(topic)
      return
    }
    // Fallback to external
    let external = try container.decode(HIGExternalReference.self)
    self = .external(external)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .topic(let ref):
      try container.encode(ref)
    case .image(let ref):
      try container.encode(ref)
    case .external(let ref):
      try container.encode(ref)
    }
  }

  public var isImageReference: Bool {
    if case .image = self { return true }
    return false
  }

  public var isTopicReference: Bool {
    if case .topic = self { return true }
    return false
  }
}

// MARK: - HIG Page JSON (main structure)

public struct HIGPageJSON: Codable, Sendable {
  public let metadata: HIGMetadata
  public let kind: String
  public let identifier: HIGIdentifier
  public let hierarchy: HIGHierarchy
  public let sections: [ContentItem]
  public let primaryContentSections: [PrimaryContentSection]
  public let abstract: [TextFragment]
  public let topicSections: [HIGTopicSection]?
  public let topicSectionsStyle: String?
  public let references: [String: HIGReferenceItem]
  public let schemaVersion: SchemaVersion
  public let legalNotices: HIGLegalNotices?

  public init(
    metadata: HIGMetadata, kind: String = "article",
    identifier: HIGIdentifier, hierarchy: HIGHierarchy,
    sections: [ContentItem] = [], primaryContentSections: [PrimaryContentSection] = [],
    abstract: [TextFragment] = [], topicSections: [HIGTopicSection]? = nil,
    topicSectionsStyle: String? = nil, references: [String: HIGReferenceItem] = [:],
    schemaVersion: SchemaVersion, legalNotices: HIGLegalNotices? = nil
  ) {
    self.metadata = metadata
    self.kind = kind
    self.identifier = identifier
    self.hierarchy = hierarchy
    self.sections = sections
    self.primaryContentSections = primaryContentSections
    self.abstract = abstract
    self.topicSections = topicSections
    self.topicSectionsStyle = topicSectionsStyle
    self.references = references
    self.schemaVersion = schemaVersion
    self.legalNotices = legalNotices
  }
}
