import Foundation
import Testing

@testable import AppleDocsCore

@Suite("RobotsPolicy")
struct RobotsPolicyTests {

  @Suite("RobotsPolicyResult")
  struct PolicyResult {
    @Test("Evaluates allow-all as allowed")
    func allowAll() {
      let result = RobotsPolicy.evaluatePolicy(
        .allowAll,
        url: URL(string: "https://example.com/path")!,
        userAgent: "test-bot"
      )
      #expect(result == true)
    }

    @Test("Evaluates deny-all as denied")
    func denyAll() {
      let result = RobotsPolicy.evaluatePolicy(
        .denyAll,
        url: URL(string: "https://example.com/path")!,
        userAgent: "test-bot"
      )
      #expect(result == false)
    }

    @Test("Evaluates not-found as allowed")
    func notFound() {
      let result = RobotsPolicy.evaluatePolicy(
        .notFound,
        url: URL(string: "https://example.com/path")!,
        userAgent: "test-bot"
      )
      #expect(result == true)
    }
  }

  @Suite("Robots Text Evaluation")
  struct RobotsTextEvaluation {
    @Test("Allows when no matching disallow rules")
    func noDisallow() {
      let robotsText = """
        User-agent: *
        Disallow: /private/
        """
      let result = RobotsPolicy.evaluateRobotsText(
        robotsText,
        url: URL(string: "https://example.com/public/page")!,
        userAgent: "test-bot"
      )
      #expect(result == true)
    }

    @Test("Blocks when path matches disallow rule")
    func matchesDisallow() {
      let robotsText = """
        User-agent: *
        Disallow: /private/
        """
      let result = RobotsPolicy.evaluateRobotsText(
        robotsText,
        url: URL(string: "https://example.com/private/page")!,
        userAgent: "test-bot"
      )
      #expect(result == false)
    }

    @Test("Allows when disallow is empty")
    func emptyDisallow() {
      let robotsText = """
        User-agent: *
        Disallow:
        """
      let result = RobotsPolicy.evaluateRobotsText(
        robotsText,
        url: URL(string: "https://example.com/any/path")!,
        userAgent: "test-bot"
      )
      #expect(result == true)
    }

    @Test("Blocks when root is disallowed")
    func rootDisallow() {
      let robotsText = """
        User-agent: *
        Disallow: /
        """
      let result = RobotsPolicy.evaluateRobotsText(
        robotsText,
        url: URL(string: "https://example.com/any/page")!,
        userAgent: "test-bot"
      )
      #expect(result == false)
    }
  }

  @Suite("Fetch Robots Policy")
  struct FetchPolicy {
    // HTTPURLResponse cannot be constructed on Linux (FoundationNetworking aliases it to AnyObject),
    // so tests using HTTPURLResponse are conditionally compiled for Apple platforms only.
    #if !canImport(FoundationNetworking)
      @Test("Returns not-found for 404 response")
      func notFound404() async {
        let policy = await RobotsPolicy.fetchRobotsPolicy(
          origin: "https://example.com",
          userAgent: "test-bot"
        ) { _ in
          let response = HTTPURLResponse(
            url: URL(string: "https://example.com/robots.txt")!,
            statusCode: 404, httpVersion: nil, headerFields: nil)!
          return (Data(), response)
        }
        #expect(policy == .notFound)
      }

      @Test("Returns deny-all for 401 response")
      func denyAll401() async {
        let policy = await RobotsPolicy.fetchRobotsPolicy(
          origin: "https://example.com",
          userAgent: "test-bot"
        ) { _ in
          let response = HTTPURLResponse(
            url: URL(string: "https://example.com/robots.txt")!,
            statusCode: 401, httpVersion: nil, headerFields: nil)!
          return (Data(), response)
        }
        #expect(policy == .denyAll)
      }

      @Test("Returns allow-all for 500 response")
      func allowAll500() async {
        let policy = await RobotsPolicy.fetchRobotsPolicy(
          origin: "https://example.com",
          userAgent: "test-bot"
        ) { _ in
          let response = HTTPURLResponse(
            url: URL(string: "https://example.com/robots.txt")!,
            statusCode: 500, httpVersion: nil, headerFields: nil)!
          return (Data(), response)
        }
        #expect(policy == .allowAll)
      }

      @Test("Returns rules for 200 response")
      func rules200() async {
        let robotsText = "User-agent: *\nDisallow: /private/"
        let policy = await RobotsPolicy.fetchRobotsPolicy(
          origin: "https://example.com",
          userAgent: "test-bot"
        ) { _ in
          let response = HTTPURLResponse(
            url: URL(string: "https://example.com/robots.txt")!,
            statusCode: 200, httpVersion: nil, headerFields: nil)!
          return (robotsText.data(using: .utf8)!, response)
        }
        #expect(policy == .rules(robotsText))
      }
    #endif

    @Test("Returns allow-all on network error")
    func networkError() async {
      let policy = await RobotsPolicy.fetchRobotsPolicy(
        origin: "https://example.com",
        userAgent: "test-bot"
      ) { _ in
        throw URLError(.notConnectedToInternet)
      }
      #expect(policy == .allowAll)
    }
  }

  @Suite("X-Robots-Tag Detection")
  struct XRobotsTag {
    @Test("Detects restrictive tags")
    func restrictiveTags() {
      #expect(RobotsPolicy.containsRestrictiveXRobotsTag("none") == true)
      #expect(RobotsPolicy.containsRestrictiveXRobotsTag("noindex") == true)
      #expect(RobotsPolicy.containsRestrictiveXRobotsTag("noai") == true)
      #expect(RobotsPolicy.containsRestrictiveXRobotsTag("noimageai") == true)
    }

    @Test("Detects restrictive tags in mixed headers")
    func mixedHeaders() {
      #expect(RobotsPolicy.containsRestrictiveXRobotsTag("nofollow, noai") == true)
      #expect(RobotsPolicy.containsRestrictiveXRobotsTag("NOINDEX, follow") == true)
    }

    @Test("Allows non-restrictive tags")
    func nonRestrictive() {
      #expect(RobotsPolicy.containsRestrictiveXRobotsTag("nofollow") == false)
      #expect(RobotsPolicy.containsRestrictiveXRobotsTag("follow") == false)
      #expect(RobotsPolicy.containsRestrictiveXRobotsTag("all") == false)
    }

    @Test("Handles nil header")
    func nilHeader() {
      #expect(RobotsPolicy.containsRestrictiveXRobotsTag(nil) == false)
    }

    @Test("Handles empty header")
    func emptyHeader() {
      #expect(RobotsPolicy.containsRestrictiveXRobotsTag("") == false)
    }
  }

  @Suite("Root Origin")
  struct RootOrigin {
    @Test("Extracts root origin from subdomain")
    func subdomain() {
      let result = RobotsPolicy.getRootOrigin("https://docs.example.com")
      #expect(result == "https://example.com")
    }

    @Test("Returns nil for two-label domain")
    func twoLabels() {
      let result = RobotsPolicy.getRootOrigin("https://example.com")
      #expect(result == nil)
    }

    @Test("Returns nil for invalid URL")
    func invalid() {
      let result = RobotsPolicy.getRootOrigin("not-a-url")
      #expect(result == nil)
    }
  }

  @Suite("Cache")
  struct CacheTests {
    @Test("Caches and retrieves policy")
    func cacheHit() async {
      let cache = RobotsCache()
      await cache.set("https://example.com", policy: .allowAll)
      let result = await cache.get("https://example.com")
      #expect(result == .allowAll)
    }

    @Test("Returns nil for cache miss")
    func cacheMiss() async {
      let cache = RobotsCache()
      let result = await cache.get("https://example.com")
      #expect(result == nil)
    }

    @Test("Clears cache")
    func clearCache() async {
      let cache = RobotsCache()
      await cache.set("https://example.com", policy: .allowAll)
      await cache.clear()
      let result = await cache.get("https://example.com")
      #expect(result == nil)
    }

    @Test("In-flight deduplication tracks tasks")
    func inFlightDedup() async {
      let cache = RobotsCache()

      // Verify in-flight tracking works
      let task = Task<RobotsPolicyResult, Never> { .allowAll }
      await cache.setInFlight("https://example.com", task: task)

      let retrieved = await cache.getInFlight("https://example.com")
      #expect(retrieved != nil)

      let result = await retrieved!.value
      #expect(result == .allowAll)

      await cache.removeInFlight("https://example.com")
      let afterRemoval = await cache.getInFlight("https://example.com")
      #expect(afterRemoval == nil)
    }

    @Test("Clear removes in-flight tasks")
    func clearInFlight() async {
      let cache = RobotsCache()
      let task = Task<RobotsPolicyResult, Never> { .denyAll }
      await cache.setInFlight("https://example.com", task: task)
      await cache.clear()
      let result = await cache.getInFlight("https://example.com")
      #expect(result == nil)
    }
  }
}
