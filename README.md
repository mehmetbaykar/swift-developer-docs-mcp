# swift-developer-docs-mcp

<p align="center">
If you found this helpful, you can support more open source work!
<br><br>
<a href="https://buymeacoffee.com/mehmetbaykar" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" height="60"></a>
</p>

---

A Swift MCP (Model Context Protocol) server that makes Apple Developer Documentation readable by AI tools like Claude. Apple's docs are JavaScript-rendered and invisible to LLMs — this server fetches the underlying JSON data and converts it to clean Markdown.

Works in two modes: as a **CLI tool** for direct use and Claude Code skills, or as an **MCP server** for Claude Desktop.

## Features

- **Search** Apple Developer Documentation by keyword
- **Fetch** any documentation page and get back structured Markdown
- Renders declarations, parameters, topics, relationships, see-also sections, and more
- Rotates through 26 user-agent strings to avoid rate limiting
- Full platform availability info, breadcrumb navigation, and code blocks

## Installation

### Via npm (recommended)

No build step required — prebuilt binaries for macOS (Apple Silicon) and Linux (x64):

```bash
# Run directly
npx @mehmetbaykar/swift-developer-docs-mcp help

# Or install globally
npm install -g @mehmetbaykar/swift-developer-docs-mcp
swift-developer-docs-mcp help
```

### Build from source

Requires macOS 14+ and Swift 6.0+:

```bash
git clone https://github.com/mehmetbaykar/swift-developer-docs-mcp.git
cd swift-developer-docs-mcp
swift build
```

## Requirements

- **npm install**: Node.js 20+
- **Build from source**: macOS 14+, Swift 6.0+

## Usage

### CLI Mode

```bash
# Search for documentation
npx @mehmetbaykar/swift-developer-docs-mcp search "SwiftUI View"

# Fetch a specific documentation page as Markdown
npx @mehmetbaykar/swift-developer-docs-mcp fetch swift/array

# Show available commands
npx @mehmetbaykar/swift-developer-docs-mcp help
```

<details>
<summary>Using a local build</summary>

```bash
.build/debug/swift-developer-docs-mcp search "SwiftUI View"
.build/debug/swift-developer-docs-mcp fetch swift/array
.build/debug/swift-developer-docs-mcp help
```

</details>

### MCP Server Mode (Claude Desktop)

Add to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "apple-docs": {
      "command": "npx",
      "args": ["-y", "@mehmetbaykar/swift-developer-docs-mcp"]
    }
  }
}
```

<details>
<summary>Using a local build</summary>

```json
{
  "mcpServers": {
    "apple-docs": {
      "command": "/absolute/path/to/.build/debug/swift-developer-docs-mcp"
    }
  }
}
```

</details>

Restart Claude Desktop. You can then ask Claude things like:

- "Search for SwiftUI View documentation"
- "Fetch the docs for swift/array"
- "Show me the documentation for combine/publisher"

### Claude Code Skill

Copy `apple-docs.md` into `~/.claude/commands/` to use it as a Claude Code skill:

```
/apple-docs SwiftUI View
```

The skill calls the CLI binary under the hood — search first, then fetch if a specific page is found.

## MCP Tools

| Tool | Description |
|------|-------------|
| `searchAppleDocumentation` | Search Apple Developer docs by keyword. Returns titles, URLs, descriptions, breadcrumbs, and tags. |
| `fetchAppleDocumentation` | Fetch a documentation page by path (e.g. `swift/array`, `swiftui/view`) and return rendered Markdown. |

## Development

### Project Structure

```
Sources/
  AppleDocsCore/              # Core library (no MCP dependency)
    Types.swift               # Codable types for Apple's JSON API
    URLUtilities.swift        # Path normalization and URL generation
    Fetcher.swift             # HTTP fetching with user-agent rotation
    Search.swift              # HTML search result parsing (SwiftSoup)
    Renderer.swift            # JSON-to-Markdown rendering engine
    Actions.swift             # Shared search/fetch logic (single source of truth)
  swift-developer-docs-mcp/   # Executable (CLI + MCP server)
    Main.swift                # Entry point, routes CLI vs MCP server
    Commands/                 # CLI subcommands
      CLICommand.swift        # Command protocol
      CLIRouter.swift         # Argument routing
      SearchCommand.swift     # `search` subcommand
      FetchCommand.swift      # `fetch` subcommand
    Tools/                    # MCP tool definitions
    Resources/                # MCP resource definitions
Tests/
  AppleDocsCoreTests/         # 56 tests covering URL, rendering, and integration
    Fixtures/                 # Real Apple documentation JSON for testing
```

See [docs/architecture.md](docs/architecture.md) for detailed architecture documentation.

### Testing

```bash
swift test
```

56 tests covering URL utilities, Markdown rendering, and full integration with real Apple documentation fixtures.

## Acknowledgments

This project is a Swift port of [sosumi.ai](https://github.com/kanaa257/sosumi.ai) by [NSHipster](https://nshipster.com), originally built in TypeScript as a Cloudflare Worker with SSE transport. The core logic — JSON fetching, search parsing, and Markdown rendering — has been ported to Swift with the transport changed to stdio for local CLI use.

The original project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Disclaimer

This is unofficial software. All Apple documentation content belongs to Apple Inc. This tool simply makes that content accessible to AI tools in a readable format.
