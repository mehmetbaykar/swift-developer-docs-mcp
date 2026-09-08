import Crypto
import Foundation
import HTTPTypes
import Hummingbird
import HummingbirdTesting
import Testing

@testable import swift_developer_docs_mcp

@Suite("CLI And Server")
struct CLIAndServerTests {

  @Suite("CLI Argument Parsing")
  struct CLIArgumentParsing {
    @Test("Preserves positional arguments and reports unknown options")
    func reportsUnknownOptions() {
      let parsed = CLIArgParser.parse(["swift/array", "--json", "--bogus"])

      #expect(parsed.positional == ["swift/array"])
      #expect(parsed.json)
      #expect(parsed.unknownOptions == ["--bogus"])
    }
  }

  @Suite("HTTP Routes")
  struct HTTPRoutes {
    @Test("Registers recursive wildcard routes for docs, external, and catch-all paths")
    func recursiveWildcardRoutes() {
      let routes = ServerApp().buildRouter().routes.map(\.path.description)

      #expect(routes.contains("/documentation/**"))
      #expect(routes.contains("/design/human-interface-guidelines/**"))
      #expect(routes.contains("/external/**"))
      #expect(routes.contains("/robots.txt"))
      #expect(routes.contains("/sitemap.xml"))
      #expect(routes.contains("/**"))
    }

    @Test("Redirects /bot to /#bot")
    func botRedirect() async throws {
      let response = try await testResponse(uri: "/bot")

      #expect(response.status == .found)
      #expect(response.headers[.location] == "/#bot")
    }

    @Test("Serves robots.txt with proxied content disallowed")
    func robotsTxt() async throws {
      let response = try await testResponse(uri: "/robots.txt")
      let body = response.body.getString(at: 0, length: response.body.readableBytes) ?? ""

      #expect(response.status == .ok)
      #expect(response.headers[.contentType]?.contains("text/plain") == true)
      #expect(body.contains("Allow: /llms.txt"))
      #expect(body.contains("Disallow: /documentation/"))
      #expect(body.contains("Disallow: /external/"))
      #expect(body.contains("Sitemap: /sitemap.xml"))
    }

    @Test("Serves sitemap with public entry points")
    func sitemapXML() async throws {
      let response = try await testResponse(
        uri: "/sitemap.xml",
        headers: [
          .init("X-Forwarded-Proto")!: "https",
          .init("X-Forwarded-Host")!: "docs.example.com",
        ]
      )
      let body = response.body.getString(at: 0, length: response.body.readableBytes) ?? ""

      #expect(response.status == .ok)
      #expect(response.headers[.contentType]?.contains("application/xml") == true)
      #expect(body.contains("<loc>https://docs.example.com/</loc>"))
      #expect(body.contains("<loc>https://docs.example.com/llms.txt</loc>"))
      #expect(!body.contains("/documentation/"))
    }

    @Test("Serves improved llms.txt guide")
    func llmsTxtGuide() async throws {
      let response = try await testResponse(uri: "/llms.txt")
      let body = response.body.getString(at: 0, length: response.body.readableBytes) ?? ""

      #expect(response.status == .ok)
      #expect(response.headers[.contentType]?.contains("text/markdown") == true)
      #expect(body.contains("## Best Entry Points"))
      #expect(body.contains("## Crawl Policy"))
      #expect(body.contains("The MCP server itself runs over stdio"))
    }

    @Test("Advertises discovery documents from the homepage Link header")
    func homepageLinkHeader() async throws {
      let response = try await testResponse(uri: "/")
      let link = response.headers[.init("Link")!] ?? ""

      #expect(response.status == .ok)
      #expect(link.contains("</.well-known/api-catalog>; rel=\"api-catalog\""))
      #expect(link.contains("</.well-known/agent-card.json>; rel=\"service-desc\""))
      #expect(link.contains("</SKILL.md>; rel=\"service-doc\""))
      #expect(link.contains("</llms.txt>; rel=\"alternate\""))
    }

    @Test("Serves the agent skill with frontmatter and origin-specific examples")
    func skillMarkdown() async throws {
      let response = try await testResponse(
        uri: "/SKILL.md",
        headers: [
          .init("X-Forwarded-Proto")!: "https",
          .init("X-Forwarded-Host")!: "docs.example.com",
        ]
      )
      let body = response.body.getString(at: 0, length: response.body.readableBytes) ?? ""

      #expect(response.status == .ok)
      #expect(response.headers[.contentType]?.contains("text/markdown") == true)
      #expect(response.headers[.accessControlAllowOrigin] == "*")
      #expect(body.hasPrefix("---\nname: apple-docs\ndescription: "))
      #expect(body.contains("https://docs.example.com/documentation/swift/array"))

      let mirrored = try await testResponse(uri: "/.well-known/agent-skills/apple-docs/SKILL.md")
      #expect(mirrored.status == .ok)
      #expect(mirrored.headers[.contentType]?.contains("text/markdown") == true)

      let head = try await testResponse(
        uri: "/.well-known/agent-skills/apple-docs/SKILL.md", method: .head)
      #expect(head.status == .ok)
      #expect(head.body.readableBytes == 0)
    }

    @Test("Serves an agent-skills index whose digest matches the served skill")
    func skillIndex() async throws {
      let headers: HTTPFields = [.init("X-Forwarded-Host")!: "docs.example.com"]
      let index = try await testResponse(uri: "/.well-known/agent-skills/index.json", headers: headers)
      let indexBody = index.body.getString(at: 0, length: index.body.readableBytes) ?? ""
      let json = try #require(
        JSONSerialization.jsonObject(with: Data(indexBody.utf8)) as? [String: Any])
      let skills = try #require(json["skills"] as? [[String: Any]])
      let skill = try #require(skills.first)

      #expect(index.status == .ok)
      #expect(index.headers[.contentType]?.contains("application/json") == true)
      #expect(json["$schema"] as? String == "https://schemas.agentskills.io/discovery/0.2.0/schema.json")
      #expect(skill["name"] as? String == "apple-docs")
      #expect(skill["type"] as? String == "skill-md")
      #expect(skill["url"] as? String == "/.well-known/agent-skills/apple-docs/SKILL.md")
      #expect(skill["files"] as? [String] == ["SKILL.md"])

      let served = try await testResponse(uri: "/SKILL.md", headers: headers)
      let servedBody = served.body.getString(at: 0, length: served.body.readableBytes) ?? ""
      let expectedDigest = SHA256.hash(data: Data(servedBody.utf8))
        .map { String(format: "%02x", $0) }.joined()
      #expect(skill["digest"] as? String == "sha256:\(expectedDigest)")
    }

    @Test("Serves an A2A agent card describing the HTTP interface")
    func agentCard() async throws {
      let response = try await testResponse(
        uri: "/.well-known/agent-card.json",
        headers: [
          .init("X-Forwarded-Proto")!: "http",
          .init("X-Forwarded-Host")!: "docs.example.com",
        ]
      )
      let body = response.body.getString(at: 0, length: response.body.readableBytes) ?? ""
      let card = try #require(JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any])
      let interfaces = try #require(card["supportedInterfaces"] as? [[String: Any]])
      let skills = try #require(card["skills"] as? [[String: Any]])

      #expect(response.status == .ok)
      #expect(response.headers[.contentType]?.contains("application/json") == true)
      #expect(card["name"] as? String == "swift-developer-docs-mcp")
      #expect(card["documentationUrl"] as? String == "http://docs.example.com/SKILL.md")
      #expect(interfaces.first?["url"] as? String == "http://docs.example.com")
      #expect(interfaces.first?["protocolVersion"] as? String == "0.3")
      #expect(interfaces.first?["protocolBinding"] as? String == "HTTP+JSON")
      #expect(skills.map { $0["id"] as? String } == [
        "search-apple-documentation",
        "fetch-apple-documentation",
        "fetch-external-documentation",
        "fetch-apple-video-transcript",
      ])
    }

    @Test("Serves an RFC 9727 API catalog")
    func apiCatalog() async throws {
      let response = try await testResponse(
        uri: "/.well-known/api-catalog",
        headers: [
          .init("X-Forwarded-Proto")!: "https",
          .init("X-Forwarded-Host")!: "docs.example.com",
        ]
      )
      let body = response.body.getString(at: 0, length: response.body.readableBytes) ?? ""
      let catalog = try #require(
        JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any])
      let linkset = try #require(catalog["linkset"] as? [[String: Any]])

      #expect(response.status == .ok)
      #expect(response.headers[.contentType]?.contains("application/linkset+json") == true)
      #expect(linkset.first?["anchor"] as? String == "https://docs.example.com/documentation")
      #expect(body.contains("https://docs.example.com/SKILL.md"))
    }

    @Test("Derives the origin from the request authority without forwarding headers")
    func originFallsBackToRequestAuthority() async throws {
      let response = try await testResponse(uri: "/.well-known/api-catalog")
      let body = response.body.getString(at: 0, length: response.body.readableBytes) ?? ""

      #expect(body.contains("\"anchor\" : \"http://localhost/documentation\""))
    }

    @Test("Returns JSON errors when the client asks for JSON")
    func jsonNotFoundResponse() async throws {
      let response = try await testResponse(
        uri: "/missing",
        headers: [.accept: "application/json"]
      )

      #expect(response.status == .notFound)
      #expect(response.headers[.contentType]?.contains("application/json") == true)

      let body = response.body.getString(at: 0, length: response.body.readableBytes) ?? ""
      #expect(body.contains("\"error\":\"Not Found\""))
      #expect(body.contains("\"message\":\"The requested resource was not found on this server.\""))
    }

    private func testResponse(
      uri: String,
      method: HTTPRequest.Method = .get,
      headers: HTTPFields = [:]
    ) async throws -> TestResponse {
      let app = Application(
        router: ServerApp().buildRouter(),
        configuration: .init(address: .hostname("127.0.0.1", port: 0))
      )

      return try await app.test(.router) { client in
        try await client.execute(uri: uri, method: method, headers: headers)
      }
    }
  }
}
