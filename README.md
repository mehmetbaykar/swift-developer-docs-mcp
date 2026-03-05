# swift-developer-docs-mcp

A Swift MCP (Model Context Protocol) server that makes Apple Developer Documentation readable by AI tools like Claude. Apple's docs are JavaScript-rendered and invisible to LLMs — this server fetches the underlying JSON data and converts it to clean Markdown.

Built as a native Swift CLI tool that communicates over stdio, designed for local use with Claude Desktop.

## Features

- **Search** Apple Developer Documentation by keyword
- **Fetch** any documentation page and get back structured Markdown
- Renders declarations, parameters, topics, relationships, see-also sections, and more
- Rotates through 26 user-agent strings to avoid rate limiting
- Full platform availability info, breadcrumb navigation, and code blocks

## Requirements

- macOS 14+
- Swift 6.0+

## Build

```bash
swift build
```

## Usage with Claude Desktop

Build the project, then add to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "apple-docs": {
      "command": "/absolute/path/to/.build/debug/swift-developer-docs-mcp"
    }
  }
}
```

Restart Claude Desktop. You can then ask Claude things like:

- "Search for SwiftUI View documentation"
- "Fetch the docs for swift/array"
- "Show me the documentation for combine/publisher"

## MCP Tools

| Tool | Description |
|------|-------------|
| `searchAppleDocumentation` | Search Apple Developer docs by keyword. Returns titles, URLs, descriptions, breadcrumbs, and tags. |
| `fetchAppleDocumentation` | Fetch a documentation page by path (e.g. `swift/array`, `swiftui/view`) and return rendered Markdown. |

## Project Structure

```
Sources/
  AppleDocsCore/          # Core library (no MCP dependency)
    Types.swift           # Codable types for Apple's JSON API
    URLUtilities.swift    # Path normalization and URL generation
    Fetcher.swift         # HTTP fetching with user-agent rotation
    Search.swift          # HTML search result parsing (SwiftSoup)
    Renderer.swift        # JSON-to-Markdown rendering engine
  swift-developer-docs-mcp/  # MCP executable
    Main.swift            # Entry point, FastMCP server setup
    Tools/                # MCP tool definitions
    Resources/            # MCP resource definitions
Tests/
  AppleDocsCoreTests/     # 56 tests covering URL, rendering, and integration
    Fixtures/             # Real Apple documentation JSON for testing
```

See [docs/architecture.md](docs/architecture.md) for detailed architecture documentation.

## Testing

```bash
swift test
```

56 tests covering URL utilities, Markdown rendering, and full integration with real Apple documentation fixtures.

## Acknowledgments

This project is a Swift port of [sosumi.ai](https://github.com/kanaa257/sosumi.ai) by [NSHipster](https://nshipster.com), originally built in TypeScript as a Cloudflare Worker with SSE transport. The core logic — JSON fetching, search parsing, and Markdown rendering — has been ported to Swift with the transport changed to stdio for local CLI use.

The original project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Disclaimer

This is unofficial software. All Apple documentation content belongs to Apple Inc. This tool simply makes that content accessible to AI tools in a readable format.
