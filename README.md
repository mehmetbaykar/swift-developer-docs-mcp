# swift-developer-docs-mcp

<p align="center">
If you found this helpful, you can support more open source work!
<br><br>
<a href="https://buymeacoffee.com/mehmetbaykar" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" height="60"></a>
</p>

---

A tool that makes Apple Developer Documentation readable by AI tools and humans alike. Apple's docs are JavaScript-rendered and invisible to LLMs — this tool fetches the underlying JSON data and converts it to clean, structured Markdown with declarations, parameters, platform availability, topic sections, relationships, code examples, and see-also links.

Supports **reference docs**, **Human Interface Guidelines**, **WWDC video transcripts**, and **external Swift-DocC sites** — all with full SSRF protection.

Use it however you prefer:

| Mode | Best for |
|------|----------|
| **CLI** | Direct terminal use, scripting, piping output |
| **MCP Server** | Claude Code MCP integration (auto-available tools) |
| **HTTP Server** | REST API for web clients and integrations |
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

Requires macOS 14+ and Swift 6.2+:

```bash
git clone https://github.com/mehmetbaykar/swift-developer-docs-mcp.git
cd swift-developer-docs-mcp
swift build
```

## Requirements

- **npm install**: Node.js 20+
- **Build from source**: macOS 14+, Swift 6.2+

## Usage

### CLI Tool

No MCP setup needed — use it directly from your terminal:

```bash
# Search for documentation
npx @mehmetbaykar/swift-developer-docs-mcp search "SwiftUI View"

# Fetch a specific documentation page as Markdown
npx @mehmetbaykar/swift-developer-docs-mcp fetch swift/array

# Fetch Human Interface Guidelines
npx @mehmetbaykar/swift-developer-docs-mcp hig foundations/color

# Fetch a WWDC video transcript
npx @mehmetbaykar/swift-developer-docs-mcp video videos/play/wwdc2024/10133

# Fetch external Swift-DocC documentation
npx @mehmetbaykar/swift-developer-docs-mcp external https://swiftlang.github.io/swift-docc-plugin/documentation/swiftdoccplugin

# Start the HTTP server
npx @mehmetbaykar/swift-developer-docs-mcp serve --port 8080

# Show available commands
npx @mehmetbaykar/swift-developer-docs-mcp help
```

| Command | Description |
|---------|-------------|
| `search <query>` | Search Apple Developer docs. Each result has a title, URL, description, breadcrumbs, tags, and type. A failed search is an error. |
| `fetch <path-or-url>` | Fetch any doc type — auto-routes based on path (reference docs, HIG, video, external). |
| `hig [path]` | Fetch Human Interface Guidelines. No path = table of contents. |
| `video <path>` | Fetch WWDC video transcript (e.g., `videos/play/wwdc2024/10133`). |
| `external <url>` | Fetch external Swift-DocC documentation by URL. |
| `serve [--port N]` | Start HTTP server (default: port 8080). |

All commands support `--json` for JSON output. When a command fails, it prints one line `swift-developer-docs-mcp: <message>` to standard error and exits with status 1. `fetch --json` puts the URL of the resolved page in `url`.

Search posts to `https://devintserv.msc.sbz.apple.com/api/v1/query` and reads the JSONL answer (`Sources/AppleDocsCore/Search/SearchParser.swift`). A request or payload failure is an error. A successful search with no matches is an empty result list.

Apple's paths for functions, methods, and overloaded symbols include a signature or a disambiguation suffix. When a requested page does not exist, the fetcher looks for the symbol in the references of the parent page (`Sources/AppleDocsCore/Reference/DocumentationPageResolver.swift`). Exactly one match returns that page: `uniformtypeidentifiers/uttype/markdown` opens `uniformtypeidentifiers/uttype-swift.struct/markdown`. More than one match is an error that lists the candidate paths: `swiftui/view/body` lists `body-swift.associatedtype` and `body-8kl5o`. A slash at the end of a path is removed. Framework pages such as `/documentation/swiftui` come from the page JSON. HIG pages render the content of each tab in a tabbed section, and the table of contents lists every section.

<details>
<summary>Using a local build</summary>

```bash
.build/debug/swift-developer-docs-mcp search "SwiftUI View"
.build/debug/swift-developer-docs-mcp fetch swift/array
.build/debug/swift-developer-docs-mcp hig foundations/color
.build/debug/swift-developer-docs-mcp video videos/play/wwdc2024/10133
.build/debug/swift-developer-docs-mcp serve
```

</details>

<details>
<summary>Example: search output</summary>

```
Found 6 result(s) for "SwiftUI View":

1. View
   https://developer.apple.com/documentation/swiftui/view
   A type that represents part of your app’s user interface and provides modifiers that you use to configure views.

2. ViewDimensions
   https://developer.apple.com/documentation/swiftui/viewdimensions
   A view’s size and alignment guides in its own coordinate space.

3. ViewModifier
   https://developer.apple.com/documentation/swiftui/viewmodifier
   A modifier that you apply to a view or another view modifier, producing a different version of the original value.
...
```

The text lists the title, URL, and description. `search --json` also includes breadcrumbs, tags, and type.

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

The fetch output includes the full documentation: overview with Swift code examples, topic sections, conformances, related types, and see-also links. Abstracts keep code spans and links. Symbol link titles are in backticks. Relationship, topic, and see-also items show conditions such as "Conforms when `Element` conforms to `Equatable`." A page that documents an Objective-C symbol includes a note that links the Swift version. Nested lists are indented.

</details>

---

### HTTP Server

Start a REST API server for web clients and integrations:

```bash
npx @mehmetbaykar/swift-developer-docs-mcp serve --port 8080
```

| Route | Description |
|-------|-------------|
| `GET /` | HTML landing page, or `llms.txt` when `Accept: text/markdown` |
| `GET /search?q=...` | Search documentation |
| `GET /documentation/{path}` | Reference documentation |
| `GET /design/human-interface-guidelines` | HIG table of contents. The contents list every section. |
| `GET /design/human-interface-guidelines/{path}` | HIG pages. Each tab of a tabbed section is rendered, including the Dynamic Type size tables on the Typography page. |
| `GET /videos/play/{collection}/{id}` | Video transcripts |
| `GET /external/{full-https-url}` | External DocC documentation |

Documentation endpoints return `text/markdown` by default. Set `Accept: application/json` for JSON. Responses include `ETag`, `Cache-Control`, and `Content-Location` headers. `GET /documentation/{path}` sets `Content-Location` to the URL of the resolved page. A missing page returns status 404. When more than one symbol matches, the Markdown answer has a `## Did you mean:` list and the JSON answer has a `candidates` array of objects with `title` and `path`. `GET /` returns HTML unless `Accept: text/markdown` is sent. Run the binary without a subcommand to start the MCP server over stdio.

---

### MCP Server

Add it as an MCP server and four tools become available automatically — `searchAppleDocumentation`, `fetchAppleDocumentation`, `fetchExternalDocumentation`, and `fetchAppleVideoTranscript`.

#### Claude Code

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
<summary>Using a local build in Claude Code</summary>

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

#### Codex

Add it to Codex with the verified local CLI syntax:

```bash
codex mcp add apple-docs -- npx -y @mehmetbaykar/swift-developer-docs-mcp
```

Use a local build instead of `npx`:

```bash
codex mcp add apple-docs -- /absolute/path/to/.build/debug/swift-developer-docs-mcp
```

Codex config file examples (`~/.codex/config.toml` or `.codex/config.toml`):

```toml
[mcp_servers.apple-docs]
command = "npx"
args = ["-y", "@mehmetbaykar/swift-developer-docs-mcp"]
```

#### Cursor

Cursor uses `~/.cursor/mcp.json` or project-local `.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "apple-docs": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@mehmetbaykar/swift-developer-docs-mcp"]
    }
  }
}
```

Helpful Codex commands:

```bash
codex mcp list
codex mcp get apple-docs
```

Claude Code, Codex, and Cursor can then use the MCP tools directly when you ask things like:

- "Search for SwiftUI View documentation"
- "Fetch the docs for swift/array"
- "Show me the documentation for combine/publisher"
- "Fetch the HIG page for color"
- "Get the WWDC 2024 video transcript for session 10133"
- "Fetch the Swift-DocC Plugin documentation"

With `swift-fast-mcp` 2.7.0, tools are authored with the macro-based FastMCP API. `searchAppleDocumentation` returns a typed structured JSON payload containing the query and matching results. The three fetch tools return plain Markdown text. `fetchAppleDocumentation` puts a text block before the Markdown when the page is at another path than the requested path: `No page exists at /documentation/<requested>. This is the page at /documentation/<resolved>.` A failure is a tool error (`isError`). The server instructions say that conformance conditions in Apple's data can be missing or wrong.

---

### Claude Code Skill

The repo includes one Claude Code skill file at `skills/apple-docs.md`. It gives Claude the ability to search and fetch Apple documentation on your behalf. When you invoke the skill, Claude will:

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
  AppleDocsCore/                # Core library (no MCP dependency)
    Shared/
      Types.swift               # Codable types (ContentItem, AppleDocJSON, etc.)
      AppleDocsError.swift      # Unified error enum (11 cases)
      VariantTypes.swift        # LanguageVariant, ImageVariant, SymbolVariant
      Fetcher.swift             # Injectable HTTP client with UA rotation
      ContentRenderer.swift     # Shared rendering (inline, blocks, tables, asides)
      MarkdownFormatting.swift  # Shared list, code block, table, and callout formatting
      RenderingContext.swift    # Injectable rendering closures
      RenderConfig.swift        # Rendering state (basePath, isExternal, etc.)
      URLUtilities.swift        # Path normalization, URL generation
    Reference/
      ReferenceRenderer.swift   # Reference doc → Markdown
      ReferenceFetcher.swift    # Injectable reference doc fetching
      DocumentationPageResolver.swift  # Path resolution for missing symbol pages
    Search/
      SearchParser.swift        # JSONL search client; HTML parser is unused by live search
      SearchClient.swift        # Injectable search struct
      SearchTypes.swift         # SearchResult, SearchOptions
    HIG/
      HIGTypes.swift            # HIGPageJSON, HIGTableOfContents, etc.
      HIGFetcher.swift          # ToC + page data fetching
      HIGRenderer.swift         # HIG Markdown rendering
      HIGPathResolver.swift     # Moved-topic path resolution
    Video/
      VideoTranscript.swift     # HTML fetch, transcript extraction, MM:SS timestamps
    External/
      ExternalPolicy.swift      # SSRF protection (IP blocking, allowlist/blocklist)
      RobotsPolicy.swift        # robots.txt caching, X-Robots-Tag
      ExternalFetcher.swift     # External DocC JSON fetching
      ExternalRenderer.swift    # External doc rendering with path rewriting
    AppleDocsClient.swift       # Injectable actions struct with unified routing
  swift-developer-docs-mcp/     # Executable (CLI + MCP + HTTP server)
    Main.swift                  # Entry point: CLI → MCP → serve
    AppleDocsMCPServer.swift    # MCP server metadata and tool registration
    Commands/
      CLICommand.swift          # Command protocol
      CLIRouter.swift           # Subcommand dispatch
      CLIArgParser.swift        # --json flag parsing
      SearchCommand.swift       # search <query>
      FetchCommand.swift        # fetch <path-or-url>
      HIGCommand.swift          # hig [path]
      VideoCommand.swift        # video <path>
      ExternalCommand.swift     # external <url>
      ServeCommand.swift        # serve [--port N]
    Tools/
      SearchTool.swift          # searchAppleDocumentation
      FetchDocumentationTool.swift  # fetchAppleDocumentation
      FetchExternalDocTool.swift    # fetchExternalDocumentation
      FetchVideoTranscriptTool.swift # fetchAppleVideoTranscript
      ToolExecutionError.swift  # Failure raised as an MCP tool error
    Server/
      ServerApp.swift           # Hummingbird routes + llms.txt
      SecurityHeadersMiddleware.swift
      CORSMiddleware.swift
      TrailingSlashMiddleware.swift
    Resources/
      llms.txt
Tests/
  AppleDocsCoreTests/
    CLI/
    Client/
    External/
    Fixtures/                   # Real Apple documentation JSON for testing
    HIG/
    Integration/
    MCP/
    Reference/
    Search/
    Shared/
    Snapshots/
    Video/
  SwiftDeveloperDocsMCPTests/
```

See [docs/architecture.md](docs/architecture.md) for detailed architecture documentation.

### Testing

```bash
swift test
```

The test suite covers URL utilities, content rendering, search parsing and formatting, HIG (fetcher, renderer, path resolver, types), video transcripts, external docs (SSRF policy, robots.txt, fetcher, renderer), client routing, error handling, concurrency, user agent rotation, MCP tool logic, CLI parsing, integration, and snapshot tests.

## Dependencies

| Package | Purpose |
|---------|---------|
| [swift-fast-mcp](https://github.com/mehmetbaykar/swift-fast-mcp) | MCP server framework (stdio transport, tool/resource registration) |
| [SwiftSoup](https://github.com/scinfu/SwiftSoup) | HTML parsing for video transcripts. `SearchParser.swift` still contains an HTML parser; live search does not use it. |
| [Hummingbird](https://github.com/hummingbird-project/hummingbird) | HTTP server framework |

## Acknowledgments

This project is a Swift port of [sosumi.ai](https://github.com/NSHipster/sosumi.ai) by [NSHipster](https://nshipster.com), originally built in TypeScript as a Cloudflare Worker with SSE transport. The core logic — JSON fetching, search parsing, Markdown rendering, HIG support, video transcript extraction, and external documentation with SSRF protection — has been ported to Swift with full feature parity.

The original project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Disclaimer

This is unofficial software. All Apple documentation content belongs to Apple Inc. This tool simply makes that content accessible to AI tools in a readable format.
