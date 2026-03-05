import AppleDocsCore
import FastMCP
import Foundation

struct DocumentationResource: MCPResource {
    let uri = "doc://apple-developer-docs"
    let name: String? = "Apple Developer Documentation"
    let description: String? = "Apple Developer documentation as Markdown"
    let mimeType: String? = "text/markdown"

    var content: Content {
        ResourceContentItem(
            text: "Use the fetchAppleDocumentation tool with a path parameter to fetch specific documentation pages.",
            mimeType: "text/markdown"
        )
    }
}
