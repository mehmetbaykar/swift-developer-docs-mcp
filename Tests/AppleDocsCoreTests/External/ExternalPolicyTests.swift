import Foundation
import Testing

@testable import AppleDocsCore

@Suite("ExternalPolicy")
struct ExternalPolicyTests {

  @Suite("URL Validation")
  struct URLValidation {
    @Test("Accepts valid HTTPS URL")
    func validHttps() throws {
      let url = try ExternalPolicy.validateExternalDocumentationUrl(
        "https://example.com/documentation/MyLib")
      #expect(url.scheme == "https")
      #expect(url.host == "example.com")
    }

    @Test("Rejects HTTP URL")
    func rejectsHttp() {
      #expect(throws: AppleDocsError.self) {
        try ExternalPolicy.validateExternalDocumentationUrl(
          "http://example.com/documentation/MyLib")
      }
    }

    @Test("Rejects empty URL")
    func rejectsEmpty() {
      #expect(throws: AppleDocsError.self) {
        try ExternalPolicy.validateExternalDocumentationUrl("")
      }
    }

    @Test("Rejects URL with credentials")
    func rejectsCredentials() {
      #expect(throws: AppleDocsError.self) {
        try ExternalPolicy.validateExternalDocumentationUrl(
          "https://user:pass@example.com/documentation/MyLib")
      }
    }

    @Test("Rejects URL with fragment")
    func rejectsFragment() {
      #expect(throws: AppleDocsError.self) {
        try ExternalPolicy.validateExternalDocumentationUrl(
          "https://example.com/documentation/MyLib#section")
      }
    }

    @Test("Rejects URL with whitespace")
    func rejectsWhitespace() {
      #expect(throws: AppleDocsError.self) {
        try ExternalPolicy.validateExternalDocumentationUrl(
          "https://example.com/doc path")
      }
    }

    @Test("Rejects URL with control characters")
    func rejectsControl() {
      #expect(throws: AppleDocsError.self) {
        try ExternalPolicy.validateExternalDocumentationUrl("https://example.com/\u{01}path")
      }
    }
  }

  @Suite("Path Decoding")
  struct PathDecoding {
    @Test("Decodes valid external path")
    func validPath() throws {
      let result = try ExternalPolicy.decodeExternalTargetPath(
        "/external/https%3A%2F%2Fexample.com%2Fdocumentation%2FMyLib")
      #expect(result == "https://example.com/documentation/MyLib")
    }

    @Test("Rejects path without external prefix")
    func missingPrefix() {
      #expect(throws: AppleDocsError.self) {
        try ExternalPolicy.decodeExternalTargetPath("/other/path")
      }
    }

    @Test("Rejects empty encoded target")
    func emptyTarget() {
      #expect(throws: AppleDocsError.self) {
        try ExternalPolicy.decodeExternalTargetPath("/external/")
      }
    }
  }

  @Suite("SSRF Protection")
  struct SSRFProtection {
    @Test("Detects localhost as private")
    func localhost() {
      #expect(ExternalPolicy.isLocalOrPrivateHost("localhost"))
      #expect(ExternalPolicy.isLocalOrPrivateHost("127.0.0.1"))
      #expect(ExternalPolicy.isLocalOrPrivateHost("::1"))
    }

    @Test("Detects .local hostnames as private")
    func localDomain() {
      #expect(ExternalPolicy.isLocalOrPrivateHost("myhost.local"))
      #expect(ExternalPolicy.isLocalOrPrivateHost("anything.local"))
    }

    @Test("Detects private IPv4 ranges")
    func privateIPv4() {
      #expect(ExternalPolicy.isPrivateIPv4("10.0.0.1"))
      #expect(ExternalPolicy.isPrivateIPv4("10.255.255.255"))
      #expect(ExternalPolicy.isPrivateIPv4("172.16.0.1"))
      #expect(ExternalPolicy.isPrivateIPv4("172.31.255.255"))
      #expect(ExternalPolicy.isPrivateIPv4("192.168.0.1"))
      #expect(ExternalPolicy.isPrivateIPv4("192.168.255.255"))
      #expect(ExternalPolicy.isPrivateIPv4("127.0.0.1"))
      #expect(ExternalPolicy.isPrivateIPv4("0.0.0.0"))
      #expect(ExternalPolicy.isPrivateIPv4("169.254.0.1"))
    }

    @Test("Allows public IPv4 addresses")
    func publicIPv4() {
      #expect(!ExternalPolicy.isPrivateIPv4("8.8.8.8"))
      #expect(!ExternalPolicy.isPrivateIPv4("1.1.1.1"))
      #expect(!ExternalPolicy.isPrivateIPv4("93.184.216.34"))
      #expect(!ExternalPolicy.isPrivateIPv4("172.15.0.1"))
      #expect(!ExternalPolicy.isPrivateIPv4("172.32.0.1"))
    }

    @Test("Detects private IPv6 addresses")
    func privateIPv6() {
      #expect(ExternalPolicy.isPrivateIPv6("::1"))
      #expect(ExternalPolicy.isPrivateIPv6("fc00::1"))
      #expect(ExternalPolicy.isPrivateIPv6("fd00::1"))
      #expect(ExternalPolicy.isPrivateIPv6("fe80::1"))
      #expect(ExternalPolicy.isPrivateIPv6("[fe80::1]"))
    }

    @Test("Allows public IPv6 addresses")
    func publicIPv6() {
      #expect(!ExternalPolicy.isPrivateIPv6("2001:db8::1"))
      #expect(!ExternalPolicy.isPrivateIPv6("2607:f8b0:4004:800::200e"))
    }

    @Test("Does not flag public hostnames as private")
    func publicHostnames() {
      #expect(!ExternalPolicy.isLocalOrPrivateHost("example.com"))
      #expect(!ExternalPolicy.isLocalOrPrivateHost("docs.swift.org"))
      #expect(!ExternalPolicy.isLocalOrPrivateHost("developer.apple.com"))
    }
  }

  @Suite("Host Policy")
  struct HostPolicy {
    @Test("Blocks hosts on blocklist")
    func blocklist() throws {
      let env = ExternalPolicyEnv(hostBlocklist: "blocked.com,evil.org")
      #expect(throws: AppleDocsError.self) {
        try ExternalPolicy.assertHostPolicy(
          url: URL(string: "https://blocked.com/documentation/Lib")!,
          env: env)
      }
    }

    @Test("Allows hosts not on blocklist")
    func notBlocked() throws {
      let env = ExternalPolicyEnv(hostBlocklist: "blocked.com")
      try ExternalPolicy.assertHostPolicy(
        url: URL(string: "https://allowed.com/documentation/Lib")!,
        env: env)
    }

    @Test("Requires allowlist membership when allowlist is set")
    func allowlistEnforced() throws {
      let env = ExternalPolicyEnv(hostAllowlist: "docs.example.com")
      #expect(throws: AppleDocsError.self) {
        try ExternalPolicy.assertHostPolicy(
          url: URL(string: "https://other.com/documentation/Lib")!,
          env: env)
      }
    }

    @Test("Allows hosts on allowlist")
    func onAllowlist() throws {
      let env = ExternalPolicyEnv(hostAllowlist: "docs.example.com")
      try ExternalPolicy.assertHostPolicy(
        url: URL(string: "https://docs.example.com/documentation/Lib")!,
        env: env)
    }

    @Test("Blocks local hosts without explicit allowlist")
    func blocksLocalHosts() {
      let env = ExternalPolicyEnv()
      #expect(throws: AppleDocsError.self) {
        try ExternalPolicy.assertHostPolicy(
          url: URL(string: "https://localhost/documentation/Lib")!,
          env: env)
      }
    }

    @Test("Allows local hosts when explicitly allowlisted")
    func allowlistedLocal() throws {
      let env = ExternalPolicyEnv(hostAllowlist: "localhost")
      try ExternalPolicy.assertHostPolicy(
        url: URL(string: "https://localhost/documentation/Lib")!,
        env: env)
    }

    @Test("Supports subdomain matching in host lists")
    func subdomainMatching() throws {
      let env = ExternalPolicyEnv(hostBlocklist: "evil.org")
      #expect(throws: AppleDocsError.self) {
        try ExternalPolicy.assertHostPolicy(
          url: URL(string: "https://sub.evil.org/documentation/Lib")!,
          env: env)
      }
    }

    @Test("Supports dot-prefix wildcard matching")
    func dotPrefixMatching() throws {
      let env = ExternalPolicyEnv(hostBlocklist: ".evil.org")
      #expect(throws: AppleDocsError.self) {
        try ExternalPolicy.assertHostPolicy(
          url: URL(string: "https://sub.evil.org/documentation/Lib")!,
          env: env)
      }
    }
  }

  @Suite("Host List Parsing")
  struct HostListParsing {
    @Test("Parses comma-separated list")
    func commaSeparated() {
      let result = ExternalPolicy.parseHostList("example.com,test.org,docs.swift.org")
      #expect(result.count == 3)
      #expect(result.contains("example.com"))
      #expect(result.contains("test.org"))
      #expect(result.contains("docs.swift.org"))
    }

    @Test("Parses newline-separated list")
    func newlineSeparated() {
      let result = ExternalPolicy.parseHostList("example.com\ntest.org\ndocs.swift.org")
      #expect(result.count == 3)
    }

    @Test("Handles nil input")
    func nilInput() {
      let result = ExternalPolicy.parseHostList(nil)
      #expect(result.isEmpty)
    }

    @Test("Handles empty input")
    func emptyInput() {
      let result = ExternalPolicy.parseHostList("")
      #expect(result.isEmpty)
    }

    @Test("Normalizes to lowercase")
    func lowercased() {
      let result = ExternalPolicy.parseHostList("Example.COM")
      #expect(result.contains("example.com"))
    }

    @Test("Trims whitespace")
    func trimmed() {
      let result = ExternalPolicy.parseHostList("  example.com  ,  test.org  ")
      #expect(result.contains("example.com"))
      #expect(result.contains("test.org"))
    }
  }
}
