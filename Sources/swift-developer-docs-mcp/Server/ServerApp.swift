import AppleDocsCore
import Foundation
import HTTPTypes
import Hummingbird

struct ServerApp {
  let mcpServer: AppleDocsMCPServer
  let hostname: String
  let port: Int
  let mcpBridge: MCPHTTPBridge

  init(
    mcpServer: AppleDocsMCPServer = AppleDocsMCPServer(),
    hostname: String = "127.0.0.1",
    port: Int = 8080
  ) {
    self.mcpServer = mcpServer
    self.hostname = hostname
    self.port = port
    self.mcpBridge = MCPHTTPBridge(
      mcpServer: mcpServer,
      hostname: hostname,
      port: port
    )
  }

  func run() async throws {
    let router = buildRouter()
    let app = Application(
      router: router,
      configuration: .init(
        address: .hostname(hostname, port: port)
      )
    )

    defer {
      Task {
        await mcpBridge.shutdown()
      }
    }

    printToStdErr("Server started at http://\(hostname):\(port)")
    try await app.runService()
  }

  func buildRouter() -> Router<BasicRequestContext> {
    let router = Router()

    router.middlewares.add(TrailingSlashMiddleware())
    router.middlewares.add(SecurityHeadersMiddleware())
    router.middlewares.add(CORSMiddleware())

    router.get("/") { request, _ -> Response in
      rootResponse(request: request)
    }

    router.get("/llms.txt") { _, _ -> Response in
      staticTextResponse(
        ServerApp.llmsTxt,
        contentType: "text/markdown; charset=utf-8"
      )
    }

    router.get("/search") { request, _ -> Response in
      let query = request.uri.queryParameters.get("q") ?? ""
      let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

      guard !trimmedQuery.isEmpty else {
        return errorResponse(
          status: .badRequest,
          message: "Missing search query. Provide ?q=..."
        )
      }

      do {
        let output = try await AppleDocsActions.search(query: trimmedQuery)

        if ServerApp.acceptsApplicationJSON(request) {
          return Response(
            status: .ok,
            headers: ServerApp.standardHeaders(
              contentType: "application/json; charset=utf-8",
              cacheControl: "public, max-age=300, s-maxage=600"
            ),
            body: .init(byteBuffer: .init(string: output.json))
          )
        }

        return Response(
          status: .ok,
          headers: ServerApp.standardHeaders(
            contentType: "text/plain; charset=utf-8",
            cacheControl: "public, max-age=300, s-maxage=600"
          ),
          body: .init(byteBuffer: .init(string: output.formatted))
        )
      } catch {
        return errorResponse(
          status: .internalServerError,
          message: "Search failed: \(error.localizedDescription)"
        )
      }
    }

    router.get("/documentation/{path+}") { request, context -> Response in
      let path = context.parameters.get("path") ?? ""

      guard !path.isEmpty else {
        return errorResponse(status: .badRequest, message: "Invalid documentation path")
      }

      do {
        let markdown = try await AppleDocsActions.fetch(path: path)
        let sourceURL = URLUtilities.generateAppleDocURL(
          URLUtilities.normalizeDocumentationPath(path)
        )

        return markdownResponse(
          markdown: markdown,
          sourceURL: sourceURL,
          request: request
        )
      } catch {
        return handleFetchError(error, path: "/documentation/\(path)")
      }
    }

    router.get("/design/human-interface-guidelines") { request, _ -> Response in
      do {
        let markdown = try await AppleDocsActions.fetchHIGTableOfContents()
        return markdownResponse(
          markdown: markdown,
          sourceURL: "https://developer.apple.com/design/human-interface-guidelines/",
          request: request
        )
      } catch {
        return handleFetchError(error, path: "/design/human-interface-guidelines")
      }
    }

    router.get("/design/human-interface-guidelines/{path+}") { request, context -> Response in
      let higPath = context.parameters.get("path") ?? ""

      guard !higPath.isEmpty else {
        return errorResponse(status: .badRequest, message: "Invalid HIG path")
      }

      do {
        let markdown = try await AppleDocsActions.fetchHIG(path: higPath)
        let sourceURL =
          "https://developer.apple.com/design/human-interface-guidelines/\(higPath)"

        return markdownResponse(
          markdown: markdown,
          sourceURL: sourceURL,
          request: request
        )
      } catch {
        return handleFetchError(
          error,
          path: "/design/human-interface-guidelines/\(higPath)"
        )
      }
    }

    router.get("/videos/play/{collection}/{id}") { request, context -> Response in
      let collection = context.parameters.get("collection") ?? ""
      let videoID = context.parameters.get("id") ?? ""

      guard !collection.isEmpty, !videoID.isEmpty else {
        return errorResponse(
          status: .badRequest,
          message: "Invalid video path. Supported format: /videos/play/COLLECTION/VIDEO_ID"
        )
      }

      do {
        let videoPath = "videos/play/\(collection)/\(videoID)"
        let markdown = try await AppleDocsActions.fetchVideo(path: videoPath)
        let sourceURL = "https://developer.apple.com/videos/play/\(collection)/\(videoID)/"

        return markdownResponse(
          markdown: markdown,
          sourceURL: sourceURL,
          request: request
        )
      } catch {
        return handleFetchError(
          error,
          path: "/videos/play/\(collection)/\(videoID)"
        )
      }
    }

    router.get("/external/{path+}") { request, _ -> Response in
      let targetURL: String
      do {
        targetURL = try ExternalPolicy.decodeExternalTargetPath(request.uri.path)
      } catch {
        return errorResponse(status: .badRequest, message: "Invalid external path")
      }

      do {
        let markdown = try await AppleDocsActions.fetchExternal(url: targetURL)
        return markdownResponse(
          markdown: markdown,
          sourceURL: targetURL,
          request: request
        )
      } catch {
        return handleExternalError(error, url: targetURL)
      }
    }

    router.get("/mcp") { request, _ -> Response in
      await mcpResponse(for: request)
    }
    router.head("/mcp") { request, _ -> Response in
      await mcpResponse(for: request)
    }
    router.post("/mcp") { request, _ -> Response in
      await mcpResponse(for: request)
    }
    router.delete("/mcp") { request, _ -> Response in
      await mcpResponse(for: request)
    }
    router.put("/mcp") { request, _ -> Response in
      await mcpResponse(for: request)
    }
    router.patch("/mcp") { request, _ -> Response in
      await mcpResponse(for: request)
    }

    router.get("/{path+}") { _, _ -> Response in
      errorResponse(
        status: .notFound,
        message: "The requested resource was not found on this server."
      )
    }

    return router
  }

  private func rootResponse(request: Request) -> Response {
    if ServerApp.acceptsMarkdown(request) {
      return staticTextResponse(
        ServerApp.llmsTxt,
        contentType: "text/markdown; charset=utf-8"
      )
    }

    return staticTextResponse(
      ServerApp.indexHTML,
      contentType: "text/html; charset=utf-8"
    )
  }

  private func staticTextResponse(
    _ body: String,
    contentType: String
  ) -> Response {
    Response(
      status: .ok,
      headers: ServerApp.standardHeaders(
        contentType: contentType,
        cacheControl: "public, max-age=300, s-maxage=600"
      ),
      body: .init(byteBuffer: .init(string: body))
    )
  }

  private func markdownResponse(
    markdown: String,
    sourceURL: String,
    request: Request
  ) -> Response {
    let etag = generateETag(markdown)

    if ServerApp.acceptsApplicationJSON(request) {
      let jsonBody: [String: String] = ["url": sourceURL, "content": markdown]
      if let jsonData = try? JSONEncoder().encode(jsonBody),
        let jsonString = String(data: jsonData, encoding: .utf8)
      {
        return Response(
          status: .ok,
          headers: ServerApp.documentHeaders(
            contentType: "application/json; charset=utf-8",
            sourceURL: sourceURL,
            etag: etag
          ),
          body: .init(byteBuffer: .init(string: jsonString))
        )
      }
    }

    return Response(
      status: .ok,
      headers: ServerApp.documentHeaders(
        contentType: "text/markdown; charset=utf-8",
        sourceURL: sourceURL,
        etag: etag
      ),
      body: .init(byteBuffer: .init(string: markdown))
    )
  }

  private func mcpResponse(for request: Request) async -> Response {
    do {
      let bridgeResponse = try await bridgeMCPRequest(request)
      return ServerApp.response(from: bridgeResponse)
    } catch {
      return errorResponse(
        status: .badRequest,
        message: "Invalid MCP request body: \(error.localizedDescription)"
      )
    }
  }

  private func bridgeMCPRequest(_ request: Request) async throws -> MCPBridgeResponse {
    var mutableRequest = request
    let bodyData: Data?

    switch mutableRequest.method {
    case .post, .put, .patch, .delete:
      let body = try await mutableRequest.collectBody(upTo: 1_048_576)
      bodyData = body.readableBytes > 0 ? Data(body.readableBytesView) : nil
    default:
      bodyData = nil
    }

    return await mcpBridge.handle(
      method: mutableRequest.method.rawValue,
      headers: ServerApp.dictionaryHeaders(from: mutableRequest.headers),
      body: bodyData
    )
  }

  private func handleFetchError(_ error: Error, path: String) -> Response {
    if let docsError = error as? AppleDocsError {
      switch docsError {
      case .notFound:
        return errorResponse(
          status: .notFound,
          message: "The requested documentation page does not exist: \(path)"
        )
      case .insufficientContent:
        return errorResponse(
          status: .badGateway,
          message: "The documentation page loaded but contained insufficient content."
        )
      case .invalidPath, .invalidURL:
        return errorResponse(
          status: .badRequest,
          message: docsError.localizedDescription
        )
      default:
        break
      }
    }

    return errorResponse(
      status: .internalServerError,
      message: "Error fetching content: \(error.localizedDescription)"
    )
  }

  private func handleExternalError(_ error: Error, url: String) -> Response {
    if let docsError = error as? AppleDocsError {
      switch docsError {
      case .accessDenied, .ssrfBlocked:
        return errorResponse(
          status: .forbidden,
          message:
            "External documentation access denied for \(url): \(docsError.localizedDescription)"
        )
      case .robotsBlocked:
        return errorResponse(
          status: .forbidden,
          message: "Blocked by robots.txt for \(url)"
        )
      case .notFound:
        return errorResponse(
          status: .notFound,
          message: "External documentation not found: \(url)"
        )
      default:
        break
      }
    }

    return handleFetchError(error, path: "/external/\(url)")
  }

  private func generateETag(_ content: String) -> String {
    let data = Data(content.utf8)
    let base64 = data.base64EncodedString().prefix(16)
    return "\"\(base64)\""
  }

  private static func acceptsApplicationJSON(_ request: Request) -> Bool {
    let accept = request.headers[.accept] ?? ""
    return accept.contains("application/json")
  }

  private static func acceptsMarkdown(_ request: Request) -> Bool {
    let accept = request.headers[.accept] ?? ""
    return accept.contains("text/markdown")
  }

  private static func standardHeaders(
    contentType: String,
    cacheControl: String
  ) -> HTTPFields {
    [
      .contentType: contentType,
      .cacheControl: cacheControl,
      .init("Vary")!: "Accept",
    ]
  }

  private static func documentHeaders(
    contentType: String,
    sourceURL: String,
    etag: String
  ) -> HTTPFields {
    [
      .contentType: contentType,
      .cacheControl: "public, max-age=3600, s-maxage=86400",
      .init("Content-Location")!: sourceURL,
      .init("ETag")!: etag,
      .init("Vary")!: "Accept",
    ]
  }

  private static func dictionaryHeaders(from headers: HTTPFields) -> [String: String] {
    var result: [String: String] = [:]

    for header in headers {
      if let existing = result[header.name.rawName] {
        result[header.name.rawName] = existing + ", " + header.value
      } else {
        result[header.name.rawName] = header.value
      }
    }

    return result
  }

  private static func response(from bridgeResponse: MCPBridgeResponse) -> Response {
    let status = HTTPResponse.Status(code: bridgeResponse.statusCode)
    let headers = httpFields(from: bridgeResponse.headers)

    if let stream = bridgeResponse.stream {
      return Response(
        status: status,
        headers: headers,
        body: .init(asyncSequence: byteBufferStream(from: stream))
      )
    }

    let bodyBuffer: ByteBuffer
    if let body = bridgeResponse.body {
      var buffer = ByteBufferAllocator().buffer(capacity: body.count)
      buffer.writeBytes(body)
      bodyBuffer = buffer
    } else {
      bodyBuffer = .init()
    }

    return Response(
      status: status,
      headers: headers,
      body: .init(byteBuffer: bodyBuffer)
    )
  }

  private static func httpFields(from headers: [String: String]) -> HTTPFields {
    var fields: HTTPFields = [:]

    for (name, value) in headers {
      guard let headerName = HTTPField.Name(name) else { continue }
      fields[headerName] = value
    }

    return fields
  }

  private static func byteBufferStream(
    from stream: AsyncThrowingStream<Data, Error>
  ) -> AsyncThrowingStream<ByteBuffer, Error> {
    AsyncThrowingStream { continuation in
      let task = Task {
        do {
          for try await chunk in stream {
            var buffer = ByteBufferAllocator().buffer(capacity: chunk.count)
            buffer.writeBytes(chunk)
            continuation.yield(buffer)
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }

      continuation.onTermination = { _ in
        task.cancel()
      }
    }
  }

  static let llmsTxt = """
    # swift-developer-docs-mcp

    Apple Developer documentation, Human Interface Guidelines,
    WWDC video transcripts, and external Swift-DocC sites
    rendered as AI-friendly Markdown.

    ## HTTP Usage

    ### Documentation
    GET /documentation/{path}

    ### Human Interface Guidelines
    GET /design/human-interface-guidelines
    GET /design/human-interface-guidelines/{path}

    ### Video Transcripts
    GET /videos/play/{collection}/{id}

    ### External DocC
    GET /external/{full-https-url}

    ### Search
    GET /search?q={query}

    ### MCP
    GET /mcp
    POST /mcp
    DELETE /mcp

    ## Content Negotiation

    `GET /` returns HTML by default.
    Send `Accept: text/markdown` to receive this `llms.txt` document instead.

    Documentation endpoints return text/markdown by default.
    Set `Accept: application/json` for JSON output.

    ## Available MCP Tools

    - `searchAppleDocumentation` - Search Apple Developer documentation
    - `fetchAppleDocumentation` - Fetch documentation, HIG, or video transcripts by path
    - `fetchExternalDocumentation` - Fetch external Swift-DocC documentation by URL
    - `fetchAppleVideoTranscript` - Fetch Apple Developer video transcripts

    ---
    *Generated by [swift-developer-docs-mcp](https://github.com/mehmetbaykar/swift-developer-docs-mcp)*
    """

  static let indexHTML = """
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>swift-developer-docs-mcp</title>
        <style>
          :root {
            color-scheme: light;
            --bg: #f5f1e8;
            --panel: rgba(255, 255, 255, 0.8);
            --ink: #1c1b19;
            --muted: #5f5a52;
            --line: rgba(28, 27, 25, 0.12);
            --accent: #0b6c66;
          }
          body {
            margin: 0;
            font-family: "Iowan Old Style", "Palatino Linotype", serif;
            color: var(--ink);
            background:
              radial-gradient(circle at top left, rgba(11, 108, 102, 0.18), transparent 32rem),
              linear-gradient(180deg, #f8f4eb 0%, var(--bg) 100%);
          }
          main {
            max-width: 48rem;
            margin: 0 auto;
            padding: 4rem 1.5rem 5rem;
          }
          .panel {
            background: var(--panel);
            border: 1px solid var(--line);
            border-radius: 1.25rem;
            box-shadow: 0 1.25rem 3rem rgba(28, 27, 25, 0.08);
            padding: 2rem;
            backdrop-filter: blur(12px);
          }
          h1 {
            font-size: clamp(2.5rem, 5vw, 4rem);
            line-height: 0.95;
            margin: 0 0 1rem;
          }
          p {
            font-size: 1.05rem;
            line-height: 1.65;
            color: var(--muted);
          }
          ul {
            padding-left: 1.2rem;
            line-height: 1.8;
            color: var(--muted);
          }
          code {
            font-family: "SF Mono", "Menlo", monospace;
            background: rgba(28, 27, 25, 0.06);
            border-radius: 0.4rem;
            padding: 0.1rem 0.35rem;
          }
          a {
            color: var(--accent);
          }
        </style>
      </head>
      <body>
        <main>
          <section class="panel">
            <h1>swift-developer-docs-mcp</h1>
            <p>
              Apple Developer documentation, Human Interface Guidelines, WWDC video transcripts,
              and external Swift-DocC sites rendered as AI-friendly Markdown.
            </p>
            <ul>
              <li>Read the service description at <a href="/llms.txt"><code>/llms.txt</code></a>.</li>
              <li>Use <code>/documentation/*</code>, <code>/search</code>, <code>/design/*</code>, <code>/videos/*</code>, and <code>/external/*</code> for HTTP access.</li>
              <li>Connect MCP clients over HTTP at <code>/mcp</code>.</li>
            </ul>
          </section>
        </main>
      </body>
    </html>
    """
}

private func errorResponse(status: HTTPResponse.Status, message: String) -> Response {
  let title: String =
    switch status.code {
    case 400: "Bad Request"
    case 403: "Forbidden"
    case 404: "Not Found"
    case 405: "Method Not Allowed"
    case 406: "Not Acceptable"
    case 415: "Unsupported Media Type"
    case 421: "Misdirected Request"
    case 502: "Bad Gateway"
    default: "Error"
    }

  let markdown = """
    # \(title)

    \(message)

    ---
    *[swift-developer-docs-mcp](https://github.com/mehmetbaykar/swift-developer-docs-mcp)*
    """

  return Response(
    status: status,
    headers: [.contentType: "text/markdown; charset=utf-8"],
    body: .init(byteBuffer: .init(string: markdown))
  )
}
