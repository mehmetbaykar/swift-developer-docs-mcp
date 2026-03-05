// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "swift-developer-docs-mcp",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AppleDocsCore", targets: ["AppleDocsCore"]),
        .executable(name: "swift-developer-docs-mcp", targets: ["swift-developer-docs-mcp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/mehmetbaykar/swift-fast-mcp", from: "1.0.2"),
        .package(url: "https://github.com/scinfu/SwiftSoup", from: "2.7.0"),
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
            ]
        ),
        .testTarget(
            name: "AppleDocsCoreTests",
            dependencies: ["AppleDocsCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
