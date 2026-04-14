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
      #expect(routes.contains("/**"))
    }

    @Test("Redirects /bot to /#bot")
    func botRedirect() async throws {
      let response = try await testResponse(uri: "/bot")

      #expect(response.status == .found)
      #expect(response.headers[.location] == "/#bot")
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

    @Test("Registers OPTIONS on /mcp")
    func optionsOnMCPIsHandled() async throws {
      let response = try await testResponse(uri: "/mcp", method: .options)
      #expect(response.status.code != 404)
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
