import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public struct ExternalPolicyEnv: Sendable {
  public let hostAllowlist: String?
  public let hostBlocklist: String?

  public init(hostAllowlist: String? = nil, hostBlocklist: String? = nil) {
    self.hostAllowlist = hostAllowlist
    self.hostBlocklist = hostBlocklist
  }
}

public enum ExternalPolicy: Sendable {
  private static let externalPathPrefix = "/external/"

  // MARK: - URL Validation

  public static func validateExternalDocumentationUrl(_ urlString: String) throws -> URL {
    if urlString.isEmpty || hasControlOrWhitespace(urlString) {
      throw AppleDocsError.invalidURL(urlString)
    }

    guard let parsedUrl = URL(string: urlString) else {
      throw AppleDocsError.invalidURL(urlString)
    }

    guard parsedUrl.scheme == "https" else {
      throw AppleDocsError.invalidURL("Only https:// external URLs are supported.")
    }

    if parsedUrl.user != nil || parsedUrl.password != nil {
      throw AppleDocsError.invalidURL("Credentialed URLs are not supported.")
    }

    if let fragment = parsedUrl.fragment, !fragment.isEmpty {
      throw AppleDocsError.invalidURL("URL fragments are not supported.")
    }

    return parsedUrl
  }

  // MARK: - Path Decoding

  public static func decodeExternalTargetPath(_ path: String) throws -> String {
    guard path.hasPrefix(externalPathPrefix) else {
      throw AppleDocsError.invalidPath
    }

    let encodedTarget = String(path.dropFirst(externalPathPrefix.count))
    if encodedTarget.isEmpty {
      throw AppleDocsError.invalidPath
    }

    guard let decodedTarget = encodedTarget.removingPercentEncoding,
      !decodedTarget.isEmpty,
      !hasControlOrWhitespace(decodedTarget)
    else {
      throw AppleDocsError.invalidPath
    }

    return decodedTarget
  }

  // MARK: - Access Policy

  public static func assertExternalDocumentationAccess(
    url: URL,
    env: ExternalPolicyEnv,
    robotsChecker: @Sendable (_ url: URL) async throws -> Bool = { _ in true }
  ) async throws {
    try assertHostPolicy(url: url, env: env)

    let robotsAllowed = try await robotsChecker(url)
    if !robotsAllowed {
      throw AppleDocsError.robotsBlocked
    }
  }

  // MARK: - Host Policy

  static func assertHostPolicy(url: URL, env: ExternalPolicyEnv) throws {
    guard let hostname = url.host?.lowercased() else {
      throw AppleDocsError.invalidURL("Missing hostname")
    }

    let allowlist = parseHostList(env.hostAllowlist)
    let blocklist = parseHostList(env.hostBlocklist)
    let explicitlyAllowlisted = isHostListed(hostname, in: allowlist)

    if isHostListed(hostname, in: blocklist) {
      throw AppleDocsError.accessDenied
    }

    if !allowlist.isEmpty && !explicitlyAllowlisted {
      throw AppleDocsError.accessDenied
    }

    if isLocalOrPrivateHost(hostname) && !explicitlyAllowlisted {
      throw AppleDocsError.ssrfBlocked
    }
  }

  // MARK: - Host List Parsing

  static func parseHostList(_ rawList: String?) -> Set<String> {
    guard let rawList, !rawList.isEmpty else {
      return []
    }

    return Set(
      rawList
        .components(separatedBy: CharacterSet(charactersIn: ",\n\r"))
        .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        .filter { !$0.isEmpty }
    )
  }

  static func isHostListed(_ hostname: String, in list: Set<String>) -> Bool {
    if list.contains(hostname) {
      return true
    }

    for candidate in list {
      if candidate.hasPrefix(".") {
        if hostname.hasSuffix(candidate) {
          return true
        }
        continue
      }

      if hostname == candidate || hostname.hasSuffix(".\(candidate)") {
        return true
      }
    }

    return false
  }

  // MARK: - SSRF Protection

  public static func isLocalOrPrivateHost(_ hostname: String) -> Bool {
    let localHostnames: Set<String> = ["localhost", "127.0.0.1", "::1"]
    if localHostnames.contains(hostname) {
      return true
    }

    if hostname.hasSuffix(".local") {
      return true
    }

    if isPrivateIPv4(hostname) {
      return true
    }

    if isPrivateIPv6(hostname) {
      return true
    }

    return false
  }

  public static func isPrivateIPv4(_ hostname: String) -> Bool {
    let octets = hostname.split(separator: ".")
    guard octets.count == 4 else { return false }

    let octetNumbers = octets.compactMap { Int($0) }
    guard octetNumbers.count == 4, octetNumbers.allSatisfy({ $0 >= 0 && $0 <= 255 }) else {
      return false
    }

    let a = octetNumbers[0]
    let b = octetNumbers[1]

    return a == 10
      || a == 127
      || a == 0
      || (a == 169 && b == 254)
      || (a == 172 && b >= 16 && b <= 31)
      || (a == 192 && b == 168)
  }

  public static func isPrivateIPv6(_ hostname: String) -> Bool {
    let normalized = hostname.lowercased()
      .replacingOccurrences(of: "[", with: "")
      .replacingOccurrences(of: "]", with: "")

    return normalized == "::1"
      || normalized.hasPrefix("fc")
      || normalized.hasPrefix("fd")
      || normalized.hasPrefix("fe8")
      || normalized.hasPrefix("fe9")
      || normalized.hasPrefix("fea")
      || normalized.hasPrefix("feb")
  }

  // MARK: - Utilities

  static func hasControlOrWhitespace(_ value: String) -> Bool {
    for scalar in value.unicodeScalars {
      if scalar.value <= 0x20 || scalar.value == 0x7F {
        return true
      }
    }
    return false
  }
}
