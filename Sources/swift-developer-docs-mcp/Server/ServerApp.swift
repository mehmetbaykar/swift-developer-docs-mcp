import AppleDocsCore
import Foundation
import Hummingbird

struct ServerApp {
  let hostname: String
  let port: Int

  init(hostname: String = "127.0.0.1", port: Int = 8080) {
    self.hostname = hostname
    self.port = port
  }

  func run() async throws {
    let router = buildRouter()

    let app = Application(
      router: router,
      configuration: .init(
        address: .hostname(hostname, port: port)
      )
    )

    printToStdErr("Server started at http://\(hostname):\(port)")
    try await app.runService()
  }

  func buildRouter() -> Router<BasicRequestContext> {
    let router = Router()

    // Add middleware
    router.middlewares.add(SecurityHeadersMiddleware())
    router.middlewares.add(CORSMiddleware())

    // Root route
    router.get("/") { _, _ -> Response in
      let llmsContent = ServerApp.llmsTxt
      return Response(
        status: .ok,
        headers: [
          .contentType: "text/markdown; charset=utf-8",
          .cacheControl: "public, max-age=300, s-maxage=600",
        ],
        body: .init(byteBuffer: .init(string: llmsContent))
      )
    }

    // llms.txt route
    router.get("/llms.txt") { _, _ -> Response in
      let llmsContent = ServerApp.llmsTxt
      return Response(
        status: .ok,
        headers: [
          .contentType: "text/markdown; charset=utf-8",
          .cacheControl: "public, max-age=300, s-maxage=600",
        ],
        body: .init(byteBuffer: .init(string: llmsContent))
      )
    }

    // Search route
    router.get("/search") { request, _ -> Response in
      let query = request.uri.queryParameters.get("q") ?? ""
      let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

      guard !trimmedQuery.isEmpty else {
        return errorResponse(
          status: .badRequest, message: "Missing search query. Provide ?q=...")
      }

      do {
        let output = try await AppleDocsActions.search(query: trimmedQuery)
        let acceptsJSON = ServerApp.acceptsApplicationJSON(request)

        if acceptsJSON {
          return Response(
            status: .ok,
            headers: [
              .contentType: "application/json; charset=utf-8",
              .cacheControl: "public, max-age=300, s-maxage=600",
            ],
            body: .init(byteBuffer: .init(string: output.json))
          )
        }

        return Response(
          status: .ok,
          headers: [
            .contentType: "text/plain; charset=utf-8",
            .cacheControl: "public, max-age=300, s-maxage=600",
          ],
          body: .init(byteBuffer: .init(string: output.formatted))
        )
      } catch {
        return errorResponse(
          status: .internalServerError,
          message: "Search failed: \(error.localizedDescription)")
      }
    }

    // Documentation routes
    router.get("/documentation/{path+}") { request, context -> Response in
      let path = context.parameters.get("path") ?? ""

      guard !path.isEmpty else {
        return errorResponse(status: .badRequest, message: "Invalid documentation path")
      }

      do {
        let markdown = try await AppleDocsActions.fetch(path: path)
        let sourceURL = URLUtilities.generateAppleDocURL(
          URLUtilities.normalizeDocumentationPath(path))

        return markdownResponse(
          markdown: markdown,
          sourceURL: sourceURL,
          request: request
        )
      } catch {
        return handleFetchError(error, path: "/documentation/\(path)")
      }
    }

    // HIG table of contents
    router.get("/design/human-interface-guidelines") { request, _ -> Response in
      do {
        let markdown = try await AppleDocsActions.fetchHIGTableOfContents()
        let sourceUrl =
          "https://developer.apple.com/design/human-interface-guidelines/"

        return markdownResponse(
          markdown: markdown,
          sourceURL: sourceUrl,
          request: request
        )
      } catch {
        return handleFetchError(error, path: "/design/human-interface-guidelines")
      }
    }

    // HIG pages
    router.get("/design/human-interface-guidelines/{path+}") { request, context -> Response in
      let higPath = context.parameters.get("path") ?? ""

      guard !higPath.isEmpty else {
        return errorResponse(status: .badRequest, message: "Invalid HIG path")
      }

      do {
        let markdown = try await AppleDocsActions.fetchHIG(path: higPath)
        let sourceUrl =
          "https://developer.apple.com/design/human-interface-guidelines/\(higPath)"

        return markdownResponse(
          markdown: markdown,
          sourceURL: sourceUrl,
          request: request
        )
      } catch {
        return handleFetchError(
          error, path: "/design/human-interface-guidelines/\(higPath)")
      }
    }

    // Video transcripts
    router.get("/videos/play/{collection}/{id}") { request, context -> Response in
      let collection = context.parameters.get("collection") ?? ""
      let videoId = context.parameters.get("id") ?? ""

      guard !collection.isEmpty, !videoId.isEmpty else {
        return errorResponse(
          status: .badRequest,
          message:
            "Invalid video path. Supported format: /videos/play/COLLECTION/VIDEO_ID")
      }

      do {
        let videoPath = "videos/play/\(collection)/\(videoId)"
        let markdown = try await AppleDocsActions.fetchVideo(path: videoPath)
        let sourceUrl =
          "https://developer.apple.com/videos/play/\(collection)/\(videoId)/"

        return markdownResponse(
          markdown: markdown,
          sourceURL: sourceUrl,
          request: request
        )
      } catch {
        return handleFetchError(
          error, path: "/videos/play/\(collection)/\(videoId)")
      }
    }

    // External documentation
    router.get("/external/{path+}") { request, context -> Response in
      let externalPath = context.parameters.get("path") ?? ""

      guard !externalPath.isEmpty else {
        return errorResponse(status: .badRequest, message: "Invalid external path")
      }

      let targetUrl = "https://\(externalPath)"

      do {
        let markdown = try await AppleDocsActions.fetchExternal(url: targetUrl)

        return markdownResponse(
          markdown: markdown,
          sourceURL: targetUrl,
          request: request
        )
      } catch {
        return handleExternalError(error, url: targetUrl)
      }
    }

    return router
  }

  // MARK: - Response Helpers

  private func markdownResponse(
    markdown: String,
    sourceURL: String,
    request: Request
  ) -> Response {
    let etag = generateETag(markdown)
    let acceptsJSON = ServerApp.acceptsApplicationJSON(request)

    if acceptsJSON {
      let jsonBody: [String: String] = ["url": sourceURL, "content": markdown]
      if let jsonData = try? JSONEncoder().encode(jsonBody),
        let jsonString = String(data: jsonData, encoding: .utf8)
      {
        return Response(
          status: .ok,
          headers: [
            .contentType: "application/json; charset=utf-8",
            .init("Content-Location")!: sourceURL,
            .cacheControl: "public, max-age=3600, s-maxage=86400",
            .init("ETag")!: etag,
          ],
          body: .init(byteBuffer: .init(string: jsonString))
        )
      }
    }

    return Response(
      status: .ok,
      headers: [
        .contentType: "text/markdown; charset=utf-8",
        .init("Content-Location")!: sourceURL,
        .cacheControl: "public, max-age=3600, s-maxage=86400",
        .init("ETag")!: etag,
      ],
      body: .init(byteBuffer: .init(string: markdown))
    )
  }

  private func handleFetchError(_ error: Error, path: String) -> Response {
    if let docsError = error as? AppleDocsError {
      switch docsError {
      case .notFound:
        return errorResponse(
          status: .notFound,
          message: "The requested documentation page does not exist: \(path)")
      case .insufficientContent:
        return errorResponse(
          status: .badGateway,
          message:
            "The documentation page loaded but contained insufficient content.")
      case .invalidPath, .invalidURL:
        return errorResponse(
          status: .badRequest,
          message: docsError.localizedDescription)
      default:
        break
      }
    }

    return errorResponse(
      status: .internalServerError,
      message: "Error fetching content: \(error.localizedDescription)")
  }

  private func handleExternalError(_ error: Error, url: String) -> Response {
    if let docsError = error as? AppleDocsError {
      switch docsError {
      case .accessDenied, .ssrfBlocked:
        return errorResponse(
          status: .forbidden,
          message:
            "External documentation access denied for \(url): \(docsError.localizedDescription)")
      case .robotsBlocked:
        return errorResponse(
          status: .forbidden,
          message: "Blocked by robots.txt for \(url)")
      case .notFound:
        return errorResponse(
          status: .notFound,
          message: "External documentation not found: \(url)")
      default:
        break
      }
    }

    return handleFetchError(error, path: "/external/\(url)")
  }

  // MARK: - Utilities

  private static func acceptsApplicationJSON(_ request: Request) -> Bool {
    let accept = request.headers[.accept] ?? ""
    return accept.contains("application/json")
  }

  private func generateETag(_ content: String) -> String {
    let data = Data(content.utf8)
    let base64 = data.prefix(12).base64EncodedString().prefix(16)
    return "\"\(base64)\""
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
    GET /external/{host}/{path}

    ### Search
    GET /search?q={query}

    ## Content Negotiation

    All endpoints return text/markdown by default.
    Set `Accept: application/json` for JSON output.

    ## Available MCP Tools

    - `searchAppleDocumentation` - Search Apple Developer documentation
    - `fetchAppleDocumentation` - Fetch documentation, HIG, or video transcripts by path
    - `fetchExternalDocumentation` - Fetch external Swift-DocC documentation by URL
    - `fetchAppleVideoTranscript` - Fetch Apple Developer video transcripts

    ---
    *Generated by [swift-developer-docs-mcp](https://github.com/mehmetbaykar/swift-developer-docs-mcp)*
    """
}

// MARK: - Standalone response helpers

private func errorResponse(status: HTTPResponse.Status, message: String) -> Response {
  let markdown = """
    # \(status.code == 404 ? "Not Found" : status.code == 400 ? "Bad Request" : status.code == 403 ? "Forbidden" : status.code == 502 ? "Bad Gateway" : "Error")

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
