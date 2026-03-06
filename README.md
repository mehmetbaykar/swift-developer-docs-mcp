# swift-developer-docs-mcp

<p align="center">
If you found this helpful, you can support more open source work!
<br><br>
<a href="https://buymeacoffee.com/mehmetbaykar" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" height="60"></a>
</p>

---

A tool that makes Apple Developer Documentation readable by AI tools and humans alike. Apple's docs are JavaScript-rendered and invisible to LLMs — this tool fetches the underlying JSON data and converts it to clean, structured Markdown with declarations, parameters, platform availability, topic sections, relationships, code examples, and see-also links.

Use it however you prefer:

| Mode | Best for |
|------|----------|
| **CLI** | Direct terminal use, scripting, piping output |
| **MCP Server** | Claude Code MCP integration (auto-available tools) |
| **Claude Code Skill** | Claude Code — just type `/apple-docs SwiftUI View` |

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

### CLI Tool

No MCP setup needed — use it directly from your terminal:

```bash
# Search for documentation
npx @mehmetbaykar/swift-developer-docs-mcp search "SwiftUI View"

# Fetch a specific documentation page as Markdown
npx @mehmetbaykar/swift-developer-docs-mcp fetch swift/array

# Show available commands
npx @mehmetbaykar/swift-developer-docs-mcp help
```

Two commands, that's it:

| Command | Description |
|---------|-------------|
| `search <query>` | Search Apple Developer docs by keyword. Returns titles, URLs, descriptions, breadcrumbs, and tags. |
| `fetch <path>` | Fetch a doc page by path (e.g. `swift/array`, `swiftui/view`) and return rendered Markdown. |

<details>
<summary>Using a local build</summary>

```bash
.build/debug/swift-developer-docs-mcp search "SwiftUI View"
.build/debug/swift-developer-docs-mcp fetch swift/array
```

</details>

<details>
<summary>Example: search output</summary>

```
Found 63 results for 'SwiftUI View':

1. **SwiftUI**
   URL: https://developer.apple.com/documentation/swiftui/
   Declare the user interface and behavior for your app on every platform.
   Path: SwiftUI > SwiftUI
   Tags: DOCUMENTATION, Swift

2. **Declaring a custom view**
   URL: https://developer.apple.com/documentation/swiftui/declaring-a-custom-view/
   Define views and assemble them into a view hierarchy.
   Tags: DOCUMENTATION ARTICLE, Swift

3. **View fundamentals**
   URL: https://developer.apple.com/documentation/swiftui/view-fundamentals/
   Define the visual elements of your app using a hierarchy of views.
   Tags: DOCUMENTATION ARTICLE, Swift
...
```

Results also include structured JSON for programmatic use. Result types include `DOCUMENTATION`, `DOCUMENTATION ARTICLE`, `SAMPLE CODE`, and `WWDC VIDEO`.

</details>

<details>
<summary>Example: fetch output</summary>

```markdown
---
title: Array
description: An ordered, random-access collection.
source: https://developer.apple.com/documentation/swift/array
timestamp: 2026-03-06T16:53:29.827Z
---

**Navigation:** [Swift](/documentation/swift)

**Structure**

# Array

**Available on:** iOS 8.0+, iPadOS 8.0+, macOS 10.10+, visionOS 1.0+, watchOS 2.0+

> An ordered, random-access collection.

@frozen struct Array<Element>

## Overview
Arrays are one of the most commonly used data types in an app...

## Conforms To
- BidirectionalCollection, Collection, Equatable, Hashable, Sendable...

## Creating an Array
- [init()] Creates a new, empty array.
- [init(repeating:count:)] Creates a new array containing the specified number of a single, repeated value.

## Accessing Elements
- [subscript(_:)] Accesses the element at the specified position.
- [first] The first element of the collection.

## Adding Elements
- [append(_:)] Adds a new element at the end of the array.
- [insert(_:at:)] Inserts a new element at the specified position.
...
```

The fetch output includes the full documentation: overview with Swift code examples, all topic sections (20+ categories for complex types), conformances, related types, and see-also links.

</details>

---

### MCP Server (Claude Code)

Add it as an MCP server in Claude Code and two tools become available automatically — `searchAppleDocumentation` and `fetchAppleDocumentation`:

```bash
claude mcp add apple-docs -- npx -y @mehmetbaykar/swift-developer-docs-mcp
```

Or add it to your `.claude/settings.json`:

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

```bash
claude mcp add apple-docs -- /absolute/path/to/.build/debug/swift-developer-docs-mcp
```

Or in `.claude/settings.json`:

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

Claude can then use the MCP tools directly when you ask things like:

- "Search for SwiftUI View documentation"
- "Fetch the docs for swift/array"
- "Show me the documentation for combine/publisher"

---

### Claude Code Skill

The `skills/apple-docs.md` file is a [Claude Code skill](https://docs.anthropic.com/en/docs/claude-code/skills) that gives Claude the ability to search and fetch Apple documentation on your behalf. When you invoke it, Claude will:

1. **Search** Apple's documentation for your query
2. **Pick** the most relevant result
3. **Fetch** the full documentation page
4. **Present** the rendered Markdown — declarations, parameters, platform availability, topic sections, conformances, and related links

#### Setup

Copy it to your personal skills directory (available across all projects):

```bash
mkdir -p ~/.claude/skills/apple-docs
cp skills/apple-docs.md ~/.claude/skills/apple-docs/SKILL.md
```

Or to your commands directory:

```bash
cp skills/apple-docs.md ~/.claude/commands/apple-docs.md
```

#### Use

```
/apple-docs SwiftUI View
/apple-docs swift/array
/apple-docs URLSession
```

The skill also activates automatically when Claude detects questions about Apple frameworks or APIs — no need to invoke it manually every time.

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
