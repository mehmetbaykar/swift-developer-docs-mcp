import Testing

@testable import AppleDocsCore

@Suite("Documentation page resolver")
struct DocumentationPageResolverTests {
  private let base = "https://developer.apple.com/tutorials/data/documentation"

  @Test("Removes a trailing slash before loading")
  func trailingSlash() async throws {
    let script = PageScript(slots: [
      "swift/array": .page(page("Array"))
    ])
    let resolved = try await resolve("swift/array/", script: script)
    #expect(resolved.path == "swift/array")
    #expect(resolved.data.metadata?.title == "Array")
    #expect(await script.requestedPaths() == ["swift/array"])
  }

  @Test("Resolves a path that omits a disambiguation suffix")
  func disambiguationSuffix() async throws {
    let script = PageScript(slots: [
      "swiftui/view": .page(
        page(
          "View",
          references: [
            "doc://com.apple.SwiftUI/documentation/SwiftUI/View/body-8kl5o": reference(
              "body",
              "/documentation/swiftui/view/body-8kl5o"
            )
          ]
        )
      ),
      "swiftui/view/body-8kl5o": .page(page("body")),
    ])

    let resolved = try await resolve("swiftui/view/body", script: script)
    #expect(resolved.path == "swiftui/view/body-8kl5o")
    #expect(resolved.data.metadata?.title == "body")
    #expect(
      await script.requestedPaths() == [
        "swiftui/view/body",
        "swiftui/view",
        "swiftui/view/body-8kl5o",
      ])
  }

  @Test("Fetches the only page whose path adds a suffix to the name")
  func suffixOnTheName() async throws {
    let script = PageScript(slots: [
      "observation": .page(observationParent),
      "observation/observable-8ab1c": .page(page("Observable()")),
    ])

    let resolved = try await resolve("/documentation/observation/observable", script: script)
    #expect(resolved.path == "observation/observable-8ab1c")
    #expect(resolved.data.metadata?.title == "Observable()")
    #expect(
      await script.requestedPaths() == [
        "observation/observable",
        "observation",
        "observation/observable-8ab1c",
      ])
  }

  @Test("Resolves a path that omits a signature")
  func omittedSignature() async throws {
    let script = PageScript(slots: exampleKitSlots)
    let resolved = try await resolve("examplekit/canvas/draw", script: script)
    #expect(resolved.path == "examplekit/canvas/draw(in:options:)")
  }

  @Test("Resolves a signature that omits trailing argument labels")
  func omittedArgumentLabels() async throws {
    let script = PageScript(slots: [
      "foundation/notificationcenter": .page(
        page(
          "NotificationCenter",
          references: [
            "doc://test/messages": reference(
              "messages(of:for:bufferSize:)",
              "/documentation/foundation/notificationcenter/messages(of:for:buffersize:)-623kg"
            )
          ]
        )
      ),
      "foundation/notificationcenter/messages(of:for:buffersize:)-623kg": .page(
        page("messages(of:for:bufferSize:)")
      ),
    ])

    let resolved = try await resolve(
      "foundation/notificationcenter/messages(of:for:)",
      script: script
    )
    #expect(
      resolved.path == "foundation/notificationcenter/messages(of:for:buffersize:)-623kg")
    #expect(await script.requestedPaths().count == 3)
  }

  @Test("Resolves a parent path that omits its disambiguation suffix")
  func resolvedParent() async throws {
    let script = PageScript(slots: exampleKitSlots)

    let resolved = try await resolve(
      "/documentation/examplekit/widget/size",
      script: script
    )
    #expect(resolved.path == "examplekit/widget-swift.struct/size")
    #expect(resolved.data.metadata?.title == "size")
    #expect(
      await script.requestedPaths() == [
        "examplekit/widget/size",
        "examplekit/widget",
        "examplekit",
        "examplekit/widget-swift.struct",
        "examplekit/widget-swift.struct/size",
      ])
  }

  @Test("uttype/markdown resolves to uttype-swift.struct/markdown")
  func uttypeMarkdown() async throws {
    let script = PageScript(slots: [
      "uniformtypeidentifiers": .page(
        page(
          "UniformTypeIdentifiers",
          references: [
            "doc://test/UTType-swift": reference(
              "UTType",
              "/documentation/uniformtypeidentifiers/uttype-swift.struct"
            ),
            "doc://test/UTType-objc": reference(
              "UTType",
              "/documentation/uniformtypeidentifiers/uttype-c.struct"
            ),
          ]
        )
      ),
      "uniformtypeidentifiers/uttype-swift.struct": .page(
        page(
          "UTType",
          references: [
            "doc://test/UTType/markdown": reference(
              "markdown",
              "/documentation/uniformtypeidentifiers/uttype-swift.struct/markdown"
            )
          ]
        )
      ),
      "uniformtypeidentifiers/uttype-swift.struct/markdown": .page(page("markdown")),
    ])

    let resolved = try await resolve(
      "uniformtypeidentifiers/uttype/markdown",
      script: script
    )
    #expect(resolved.path == "uniformtypeidentifiers/uttype-swift.struct/markdown")
    #expect(resolved.data.metadata?.title == "markdown")
  }

  @Test("Fetches the Swift symbol instead of its Objective-C counterparts")
  func swiftOverObjectiveC() async throws {
    let script = PageScript(slots: exampleKitSlots)
    let resolved = try await resolve("examplekit/widget", script: script)
    #expect(resolved.path == "examplekit/widget-swift.struct")
    #expect(resolved.data.metadata?.title == "Widget")
  }

  @Test("Lists candidates when more than one symbol matches")
  func ambiguousCandidates() async throws {
    let script = PageScript(slots: [
      "observation": .page(observationParent)
    ])
    let url = "\(base)/observation/withobservationtracking.json"

    do {
      _ = try await resolve("observation/withobservationtracking", script: script)
      Issue.record("Expected documentationNotFound")
    } catch let error as AppleDocsError {
      guard case .documentationNotFound(let foundURL, let candidates) = error else {
        Issue.record("Expected documentationNotFound, got \(error)")
        return
      }
      #expect(foundURL == url)
      #expect(
        candidates == [
          DocumentationCandidate(
            path: "observation/withobservationtracking(_:onchange:)",
            title: "withObservationTracking(_:onChange:)"
          ),
          DocumentationCandidate(
            path: "observation/withobservationtracking(options:_:onchange:)",
            title: "withObservationTracking(options:_:onChange:)"
          ),
        ])
      #expect(
        error.localizedDescription
          == "Apple documentation page not found at \(url)\n"
          + "The path matches more than one symbol. Fetch one of these paths:\n"
          + "- withObservationTracking(_:onChange:): /documentation/observation/withobservationtracking(_:onchange:)\n"
          + "- withObservationTracking(options:_:onChange:): /documentation/observation/withobservationtracking(options:_:onchange:)"
      )
    }
  }

  @Test("Lists overloads of a signature without its disambiguation suffix")
  func ambiguousOverloads() async throws {
    let script = PageScript(slots: exampleKitSlots)
    do {
      _ = try await resolve("examplekit/canvas/fill(_:)", script: script)
      Issue.record("Expected documentationNotFound")
    } catch let error as AppleDocsError {
      guard case .documentationNotFound(_, let candidates) = error else {
        Issue.record("Expected documentationNotFound, got \(error)")
        return
      }
      #expect(
        candidates.map(\.path) == [
          "examplekit/canvas/fill(_:)-1a2b3",
          "examplekit/canvas/fill(_:)-4c5d6",
        ])
    }
  }

  @Test("A path with no match throws the first not-found error")
  func noMatchThrowsFirstNotFound() async throws {
    let script = PageScript(slots: [
      "observation": .page(observationParent)
    ])
    let url = "\(base)/observation/observation.json"

    do {
      _ = try await resolve("observation/observation", script: script)
      Issue.record("Expected documentationNotFound")
    } catch let error as AppleDocsError {
      guard case .documentationNotFound(let foundURL, let candidates) = error else {
        Issue.record("Expected documentationNotFound, got \(error)")
        return
      }
      #expect(error.isNotFound)
      #expect(candidates == [])
      #expect(foundURL == url)
      #expect(error.localizedDescription == "Apple documentation page not found at \(url)")
      #expect(await script.requestedPaths() == ["observation/observation", "observation"])
    }
  }

  @Test("Does not resolve a signature that no page starts with")
  func unmatchedSignature() async throws {
    let script = PageScript(slots: [
      "observation": .page(observationParent)
    ])
    do {
      _ = try await resolve(
        "observation/withobservationtracking(onchange:)",
        script: script
      )
      Issue.record("Expected documentationNotFound")
    } catch let error as AppleDocsError {
      guard case .documentationNotFound(_, let candidates) = error else {
        Issue.record("Expected documentationNotFound, got \(error)")
        return
      }
      #expect(candidates == [])
      #expect(await script.requestedPaths().count == 2)
    }
  }

  @Test("Does not resolve parents beyond one level")
  func parentDepthLimit() async throws {
    let script = PageScript(slots: exampleKitSlots)
    let url = "\(base)/examplekit/widget/missing/size.json"
    do {
      _ = try await resolve("examplekit/widget/missing/size", script: script)
      Issue.record("Expected documentationNotFound")
    } catch let error as AppleDocsError {
      guard case .documentationNotFound(let foundURL, let candidates) = error else {
        Issue.record("Expected documentationNotFound, got \(error)")
        return
      }
      #expect(foundURL == url)
      #expect(candidates == [])
      #expect(
        await script.requestedPaths() == [
          "examplekit/widget/missing/size",
          "examplekit/widget/missing",
          "examplekit/widget",
        ])
    }
  }

  @Test("A 5xx response for the parent page propagates")
  func parentServerError() async throws {
    let url = "\(base)/swift.json"
    let script = PageScript(slots: [
      "swift": .docs(.httpError(statusCode: 503, url: url))
    ])
    do {
      _ = try await resolve("swift/array", script: script)
      Issue.record("Expected httpError")
    } catch let error as AppleDocsError {
      guard case .httpError(let statusCode, let foundURL) = error else {
        Issue.record("Expected httpError, got \(error)")
        return
      }
      #expect(statusCode == 503)
      #expect(foundURL == url)
      #expect(!error.isNotFound)
      #expect(error.localizedDescription == "HTTP 503 fetching \(url)")
    } catch {
      Issue.record("Expected httpError, got \(error)")
    }
  }

  @Test("A network failure for the parent page propagates")
  func parentNetworkFailure() async throws {
    let script = PageScript(slots: [
      "swift": .probe("fetch failed")
    ])
    do {
      _ = try await resolve("swift/array", script: script)
      Issue.record("Expected ProbeError")
    } catch let error as ProbeError {
      #expect(error.message == "fetch failed")
    } catch {
      Issue.record("Expected ProbeError, got \(error)")
    }
  }

  @Test("Invalid JSON for the parent page propagates")
  func parentInvalidJSON() async throws {
    let script = PageScript(slots: [
      "swift": .docs(.decodingError(underlying: ProbeError(message: "invalid json")))
    ])
    do {
      _ = try await resolve("swift/array", script: script)
      Issue.record("Expected decodingError")
    } catch let error as AppleDocsError {
      guard case .decodingError = error else {
        Issue.record("Expected decodingError, got \(error)")
        return
      }
      #expect(!error.isNotFound)
    } catch {
      Issue.record("Expected decodingError, got \(error)")
    }
  }

  @Test("A 5xx response while resolving the parent path propagates")
  func grandparentServerError() async throws {
    let url = "\(base)/examplekit.json"
    let script = PageScript(slots: [
      "examplekit": .docs(.httpError(statusCode: 502, url: url))
    ])
    do {
      _ = try await resolve("examplekit/widget/size", script: script)
      Issue.record("Expected httpError")
    } catch let error as AppleDocsError {
      guard case .httpError(let statusCode, let foundURL) = error else {
        Issue.record("Expected httpError, got \(error)")
        return
      }
      #expect(statusCode == 502)
      #expect(foundURL == url)
      #expect(!error.isNotFound)
      #expect(
        await script.requestedPaths() == [
          "examplekit/widget/size",
          "examplekit/widget",
          "examplekit",
        ])
    } catch {
      Issue.record("Expected httpError, got \(error)")
    }
  }

  @Test("Framework roots use the documentation page JSON URL")
  func frameworkPageURL() {
    #expect(
      Fetcher.pageJSONURL(normalizedPath: "swiftui")
        == "\(base)/swiftui.json")
    #expect(
      Fetcher.pageJSONURL(normalizedPath: "swiftui/view")
        == "\(base)/swiftui/view.json")
  }

  @Test("draw(in:) resolves to draw(in:options:)")
  func partialSignatureFromUpstream() async throws {
    let script = PageScript(slots: exampleKitSlots)
    let resolved = try await resolve("examplekit/canvas/draw(in:)", script: script)
    #expect(resolved.path == "examplekit/canvas/draw(in:options:)")
  }

  private var observationParent: AppleDocJSON {
    page(
      "Observation",
      references: [
        "doc://com.apple.documentation/documentation/Observation/withObservationTracking(_:onChange:)":
          reference(
            "withObservationTracking(_:onChange:)",
            "/documentation/observation/withobservationtracking(_:onchange:)"
          ),
        "doc://com.apple.documentation/documentation/Observation/withObservationTracking(options:_:onChange:)":
          reference(
            "withObservationTracking(options:_:onChange:)",
            "/documentation/observation/withobservationtracking(options:_:onchange:)"
          ),
        "doc://com.apple.documentation/documentation/Observation/ObservationTracking": reference(
          "ObservationTracking",
          "/documentation/observation/observationtracking"
        ),
        "doc://com.apple.documentation/documentation/Observation/Observable-macro": reference(
          "Observable()",
          "/documentation/observation/observable-8ab1c"
        ),
        "doc://com.apple.documentation/documentation/Observation/Observable/Child": reference(
          "Child",
          "/documentation/observation/observable/child-1a2b3"
        ),
      ]
    )
  }

  private var exampleKitSlots: [String: PageScript.Slot] {
    [
      "examplekit": .page(
        page(
          "ExampleKit",
          references: [
            "doc://test/Widget-swift": reference(
              "Widget",
              "/documentation/examplekit/widget-swift.struct"
            ),
            "doc://test/Widget-objc": reference(
              "Widget",
              "/documentation/examplekit/widget-c.class"
            ),
            "doc://test/Canvas": reference(
              "Canvas",
              "/documentation/examplekit/canvas"
            ),
          ]
        )
      ),
      "examplekit/widget-swift.struct": .page(
        page(
          "Widget",
          references: [
            "doc://test/Widget/size": reference(
              "size",
              "/documentation/examplekit/widget-swift.struct/size"
            )
          ]
        )
      ),
      "examplekit/canvas": .page(
        page(
          "Canvas",
          references: [
            "doc://test/Canvas/draw": reference(
              "draw(in:options:)",
              "/documentation/examplekit/canvas/draw(in:options:)"
            ),
            "doc://test/Canvas/fill-1": reference(
              "fill(_:)",
              "/documentation/examplekit/canvas/fill(_:)-1a2b3"
            ),
            "doc://test/Canvas/fill-2": reference(
              "fill(_:)",
              "/documentation/examplekit/canvas/fill(_:)-4c5d6"
            ),
          ]
        )
      ),
      "examplekit/widget-swift.struct/size": .page(page("size")),
      "examplekit/canvas/draw(in:options:)": .page(page("draw(in:options:)")),
    ]
  }

  private func resolve(_ path: String, script: PageScript) async throws -> DocumentationPage {
    try await DocumentationPageResolver.resolve(path: path) { requested in
      try await script.load(requested)
    }
  }

  private func page(_ title: String, references: [String: ContentItem]? = nil) -> AppleDocJSON {
    AppleDocJSON(
      metadata: DocumentationMetadata(title: title),
      references: references
    )
  }

  private func reference(_ title: String, _ url: String) -> ContentItem {
    ContentItem(title: title, url: url)
  }
}

private struct ProbeError: Error, Equatable, Sendable {
  let message: String
}

private actor PageScript {
  enum Slot: Sendable {
    case page(AppleDocJSON)
    case docs(AppleDocsError)
    case probe(String)
  }

  private let slots: [String: Slot]
  private var requested: [String] = []

  init(slots: [String: Slot] = [:]) {
    self.slots = slots
  }

  func load(_ path: String) throws -> AppleDocJSON {
    requested.append(path)
    if let slot = slots[path] {
      switch slot {
      case .page(let page):
        return page
      case .docs(let error):
        throw error
      case .probe(let message):
        throw ProbeError(message: message)
      }
    }
    throw AppleDocsError.documentationNotFound(url: Self.jsonURL(path), candidates: [])
  }

  func requestedPaths() -> [String] { requested }

  static func jsonURL(_ path: String) -> String {
    "https://developer.apple.com/tutorials/data/documentation/\(path).json"
  }
}
