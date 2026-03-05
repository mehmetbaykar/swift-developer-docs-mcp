import AppleDocsCore
import FastMCP
import Foundation

struct SearchAppleDocsTool: MCPTool {
    let name = "searchAppleDocumentation"
    let description: String? = "Search Apple Developer documentation and return structured results"

    var annotations: Tool.Annotations {
        Tool.Annotations(
            title: "Search Apple Documentation",
            readOnlyHint: true,
            destructiveHint: false,
            idempotentHint: true,
            openWorldHint: true
        )
    }

    @Schemable
    struct Parameters: Sendable {
        let query: String
    }

    func call(with args: Parameters) async throws(ToolError) -> Content {
        do {
            let response = try await AppleDocsSearcher.search(query: args.query)

            if response.results.isEmpty {
                return [ToolContentItem(text: "No results found for '\(args.query)'")]
            }

            var text = "Found \(response.results.count) results for '\(args.query)':\n\n"
            for (i, result) in response.results.enumerated() {
                text += "\(i + 1). **\(result.title)**\n"
                text += "   URL: \(result.url)\n"
                if !result.description.isEmpty {
                    text += "   \(result.description)\n"
                }
                if !result.breadcrumbs.isEmpty {
                    text += "   Path: \(result.breadcrumbs.joined(separator: " > "))\n"
                }
                if !result.tags.isEmpty {
                    text += "   Tags: \(result.tags.joined(separator: ", "))\n"
                }
                text += "\n"
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(response)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""

            return [
                ToolContentItem(text: text),
                ToolContentItem(text: jsonString),
            ]
        } catch {
            throw ToolError("Search failed: \(error.localizedDescription)")
        }
    }
}
