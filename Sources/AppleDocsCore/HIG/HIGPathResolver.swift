import Foundation

public struct HIGPathResolver: Sendable {

  /// Resolve a potentially outdated HIG path by matching the leaf slug against
  /// the live table of contents. HIG moved many topics from grouped paths
  /// (e.g. "foundations/color" -> "color"). When the leaf slug uniquely matches
  /// a single path in the ToC, use that resolved path instead.
  public static func resolveHigPathForFetch(
    path: String, toc: HIGTableOfContents
  ) -> String {
    // If there's no slash, it's already a top-level slug — no resolution needed
    guard path.contains("/") else { return path }

    // Extract the leaf slug (last non-empty component)
    let components = path.split(separator: "/").filter { !$0.isEmpty }
    guard let leaf = components.last.map(String.init) else { return path }

    // Search all available paths for a unique match
    let allPaths = HIGFetcher.extractHIGPaths(toc: toc)
    let matches = allPaths.filter { p in
      p == leaf || p.hasSuffix("/\(leaf)")
    }

    // Only resolve if there's exactly one match (unambiguous)
    return matches.count == 1 ? matches[0] : path
  }
}
