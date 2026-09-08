import Crypto
import Foundation
import HTTPTypes
import Hummingbird

/// Agent-facing discovery documents served from `/.well-known/*` and `/SKILL.md`,
/// mirroring the discovery surface published by sosumi.ai.
enum AgentDiscovery {
  static let skillName = "apple-docs"
  static let providerOrganization = "mehmetbaykar"
  static let repositoryURL = "https://github.com/mehmetbaykar/swift-developer-docs-mcp"

  /// The A2A protocol version the agent card advertises, as `major.minor`.
  /// See https://a2a-protocol.org/latest/specification/
  static let a2aProtocolVersion = "0.3"

  /// The documentation service is exposed over plain HTTP requests, so `HTTP+JSON`
  /// is the closest of A2A's officially supported bindings.
  static let a2aTransport = "HTTP+JSON"

  static let agentDescription =
    "Making Apple docs AI-readable. "
    + "Converts Apple Developer documentation, Human Interface Guidelines, "
    + "WWDC session transcripts, and public Swift-DocC sites into clean Markdown for AI agents."

  struct SkillDefinition: Sendable {
    let toolName: String
    let title: String
    let description: String
    let tags: [String]
    let examples: [String]

    /// The camelCase tool name as a kebab-case skill id.
    var id: String {
      toolName.replacingOccurrences(
        of: "([a-z0-9])([A-Z])", with: "$1-$2", options: .regularExpression
      ).lowercased()
    }
  }

  static let skills: [SkillDefinition] = [
    SkillDefinition(
      toolName: "searchAppleDocumentation",
      title: "Search Apple Documentation",
      description: "Search Apple Developer documentation and return structured results",
      tags: ["apple", "search", "documentation"],
      examples: ["Search Apple documentation for URLSession"]),
    SkillDefinition(
      toolName: "fetchAppleDocumentation",
      title: "Fetch Apple Documentation",
      description:
        "Fetch Apple Developer documentation and Human Interface Guidelines by path and return as markdown",
      tags: ["apple", "documentation", "markdown", "hig"],
      examples: ["Fetch /documentation/swiftui/view as Markdown"]),
    SkillDefinition(
      toolName: "fetchExternalDocumentation",
      title: "Fetch External Documentation",
      description:
        "Fetch external Swift-DocC documentation by absolute https URL and return as markdown",
      tags: ["swift-docc", "documentation", "markdown"],
      examples: [
        "Fetch https://swiftlang.github.io/swift-markdown/documentation/markdown"
      ]),
    SkillDefinition(
      toolName: "fetchAppleVideoTranscript",
      title: "Fetch Apple Video Transcript",
      description: "Fetch transcript for an Apple Developer video path and return as markdown",
      tags: ["apple", "wwdc", "video", "transcript"],
      examples: ["Fetch the transcript for /videos/play/wwdc2021/10133"]),
  ]

  /// Discovery links advertised on the homepage.
  static let linkHeader = [
    "</.well-known/api-catalog>; rel=\"api-catalog\"",
    "</.well-known/agent-card.json>; rel=\"service-desc\"; type=\"application/json\"",
    "</SKILL.md>; rel=\"service-doc\"",
    "</llms.txt>; rel=\"alternate\"; type=\"text/markdown\"",
  ].joined(separator: ", ")

  // MARK: - Origin

  /// The public origin clients should use to reach this server, honoring reverse-proxy
  /// forwarding headers before falling back to the request `Host` and the bind address.
  static func origin(for request: Request, fallbackHost: String) -> String {
    let scheme = request.headers[.init("X-Forwarded-Proto")!]?.split(separator: ",").first.map {
      $0.trimmingCharacters(in: .whitespaces)
    }
    let host = request.headers[.init("X-Forwarded-Host")!]?.split(separator: ",").first.map {
      $0.trimmingCharacters(in: .whitespaces)
    }
    return "\(scheme ?? "http")://\(host ?? request.head.authority ?? fallbackHost)"
  }

  // MARK: - Documents

  static func agentCard(origin: String, serverName: String, version: String) -> String {
    let card: [String: Any] = [
      "name": serverName,
      "description": agentDescription,
      "version": version,
      "supportedInterfaces": [
        [
          "url": origin,
          "protocolVersion": a2aProtocolVersion,
          // Named `protocolBinding` by the current A2A proto schema; `transport` is kept
          // for clients reading the published JSON schema.
          "protocolBinding": a2aTransport,
          "transport": a2aTransport,
        ]
      ],
      "provider": [
        "organization": providerOrganization,
        "url": repositoryURL,
      ],
      "documentationUrl": "\(origin)/SKILL.md",
      "capabilities": [
        "streaming": false,
        "pushNotifications": false,
      ],
      "defaultInputModes": ["text/plain"],
      "defaultOutputModes": ["text/markdown", "text/plain"],
      "skills": skills.map { skill in
        [
          "id": skill.id,
          "name": skill.title,
          "description": skill.description,
          "tags": skill.tags,
          "examples": skill.examples,
        ] as [String: Any]
      },
    ]
    return encodeJSON(card)
  }

  /// RFC 9727 API catalog. Only the HTTP documentation surface is listed, because the
  /// MCP server runs over stdio rather than at an HTTP endpoint.
  static func apiCatalog(origin: String) -> String {
    let catalog: [String: Any] = [
      "linkset": [
        [
          "anchor": "\(origin)/documentation",
          "service-desc": [
            ["href": "\(origin)/.well-known/agent-card.json", "type": "application/json"]
          ],
          "service-doc": [["href": "\(origin)/SKILL.md", "type": "text/markdown"]],
          "status": [["href": "\(origin)/"]],
        ]
      ]
    ]
    return encodeJSON(catalog)
  }

  /// agentskills.io discovery index for the served skill.
  static func skillIndex(origin: String) -> String {
    let markdown = skillMarkdown(origin: origin)
    let digest = SHA256.hash(data: Data(markdown.utf8))
      .map { String(format: "%02x", $0) }
      .joined()

    let index: [String: Any] = [
      "$schema": "https://schemas.agentskills.io/discovery/0.2.0/schema.json",
      "skills": [
        [
          "name": skillName,
          "type": "skill-md",
          "description": skillDescription,
          "url": "/.well-known/agent-skills/\(skillName)/SKILL.md",
          "digest": "sha256:\(digest)",
          "files": ["SKILL.md"],
        ] as [String: Any]
      ],
    ]
    return encodeJSON(index)
  }

  static let skillDescription =
    "Fetches Apple documentation as Markdown from a swift-developer-docs-mcp server. "
    + "Use for Apple API reference, Human Interface Guidelines, WWDC transcripts, "
    + "and external Swift-DocC pages."

  static func skillMarkdown(origin: String) -> String {
    """
    ---
    name: \(skillName)
    description: \(skillDescription)
    ---

    # \(skillName) Skill

    Use this skill to reliably fetch Apple docs as Markdown when coding agents need precise API details.

    ## When to Use

    Use this service when the request involves any of the following:

    - Apple platform APIs (`Swift`, `SwiftUI`, `UIKit`, `AppKit`, `Foundation`, etc.)
    - API signatures, availability, parameter behavior, or return semantics
    - Human Interface Guidelines questions
    - WWDC session transcript lookup
    - External Swift-DocC documentation (for example, GitHub Pages or Swift Package Index hosts)

    ## Core Workflow

    1. If you already have a `developer.apple.com` URL, replace the origin with `\(origin)` and keep the same path.
    2. If you do not know the exact page path, search first, then fetch the best match.
    3. Prefer specific symbol pages instead of broad top-level pages when answering implementation questions.

    ## HTTP Usage

    Replace `https://developer.apple.com` with `\(origin)`:

    - Original: `https://developer.apple.com/documentation/swift/array`
    - AI-readable: `\(origin)/documentation/swift/array`

    Responses are `text/markdown` by default. Send `Accept: application/json` for
    `{"url": ..., "content": ...}` payloads.

    ## Content Types

    ### Search

    - Pattern: `\(origin)/search?q={query}`
    - Example: `\(origin)/search?q=SwiftUI%20NavigationStack`

    ### Apple API Reference

    - Pattern: `\(origin)/documentation/{framework}/{symbol}`
    - Examples:
      - `\(origin)/documentation/swift/array`
      - `\(origin)/documentation/swiftui/view`

    ### Human Interface Guidelines

    - Pattern: `\(origin)/design/human-interface-guidelines/{topic}`
    - Examples:
      - `\(origin)/design/human-interface-guidelines`
      - `\(origin)/design/human-interface-guidelines/foundations/color`

    ### Apple Video Transcripts

    - Pattern: `\(origin)/videos/play/{collection}/{id}`
    - Examples:
      - `\(origin)/videos/play/wwdc2021/10133`
      - `\(origin)/videos/play/meet-with-apple/208`

    ### External Swift-DocC

    - Pattern: `\(origin)/external/{full-https-url}`
    - Example: `\(origin)/external/https://swiftlang.github.io/swift-markdown/documentation/markdown`

    ## MCP Tools Quick Reference

    Use these when `swift-developer-docs-mcp` is configured as an MCP server over stdio:

    | Tool | Parameters | Use |
    |---|---|---|
    | `searchAppleDocumentation` | `query: string` | Search Apple documentation and return structured results |
    | `fetchAppleDocumentation` | `path: string` | Fetch Apple docs, HIG content, video transcripts, or external docs via auto-routing |
    | `fetchAppleVideoTranscript` | `path: string` | Fetch Apple video transcript by `/videos/play/...` path |
    | `fetchExternalDocumentation` | `url: string` | Fetch external Swift-DocC page by absolute HTTPS URL |

    ## Best Practices

    - Search first if the exact path is unknown.
    - Fetch targeted symbol pages for coding questions.
    - Keep source links in answers so users can verify details quickly.

    ## Troubleshooting

    ### 404 or sparse output

    - The path may be incorrect or too broad.
    - Run a search query first, then fetch a specific result path.

    ### External page cannot be fetched

    - The host may block access via `robots.txt` or `X-Robots-Tag` directives.
    - Try another canonical page URL for the same symbol.

    """
  }

  private static func encodeJSON(_ object: [String: Any]) -> String {
    guard
      let data = try? JSONSerialization.data(
        withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
      let json = String(data: data, encoding: .utf8)
    else {
      return "{}"
    }
    return json
  }
}
