import AppleDocsCore
import FastMCP
import Foundation

struct FetchAppleDocsTool: MCPTool {
    let name = "fetchAppleDocumentation"
    let description: String? = "Fetch Apple Developer documentation by path and return as markdown"

    @Schemable
    struct Parameters: Sendable {
        let path: String
    }

    func call(with args: Parameters) async throws(ToolError) -> Content {
        do {
            let normalized = URLUtilities.normalizeDocumentationPath(args.path)
            if normalized.isEmpty {
                throw ToolError("Invalid path. Expected format: swift/array")
            }

            let sourceURL = URLUtilities.generateAppleDocURL(normalized)
            let jsonData = try await Fetcher.fetchJSONData(path: normalized)
            let markdown = DocumentRenderer.renderFromJSON(jsonData, sourceURL: sourceURL)

            if markdown.count < DocumentRenderer.minContentLength {
                throw ToolError("Insufficient content returned for path: \(normalized)")
            }

            return [ToolContentItem(text: markdown)]
        } catch let error as ToolError {
            throw error
        } catch {
            throw ToolError("Failed to fetch documentation: \(error.localizedDescription)")
        }
    }
}
