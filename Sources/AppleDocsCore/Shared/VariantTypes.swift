import Foundation

// MARK: - Language Variant

public struct LanguageVariant: Codable, Sendable {
  public let title: String?
  public let abstract: [TextFragment]?
  public let identifier: String?
  public let type: String?
  public let role: String?
  public let kind: String?
  public let traits: [LanguageTrait]
  public let paths: [String]

  public init(
    title: String? = nil, abstract: [TextFragment]? = nil, identifier: String? = nil,
    type: String? = nil, role: String? = nil, kind: String? = nil,
    traits: [LanguageTrait] = [], paths: [String] = []
  ) {
    self.title = title
    self.abstract = abstract
    self.identifier = identifier
    self.type = type
    self.role = role
    self.kind = kind
    self.traits = traits
    self.paths = paths
  }
}

public struct LanguageTrait: Codable, Sendable {
  public let interfaceLanguage: String

  public init(interfaceLanguage: String) {
    self.interfaceLanguage = interfaceLanguage
  }
}

// MARK: - Image Variant

public struct ImageVariant: Codable, Sendable {
  public let title: String?
  public let abstract: [TextFragment]?
  public let identifier: String?
  public let type: String?
  public let role: String?
  public let kind: String?
  public let url: String
  public let traits: [String]

  public init(
    title: String? = nil, abstract: [TextFragment]? = nil, identifier: String? = nil,
    type: String? = nil, role: String? = nil, kind: String? = nil,
    url: String, traits: [String] = []
  ) {
    self.title = title
    self.abstract = abstract
    self.identifier = identifier
    self.type = type
    self.role = role
    self.kind = kind
    self.url = url
    self.traits = traits
  }
}

// MARK: - Symbol Variant

public struct SymbolVariant: Codable, Sendable {
  public let title: String?
  public let abstract: [TextFragment]?
  public let identifier: String?
  public let type: String?
  public let role: String?
  public let kind: String?
  public let url: String?
  public let fragments: [FragmentItem]?
  public let conformance: ConformanceInfo?

  public init(
    title: String? = nil, abstract: [TextFragment]? = nil, identifier: String? = nil,
    type: String? = nil, role: String? = nil, kind: String? = nil,
    url: String? = nil, fragments: [FragmentItem]? = nil, conformance: ConformanceInfo? = nil
  ) {
    self.title = title
    self.abstract = abstract
    self.identifier = identifier
    self.type = type
    self.role = role
    self.kind = kind
    self.url = url
    self.fragments = fragments
    self.conformance = conformance
  }
}

// MARK: - Variant (tagged union via Codable)

public enum Variant: Codable, Sendable {
  case language(LanguageVariant)
  case image(ImageVariant)
  case symbol(SymbolVariant)

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    // Try language variant first (has traits as array of objects with interfaceLanguage)
    if let language = try? container.decode(LanguageVariant.self),
      !language.traits.isEmpty
    {
      self = .language(language)
      return
    }
    // Try symbol variant (has fragments or conformance)
    if let symbol = try? container.decode(SymbolVariant.self),
      symbol.fragments != nil || symbol.conformance != nil
    {
      self = .symbol(symbol)
      return
    }
    // Try image variant (has url and traits as string array)
    if let image = try? container.decode(ImageVariant.self) {
      self = .image(image)
      return
    }
    // Fallback to symbol
    let symbol = try container.decode(SymbolVariant.self)
    self = .symbol(symbol)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .language(let variant):
      try container.encode(variant)
    case .image(let variant):
      try container.encode(variant)
    case .symbol(let variant):
      try container.encode(variant)
    }
  }

  public var title: String? {
    switch self {
    case .language(let v): return v.title
    case .image(let v): return v.title
    case .symbol(let v): return v.title
    }
  }

  public var identifier: String? {
    switch self {
    case .language(let v): return v.identifier
    case .image(let v): return v.identifier
    case .symbol(let v): return v.identifier
    }
  }

  public var abstract: [TextFragment]? {
    switch self {
    case .language(let v): return v.abstract
    case .image(let v): return v.abstract
    case .symbol(let v): return v.abstract
    }
  }
}
