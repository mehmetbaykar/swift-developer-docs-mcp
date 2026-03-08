import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public enum RobotsPolicyResult: Sendable, Equatable {
  case allowAll
  case denyAll
  case notFound
  case rules(String)
}

public actor RobotsCache {
  private struct CacheEntry {
    let policy: RobotsPolicyResult
    let expiresAt: Date
  }

  private var cache: [String: CacheEntry] = [:]
  private var inFlight: [String: Task<RobotsPolicyResult, Never>] = [:]
  private static let ttl: TimeInterval = 5 * 60  // 5 minutes
  private static let maxEntries = 1000
  private static let maxInFlight = 1000

  public init() {}

  public func get(_ origin: String) -> RobotsPolicyResult? {
    guard let entry = cache[origin], entry.expiresAt > Date() else {
      return nil
    }
    return entry.policy
  }

  public func set(_ origin: String, policy: RobotsPolicyResult) {
    pruneExpired()
    if cache.count >= Self.maxEntries {
      if let oldest = cache.keys.first {
        cache.removeValue(forKey: oldest)
      }
    }
    cache[origin] = CacheEntry(policy: policy, expiresAt: Date().addingTimeInterval(Self.ttl))
  }

  /// Returns an existing in-flight task for this origin, if any.
  public func getInFlight(_ origin: String) -> Task<RobotsPolicyResult, Never>? {
    inFlight[origin]
  }

  /// Registers an in-flight task for deduplication. Evicts oldest if at capacity.
  public func setInFlight(_ origin: String, task: Task<RobotsPolicyResult, Never>) {
    if inFlight.count >= Self.maxInFlight, !inFlight.keys.contains(origin) {
      if let oldest = inFlight.keys.first {
        inFlight.removeValue(forKey: oldest)
      }
    }
    inFlight[origin] = task
  }

  /// Removes a completed in-flight task.
  public func removeInFlight(_ origin: String) {
    inFlight.removeValue(forKey: origin)
  }

  private func pruneExpired() {
    let now = Date()
    for (key, entry) in cache where entry.expiresAt <= now {
      cache.removeValue(forKey: key)
    }
  }

  public func clear() {
    cache.removeAll()
    inFlight.removeAll()
  }
}

public enum RobotsPolicy: Sendable {
  private static let restrictiveXRobotsTags: Set<String> = [
    "none", "noindex", "noai", "noimageai",
  ]

  public static func fetchRobotsPolicy(
    origin: String,
    userAgent: String,
    fetcher: @Sendable (_ url: URL) async throws -> (Data, URLResponse) =
      URLSession.shared.data(from:)
  ) async -> RobotsPolicyResult {
    guard let robotsUrl = URL(string: "\(origin)/robots.txt") else {
      return .allowAll
    }

    do {
      let (data, response) = try await fetcher(robotsUrl)

      if let httpResponse = response as? HTTPURLResponse {
        switch httpResponse.statusCode {
        case 404, 410, 403:
          return .notFound
        case 401:
          return .denyAll
        case 200:
          if let robotsText = String(data: data, encoding: .utf8) {
            return .rules(robotsText)
          }
          return .allowAll
        default:
          return .allowAll
        }
      }

      return .allowAll
    } catch {
      return .allowAll
    }
  }

  public static func isAllowedByRobots(
    url: URL,
    userAgent: String,
    cache: RobotsCache,
    fetcher: @escaping @Sendable (_ url: URL) async throws -> (Data, URLResponse) =
      URLSession.shared.data(from:)
  ) async -> Bool {
    guard let host = url.host, let scheme = url.scheme else {
      return true
    }

    let origin = "\(scheme)://\(host)"

    // Check cache first
    if let cached = await cache.get(origin) {
      return evaluatePolicy(cached, url: url, userAgent: userAgent)
    }

    // Check for in-flight request to deduplicate concurrent fetches
    if let existing = await cache.getInFlight(origin) {
      let policy = await existing.value
      return evaluatePolicy(policy, url: url, userAgent: userAgent)
    }

    // Create a new in-flight task
    let task = Task<RobotsPolicyResult, Never> {
      var policy = await fetchRobotsPolicy(
        origin: origin, userAgent: userAgent, fetcher: fetcher)

      if case .notFound = policy {
        let rootOrigin = getRootOrigin(origin)
        if let rootOrigin, rootOrigin != origin {
          let rootPolicy = await fetchRobotsPolicy(
            origin: rootOrigin, userAgent: userAgent, fetcher: fetcher)
          if case .notFound = rootPolicy {
            policy = .allowAll
          } else {
            policy = rootPolicy
          }
        } else {
          policy = .allowAll
        }
      }

      await cache.set(origin, policy: policy)
      await cache.removeInFlight(origin)
      return policy
    }

    await cache.setInFlight(origin, task: task)
    let policy = await task.value
    return evaluatePolicy(policy, url: url, userAgent: userAgent)
  }

  static func evaluatePolicy(
    _ policy: RobotsPolicyResult, url: URL, userAgent: String
  ) -> Bool {
    switch policy {
    case .allowAll:
      return true
    case .denyAll:
      return false
    case .notFound:
      return true
    case .rules(let robotsText):
      return evaluateRobotsText(robotsText, url: url, userAgent: userAgent)
    }
  }

  static func evaluateRobotsText(
    _ robotsText: String, url: URL, userAgent: String
  ) -> Bool {
    let lines = robotsText.components(separatedBy: .newlines)
    var currentAgent = ""
    var disallowedPaths: [String] = []
    var matchesAgent = false

    let lowerUserAgent = userAgent.lowercased()

    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

      if let colonIndex = trimmed.firstIndex(of: ":") {
        let field = trimmed[..<colonIndex].trimmingCharacters(in: .whitespaces).lowercased()
        let value = trimmed[trimmed.index(after: colonIndex)...]
          .trimmingCharacters(in: .whitespaces)

        switch field {
        case "user-agent":
          currentAgent = value.lowercased()
          matchesAgent = currentAgent == "*" || lowerUserAgent.contains(currentAgent)
        case "disallow":
          if matchesAgent && !value.isEmpty {
            disallowedPaths.append(value)
          }
        default:
          break
        }
      }
    }

    let urlPath = url.path
    for disallowed in disallowedPaths {
      if urlPath.hasPrefix(disallowed) {
        return false
      }
    }

    return true
  }

  static func getRootOrigin(_ origin: String) -> String? {
    guard let url = URL(string: origin), let host = url.host else {
      return nil
    }

    let labels = host.lowercased().split(separator: ".")
    if labels.count < 3 { return nil }

    let rootHost = labels.suffix(2).joined(separator: ".")
    return "\(url.scheme ?? "https")://\(rootHost)"
  }

  public static func containsRestrictiveXRobotsTag(_ headerValue: String?) -> Bool {
    guard let headerValue, !headerValue.isEmpty else {
      return false
    }

    let tokens = Set(
      headerValue
        .lowercased()
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
    )

    return !tokens.isDisjoint(with: restrictiveXRobotsTags)
  }
}
