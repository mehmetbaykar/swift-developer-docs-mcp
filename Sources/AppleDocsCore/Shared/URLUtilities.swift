import Foundation

public enum URLUtilities: Sendable {
  static let appleDocBaseURL = "https://developer.apple.com/documentation/"

  public static func normalizeDocumentationPath(_ path: String) -> String {
    let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return "" }
    return trimmed.replacingOccurrences(
      of: #"^\/?(?:documentation\/?)?"#,
      with: "",
      options: .regularExpression
    )
  }

  public static func generateAppleDocURL(_ normalizedPath: String) -> String {
    if normalizedPath.isEmpty { return appleDocBaseURL }
    return "\(appleDocBaseURL)\(normalizedPath)"
  }

  public static func isValidAppleDocURL(_ url: String) -> Bool {
    if url.isEmpty { return false }
    return url.hasPrefix(appleDocBaseURL)
  }
}
