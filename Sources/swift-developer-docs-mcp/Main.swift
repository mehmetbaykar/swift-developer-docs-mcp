import FastMCP

@main
struct AppleDocsServer {
    static func main() async throws {
        try await FastMCP.builder()
            .name("swift-developer-docs-mcp")
            .version("1.0.0")
            .addTools([
                SearchAppleDocsTool(),
                FetchAppleDocsTool(),
            ])
            .addResources([DocumentationResource()])
            .transport(.stdio)
            .shutdownSignals([.sigterm, .sigint])
            .run()
    }
}
