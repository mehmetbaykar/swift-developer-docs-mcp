import Foundation

public struct RenderConfig: Sendable {
  public var basePath: String
  public var isExternalDoc: Bool
  public var timestamp: Date
  public var includeFooter: Bool

  public init(
    basePath: String = "",
    isExternalDoc: Bool = false,
    timestamp: Date = Date(),
    includeFooter: Bool = true
  ) {
    self.basePath = basePath
    self.isExternalDoc = isExternalDoc
    self.timestamp = timestamp
    self.includeFooter = includeFooter
  }
}
