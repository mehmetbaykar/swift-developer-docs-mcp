import Hummingbird

struct TrailingSlashMiddleware<Context: RequestContext>: RouterMiddleware {
  func handle(
    _ request: Request,
    context: Context,
    next: (Request, Context) async throws -> Response
  ) async throws -> Response {
    let path = request.uri.path
    if path != "/", path.hasSuffix("/") {
      let trimmed = String(path.dropLast())
      let query = request.uri.query.map { "?\($0)" } ?? ""
      return Response(
        status: .movedPermanently,
        headers: [.location: "\(trimmed)\(query)"]
      )
    }
    return try await next(request, context)
  }
}
