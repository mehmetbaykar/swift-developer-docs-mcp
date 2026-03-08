import Foundation

public enum AppleDocsError: Error, LocalizedError, Sendable {
  case invalidURL(String)
  case invalidPath
  case httpError(statusCode: Int, url: String)
  case decodingError(underlying: Error)
  case insufficientContent
  case networkError(underlying: Error)
  case notFound
  case accessDenied
  case robotsBlocked
  case ssrfBlocked

  public var errorDescription: String? {
    switch self {
    case .invalidURL(let url):
      return "Invalid URL: \(url)"
    case .invalidPath:
      return "Invalid path. Expected format: swift/array"
    case .httpError(let statusCode, let url):
      return "HTTP \(statusCode) fetching \(url)"
    case .decodingError(let underlying):
      return "Failed to decode: \(underlying.localizedDescription)"
    case .insufficientContent:
      return "Insufficient content returned"
    case .networkError(let underlying):
      return "Network error: \(underlying.localizedDescription)"
    case .notFound:
      return "Resource not found"
    case .accessDenied:
      return "Access denied"
    case .robotsBlocked:
      return "Blocked by robots.txt"
    case .ssrfBlocked:
      return "Request blocked: SSRF protection"
    }
  }
}
