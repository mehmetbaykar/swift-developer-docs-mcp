import Foundation
import Testing

@testable import AppleDocsCore

@Suite("HIG Path Resolver Tests")
struct HIGPathResolverTests {

  private func makeToc() -> HIGTableOfContents {
    HIGTableOfContents(
      includedArchiveIdentifiers: [],
      interfaceLanguages: HIGInterfaceLanguages(swift: [
        HIGTocItem(
          children: nil,
          path: "/design/human-interface-guidelines/color",
          title: "Color",
          type: "article"
        ),
        HIGTocItem(
          children: nil,
          path: "/design/human-interface-guidelines/typography",
          title: "Typography",
          type: "article"
        ),
        HIGTocItem(
          children: nil,
          path: "/design/human-interface-guidelines/buttons",
          title: "Buttons",
          type: "article"
        ),
      ]),
      references: [:],
      schemaVersion: SchemaVersion(major: 0, minor: 3, patch: 0)
    )
  }

  @Test("Does not resolve single-segment paths")
  func singleSegmentPath() {
    let toc = makeToc()
    let resolved = HIGPathResolver.resolveHigPathForFetch(path: "color", toc: toc)
    #expect(resolved == "color")
  }

  @Test("Resolves grouped path to top-level when unique match")
  func resolveGroupedPath() {
    let toc = makeToc()
    let resolved = HIGPathResolver.resolveHigPathForFetch(
      path: "foundations/color", toc: toc)
    #expect(resolved == "color")
  }

  @Test("Returns original path when leaf slug has no matches")
  func noMatches() {
    let toc = makeToc()
    let resolved = HIGPathResolver.resolveHigPathForFetch(
      path: "foundations/nonexistent", toc: toc)
    #expect(resolved == "foundations/nonexistent")
  }

  @Test("Returns original path when leaf slug matches multiple paths")
  func ambiguousMatches() {
    // Create a ToC with duplicate leaf slugs
    let toc = HIGTableOfContents(
      includedArchiveIdentifiers: [],
      interfaceLanguages: HIGInterfaceLanguages(swift: [
        HIGTocItem(
          children: nil,
          path: "/design/human-interface-guidelines/color",
          title: "Color",
          type: "article"
        ),
        HIGTocItem(
          children: [
            HIGTocItem(
              children: nil,
              path: "/design/human-interface-guidelines/patterns/color",
              title: "Color",
              type: "article"
            )
          ],
          path: "/design/human-interface-guidelines/patterns",
          title: "Patterns",
          type: "symbol"
        ),
      ]),
      references: [:],
      schemaVersion: SchemaVersion(major: 0, minor: 3, patch: 0)
    )

    let resolved = HIGPathResolver.resolveHigPathForFetch(
      path: "foundations/color", toc: toc)
    // Should return original because "color" matches two paths
    #expect(resolved == "foundations/color")
  }
}
