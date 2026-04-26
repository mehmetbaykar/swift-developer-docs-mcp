// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "swift-developer-docs-mcp",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "AppleDocsCore", targets: ["AppleDocsCore"]),
    .executable(name: "swift-developer-docs-mcp", targets: ["swift-developer-docs-mcp"]),
  ],
  dependencies: [
    .package(url: "https://github.com/mehmetbaykar/swift-fast-mcp", from: "2.3.0"),
    .package(url: "https://github.com/scinfu/SwiftSoup", from: "2.7.0"),
    .package(url: "https://github.com/hummingbird-project/hummingbird", from: "2.0.0"),
  ],
  targets: [
    .target(
      name: "AppleDocsCore",
      dependencies: ["SwiftSoup"]
    ),
    .executableTarget(
      name: "swift-developer-docs-mcp",
      dependencies: [
        "AppleDocsCore",
        .product(name: "FastMCP", package: "swift-fast-mcp"),
        .product(name: "Hummingbird", package: "hummingbird"),
      ],
      exclude: ["Resources/llms.txt"]
    ),
    .testTarget(
      name: "AppleDocsCoreTests",
      dependencies: ["AppleDocsCore"],
      resources: [.copy("Fixtures")]
    ),
    .testTarget(
      name: "SwiftDeveloperDocsMCPTests",
      dependencies: [
        "swift-developer-docs-mcp",
        .product(name: "Hummingbird", package: "hummingbird"),
        .product(name: "HummingbirdTesting", package: "hummingbird"),
      ]
    ),
  ]
)
