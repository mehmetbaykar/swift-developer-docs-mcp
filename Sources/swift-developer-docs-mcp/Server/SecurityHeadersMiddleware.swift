import Hummingbird

struct SecurityHeadersMiddleware<Context: RequestContext>: RouterMiddleware {
  func handle(
    _ request: Request,
    context: Context,
    next: (Request, Context) async throws -> Response
  ) async throws -> Response {
    var response = try await next(request, context)

    response.headers[.init("X-Content-Type-Options")!] = "nosniff"
    response.headers[.init("X-Frame-Options")!] = "DENY"
    response.headers[.init("X-XSS-Protection")!] = "1; mode=block"
    response.headers[.init("Referrer-Policy")!] = "strict-origin-when-cross-origin"
    response.headers[.init("Permissions-Policy")!] = "camera=(), microphone=(), geolocation=()"
    response.headers[.vary] = "Accept"

    return response
  }
}
