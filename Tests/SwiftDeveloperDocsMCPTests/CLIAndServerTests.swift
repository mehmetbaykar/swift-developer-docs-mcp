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
