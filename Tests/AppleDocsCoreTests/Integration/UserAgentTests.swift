import Foundation
import Testing

@testable import AppleDocsCore

@Suite("User Agent Tests")
struct UserAgentTests {

  @Test("randomUserAgent returns a non-empty string")
  func randomUserAgentNonEmpty() {
    let ua = Fetcher.randomUserAgent()
    #expect(!ua.isEmpty)
  }

  @Test("randomUserAgent returns different values across 100 calls")
  func randomUserAgentVariety() {
    var agents: Set<String> = []
    for _ in 0..<100 {
      agents.insert(Fetcher.randomUserAgent())
    }
    #expect(agents.count >= 2)
  }

  @Test("User agent contains Safari or Mobile pattern")
  func userAgentContainsSafariOrMobile() {
    for agent in Fetcher.userAgents {
      let containsSafari = agent.contains("Safari")
      let containsMobile = agent.contains("Mobile")
      #expect(containsSafari || containsMobile)
    }
  }

  @Test("User agent array has at least 25 entries")
  func userAgentArraySize() {
    #expect(Fetcher.userAgents.count >= 25)
  }

  @Test("All user agents contain AppleWebKit")
  func userAgentsContainAppleWebKit() {
    for agent in Fetcher.userAgents {
      #expect(agent.contains("AppleWebKit"))
    }
  }

  @Test("randomUserAgent returns value from the userAgents array")
  func randomUserAgentFromArray() {
    for _ in 0..<50 {
      let ua = Fetcher.randomUserAgent()
      #expect(Fetcher.userAgents.contains(ua))
    }
  }
}
