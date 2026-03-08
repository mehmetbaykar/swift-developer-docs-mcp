import Foundation
import Testing

@testable import AppleDocsCore

@Suite("HIG Fetcher Tests")
struct HIGFetcherTests {

  private func makeToc() -> HIGTableOfContents {
    HIGTableOfContents(
      includedArchiveIdentifiers: [],
      interfaceLanguages: HIGInterfaceLanguages(swift: [
        HIGTocItem(
          children: [
            HIGTocItem(
              path: "/design/human-interface-guidelines/color",
              title: "Color",
              type: "article"
            ),
            HIGTocItem(
              path: "/design/human-interface-guidelines/typography",
              title: "Typography",
              type: "article"
            ),
          ],
          path: "/design/human-interface-guidelines/foundations",
          title: "Foundations",
          type: "symbol"
        ),
        HIGTocItem(
          children: [
            HIGTocItem(
              path: "/design/human-interface-guidelines/buttons",
              title: "Buttons",
              type: "article"
            )
          ],
          path: "/design/human-interface-guidelines/components",
          title: "Components",
          type: "symbol"
        ),
        HIGTocItem(
          path: "/design/human-interface-guidelines/getting-started",
          title: "Getting Started",
          type: "article"
        ),
      ]),
      references: [:],
      schemaVersion: SchemaVersion(major: 0, minor: 3, patch: 0)
    )
  }

  @Test("extractHIGPaths returns all paths from ToC")
  func extractPaths() {
    let toc = makeToc()
    let paths = HIGFetcher.extractHIGPaths(toc: toc)

    #expect(paths.contains("color"))
    #expect(paths.contains("typography"))
    #expect(paths.contains("buttons"))
    #expect(paths.contains("getting-started"))
    #expect(paths.contains("foundations"))
    #expect(paths.contains("components"))
    #expect(paths.count == 6)
  }

  @Test("findHIGItemByPath finds item at top level")
  func findItemTopLevel() {
    let toc = makeToc()
    let item = HIGFetcher.findHIGItemByPath("getting-started", in: toc)

    #expect(item != nil)
    #expect(item?.title == "Getting Started")
  }

  @Test("findHIGItemByPath finds nested item")
  func findItemNested() {
    let toc = makeToc()
    let item = HIGFetcher.findHIGItemByPath("color", in: toc)

    #expect(item != nil)
    #expect(item?.title == "Color")
  }

  @Test("findHIGItemByPath returns nil for non-existent path")
  func findItemNotFound() {
    let toc = makeToc()
    let item = HIGFetcher.findHIGItemByPath("nonexistent", in: toc)

    #expect(item == nil)
  }

  @Test("getHIGBreadcrumbs returns breadcrumb path")
  func breadcrumbs() {
    let toc = makeToc()
    let breadcrumbs = HIGFetcher.getHIGBreadcrumbs(for: "color", in: toc)

    #expect(breadcrumbs == ["Foundations", "Color"])
  }

  @Test("getHIGBreadcrumbs for top-level item")
  func breadcrumbsTopLevel() {
    let toc = makeToc()
    let breadcrumbs = HIGFetcher.getHIGBreadcrumbs(for: "getting-started", in: toc)

    #expect(breadcrumbs == ["Getting Started"])
  }

  @Test("getHIGBreadcrumbs returns empty for non-existent path")
  func breadcrumbsNotFound() {
    let toc = makeToc()
    let breadcrumbs = HIGFetcher.getHIGBreadcrumbs(for: "nonexistent", in: toc)

    #expect(breadcrumbs.isEmpty)
  }
}
