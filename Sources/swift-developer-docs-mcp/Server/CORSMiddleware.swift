import Hummingbird

struct CORSMiddleware<Context: RequestContext>: RouterMiddleware {
  func handle(
    _ request: Request,
    context: Context,
    next: (Request, Context) async throws -> Response
  ) async throws -> Response {
    var response = try await next(request, context)

    response.headers[.accessControlAllowOrigin] = "*"
    response.headers[.accessControlAllowMethods] = "GET, OPTIONS"
    response.headers[.accessControlAllowHeaders] = "Accept, Content-Type"

    return response
  }
}
