import Foundation

// SearchResult and SearchResponse are defined in SearchParser.swift
// This file provides additional search-related types for the injectable SearchClient.

public struct SearchOptions: Sendable {
  public var maxResults: Int
  public var includeDeprecated: Bool

  public init(maxResults: Int = 50, includeDeprecated: Bool = true) {
    self.maxResults = maxResults
    self.includeDeprecated = includeDeprecated
  }
}
