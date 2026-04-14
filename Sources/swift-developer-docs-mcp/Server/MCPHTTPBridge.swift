import FastMCP
import Foundation

struct MCPBridgeResponse: Sendable {
  let statusCode: Int
  let headers: [String: String]
  let body: Data?
  let stream: AsyncThrowingStream<Data, Error>?

  init(response: HTTPResponse) {
    self.statusCode = response.statusCode
    self.headers = response.headers

    switch response {
    case .stream(let stream, _):
      self.body = nil
      self.stream = stream
    default:
      self.body = response.bodyData
      self.stream = nil
    }
  }
}

actor MCPHTTPBridge {
  struct Configuration: Sendable {
    let sessionTimeout: TimeInterval
    let retryInterval: Int?

    init(sessionTimeout: TimeInterval = 3600, retryInterval: Int? = nil) {
      self.sessionTimeout = sessionTimeout
      self.retryInterval = retryInterval
    }
  }

  private struct FixedSessionIDGenerator: SessionIDGenerator {
    let sessionID: String

    func generateSessionID() -> String {
      sessionID
    }
  }

  private struct SessionContext: Sendable {
    let server: Server
    let transport: StatefulHTTPServerTransport
    let createdAt: Date
    var lastAccessedAt: Date
  }

  private let configuration: Configuration
  private let mcpServer: AppleDocsMCPServer
  private let validationPipeline: (any HTTPRequestValidationPipeline)?
  private var sessions: [String: SessionContext] = [:]

  init(
    mcpServer: AppleDocsMCPServer,
    hostname: String,
    port: Int,
    configuration: Configuration = Configuration()
  ) {
    self.mcpServer = mcpServer
    self.configuration = configuration
    self.validationPipeline = Self.makeValidationPipeline(hostname: hostname, port: port)

    Task { [weak self] in
      await self?.sessionCleanupLoop()
    }
  }

  func handle(
    method: String,
    headers: [String: String],
    body: Data?
  ) async -> MCPBridgeResponse {
    let request = HTTPRequest(
      method: method,
      headers: headers,
      body: body
    )

    let response = await handle(request)
    return MCPBridgeResponse(response: response)
  }

  func shutdown() async {
    await closeAllSessions()
  }

  private func handle(_ request: HTTPRequest) async -> HTTPResponse {
    let sessionID = request.header(HTTPHeaderName.sessionID)

    if let sessionID, var session = sessions[sessionID] {
      session.lastAccessedAt = Date()
      sessions[sessionID] = session

      let response = await session.transport.handleRequest(request)

      if request.method.uppercased() == "DELETE", response.statusCode == 200 {
        sessions.removeValue(forKey: sessionID)
      }

      return response
    }

    if request.method.uppercased() == "POST",
      let body = request.body,
      Self.isInitializeRequest(body)
    {
      return await createSessionAndHandle(request)
    }

    if sessionID != nil {
      return .error(statusCode: 404, .invalidRequest("Not Found: Session not found or expired"))
    }

    return .error(
      statusCode: 400,
      .invalidRequest("Bad Request: Missing \(HTTPHeaderName.sessionID) header")
    )
  }

  private func createSessionAndHandle(_ request: HTTPRequest) async -> HTTPResponse {
    let sessionID = UUID().uuidString
    let transport = StatefulHTTPServerTransport(
      sessionIDGenerator: FixedSessionIDGenerator(sessionID: sessionID),
      validationPipeline: validationPipeline,
      retryInterval: configuration.retryInterval
    )

    do {
      let server = await mcpServer.makeServer()
      try await server.start(transport: transport)

      sessions[sessionID] = SessionContext(
        server: server,
        transport: transport,
        createdAt: Date(),
        lastAccessedAt: Date()
      )

      let response = await transport.handleRequest(request)

      if case .error = response {
        sessions.removeValue(forKey: sessionID)
        await transport.disconnect()
      }

      return response
    } catch {
      await transport.disconnect()
      return .error(
        statusCode: 500,
        .internalError("Failed to create session: \(error.localizedDescription)")
      )
    }
  }

  private func closeSession(_ sessionID: String) async {
    guard let session = sessions.removeValue(forKey: sessionID) else { return }
    await session.transport.disconnect()
  }

  private func closeAllSessions() async {
    for sessionID in sessions.keys {
      await closeSession(sessionID)
    }
  }

  private func sessionCleanupLoop() async {
    while !Task.isCancelled {
      try? await Task.sleep(for: .seconds(60))

      let now = Date()
      let expiredSessionIDs = sessions.compactMap { sessionID, context in
        now.timeIntervalSince(context.lastAccessedAt) > configuration.sessionTimeout
          ? sessionID : nil
      }

      for sessionID in expiredSessionIDs {
        await closeSession(sessionID)
      }
    }
  }

  private static func makeValidationPipeline(
    hostname: String,
    port: Int
  ) -> (any HTTPRequestValidationPipeline)? {
    let normalizedHost = hostname.lowercased()
    let originValidator: any HTTPRequestValidator =
      if normalizedHost == "127.0.0.1" || normalizedHost == "localhost" || normalizedHost == "::1" {
        OriginValidator.localhost(port: port)
      } else {
        OriginValidator.disabled
      }

    return StandardValidationPipeline(validators: [
      originValidator,
      AcceptHeaderValidator(mode: .sseRequired),
      ContentTypeValidator(),
      ProtocolVersionValidator(),
      SessionValidator(),
    ])
  }

  /// Uses raw JSON parsing because `JSONRPCMessageKind` is package-scoped in the MCP SDK.
  private static func isInitializeRequest(_ data: Data) -> Bool {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let method = json["method"] as? String
    else {
      return false
    }

    return method == "initialize"
  }
}
