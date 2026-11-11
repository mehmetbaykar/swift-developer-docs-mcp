import AppleDocsCore
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
      #expect(body.contains("`Content-Location` gives the real page"))
      #expect(body.contains("gives a 404 answer that lists the"))
      #expect(body.contains("candidate paths."))
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

  @Suite("Missing Documentation Pages")
  struct MissingDocumentationPages {
    private let candidates = [
      DocumentationCandidate(
        path: "swiftui/view/body-swift.property",
        title: "body"
      ),
      DocumentationCandidate(
        path: "swiftui/view/body-5abc",
        title: "Body"
      ),
    ]

    @Test("Renders Markdown candidates")
    func markdownCandidates() {
      #expect(
        renderDocumentationCandidatesMarkdown(candidates)
          == "\n## Did you mean:\n\n"
          + "- [body](/documentation/swiftui/view/body-swift.property)\n"
          + "- [Body](/documentation/swiftui/view/body-5abc)\n"
      )
    }

    @Test("Renders no Markdown candidate section when there are none")
    func markdownWithoutCandidates() {
      #expect(renderDocumentationCandidatesMarkdown([]) == "")

      let markdown = renderHTTPErrorMarkdown(
        title: "Not Found",
        message: "The requested documentation page does not exist: /documentation/missing",
        candidates: []
      )
      #expect(!markdown.contains("Did you mean"))
      #expect(markdown.contains("# Not Found"))
      #expect(
        markdown.contains(
          "The requested documentation page does not exist: /documentation/missing"))
    }

    @Test("Renders JSON candidates")
    func jsonCandidates() throws {
      let json = renderHTTPErrorJSON(
        title: "Not Found",
        message:
          "The requested documentation page does not exist: /documentation/swiftui/view/body",
        candidates: candidates
      )
      #expect(json.contains("\"candidates\""))
      #expect(json.contains("\"title\""))
      #expect(json.contains("\"path\""))
      let body = try JSONDecoder().decode(ErrorBody.self, from: Data(json.utf8))
      #expect(body.error == "Not Found")
      #expect(
        body.candidates == [
          CandidateLink(title: "body", path: "/documentation/swiftui/view/body-swift.property"),
          CandidateLink(title: "Body", path: "/documentation/swiftui/view/body-5abc"),
        ]
      )
    }

    @Test("Omits the JSON candidates field when there are none")
    func jsonWithoutCandidates() throws {
      let json = renderHTTPErrorJSON(
        title: "Not Found",
        message: "The requested documentation page does not exist: /documentation/missing",
        candidates: []
      )
      #expect(!json.contains("\"candidates\""))
      let body = try JSONDecoder().decode(ErrorBody.self, from: Data(json.utf8))
      #expect(body.candidates == nil)
    }

    @Test("Maps documentationNotFound to 404")
    func documentationNotFoundIs404() {
      let missing = AppleDocsError.documentationNotFound(
        url: "https://developer.apple.com/documentation/missing",
        candidates: []
      )
      #expect(fetchFailure(for: missing, path: "/documentation/missing").status == .notFound)

      let ambiguous = AppleDocsError.documentationNotFound(
        url: "https://developer.apple.com/documentation/swiftui/view/body.json",
        candidates: candidates
      )
      #expect(
        fetchFailure(for: ambiguous, path: "/documentation/swiftui/view/body").status == .notFound)
    }

    private struct CandidateLink: Decodable, Equatable {
      let title: String
      let path: String
    }

    private struct ErrorBody: Decodable {
      let error: String
      let message: String
      let candidates: [CandidateLink]?
    }
  }
}
