# Architecture

## Overview

The project has two targets:

- **AppleDocsCore** — a pure Swift library with no MCP dependencies. Handles fetching, parsing, rendering, and shared action logic.
- **swift-developer-docs-mcp** — an executable that provides both a CLI interface and an MCP server, both backed by the same core library.

```
┌─────────────────────────────────┐    ┌──────────────────────┐
│    Claude Desktop / MCP Client  │    │    CLI / Shell        │
└──────────────┬──────────────────┘    └──────────┬───────────┘
               │ stdio (JSON-RPC)                 │ subcommands
┌──────────────▼──────────────────────────────────▼───────────┐
│                  swift-developer-docs-mcp                   │
│                                                             │
│   ┌───────────┐ ┌────────────┐   ┌───────────┐ ┌────────┐  │
│   │SearchTool │ │ FetchTool  │   │SearchCmd  │ │FetchCmd│  │
│   └─────┬─────┘ └─────┬──────┘   └─────┬─────┘ └───┬────┘  │
│         │              │                │            │       │
│         │         MCP Tools          Commands        │       │
│         │     (FastMCP wrappers)  (CLICommand)       │       │
└─────────┼──────────────┼────────────────┼────────────┼──────┘
          │              │                │            │
┌─────────▼──────────────▼────────────────▼────────────▼──────┐
│                     AppleDocsCore                           │
│                                                             │
│   ┌──────────────────────────────────────────────────────┐  │
│   │              AppleDocsActions                        │  │
│   │  .search(query:) → SearchOutput                     │  │
│   │  .fetch(path:)   → String (markdown)                │  │
│   └───────────┬──────────────────────┬───────────────────┘  │
│               │                      │                      │
│   ┌───────────▼──────┐    ┌─────────▼──────────────────┐   │
│   │    Search        │    │   Fetcher → Renderer       │   │
│   │ (HTML parsing)   │    │ (JSON fetch → Markdown)    │   │
│   └──────────────────┘    └────────────────────────────┘   │
│                                                             │
│   ┌─────────────────────────────────────────────────────┐   │
│   │           Types / URLUtilities                      │   │
│   └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Entry Point

`Main.swift` creates a `CLIRouter` and checks for subcommands. If a subcommand matches (`search`, `fetch`, `help`), it runs in CLI mode and exits. Otherwise, it starts the MCP server.

```
args present? ──yes──▶ CLIRouter ──▶ matched command ──▶ run & exit
      │
      no
      │
      ▼
  FastMCP server (stdio)
```

## Shared Action Layer

`AppleDocsActions` is the single source of truth for search and fetch logic. Both MCP tools and CLI commands delegate to it:

- `AppleDocsActions.search(query:)` — calls `AppleDocsSearcher.search()`, formats results, encodes JSON
- `AppleDocsActions.fetch(path:)` — normalizes path, fetches JSON, renders Markdown, validates content length

This eliminates duplication between the CLI and MCP interfaces. Adding a new interface (e.g., HTTP server) only requires writing thin wrappers around `AppleDocsActions`.

## CLI Layer

The CLI uses a simple protocol-based design:

- **`CLICommand`** — protocol with `name`, `usage`, and `run(arguments:)`
- **`CLIRouter`** — takes an array of commands, matches the first argument, dispatches
- **`SearchCommand`** / **`FetchCommand`** — thin wrappers that call `AppleDocsActions` and print to stdout

New CLI commands are added by conforming to `CLICommand` and registering in `CLIRouter`'s default array.

## Core Library Modules

### Types.swift

All Codable & Sendable types that map to Apple's documentation JSON API. The root type is `AppleDocJSON` which contains metadata, content sections, topic sections, references, and more.

Key design decisions:
- `ContentItem` is a flexible union type with many optional fields, used across content arrays, references, relationships, and variants
- `CodeValue` is an enum handling the JSON ambiguity where code can be either a single string or an array of strings
- `TextFragment` has optional `text` and recursive `inlineContent` to handle emphasis/strong fragments in abstracts

### URLUtilities.swift

Three static functions for path handling:
- `normalizeDocumentationPath` — strips leading slashes, `documentation/` prefix, and whitespace
- `generateAppleDocURL` — builds the full `https://developer.apple.com/documentation/` URL
- `isValidAppleDocURL` — validates a URL points to Apple's docs

### Fetcher.swift

Fetches Apple's JSON data API. The key insight is that Apple's documentation pages are JavaScript-rendered, but the underlying data is available at predictable JSON endpoints:

- Framework index: `https://developer.apple.com/tutorials/data/index/{framework}`
- Documentation page: `https://developer.apple.com/tutorials/data/documentation/{path}.json`

The fetcher rotates through 26 Safari user-agent strings to avoid detection.

### Search.swift

Fetches Apple's search page HTML and parses it with SwiftSoup. Extracts:
- Result title and URL from `a.click-analytics-result` elements
- Description from `p.result-description`
- Breadcrumbs from `li.breadcrumb-list-item`
- Tags from `li.result-tag`
- Result type (documentation/general/other) from CSS classes

### Renderer.swift

The largest module. Converts `AppleDocJSON` into Markdown with:

1. **Front matter** — YAML block with title, description, source URL, timestamp
2. **Breadcrumbs** — Navigation path links
3. **Metadata** — Role heading, title, platform availability
4. **Abstract** — Blockquote summary
5. **Declarations** — Swift code blocks from token arrays
6. **Parameters** — Formatted parameter list
7. **Content sections** — Recursive rendering of headings, paragraphs, code listings, lists, asides
8. **Relationships** — Conformances, inheritance
9. **Topics** — Grouped API members with abstracts
10. **Index content** — Framework-level member listings
11. **See also** — Related documentation links
12. **Footer** — Attribution

Recursion is depth-limited (content: 50, inline: 20) to prevent stack overflow on malformed data.

### Actions.swift

Shared action layer that both MCP tools and CLI commands call:

- `search(query:)` returns `SearchOutput` with formatted text and JSON string
- `fetch(path:)` returns rendered Markdown string
- `FetchError` provides typed errors for invalid paths and insufficient content

## MCP Layer

### SearchTool

Wraps `AppleDocsActions.search()`. Returns both formatted text and JSON as separate `ToolContentItem` entries.

### FetchTool

Wraps `AppleDocsActions.fetch()`. Returns the rendered Markdown as a single `ToolContentItem`.

### Both tools declare MCP annotations:
- `readOnlyHint: true` — no side effects
- `destructiveHint: false` — no mutations
- `idempotentHint: true` — same input = same output
- `openWorldHint: true` — accesses external Apple servers

## Dependencies

| Package | Purpose |
|---------|---------|
| [swift-fast-mcp](https://github.com/mehmetbaykar/swift-fast-mcp) | MCP server framework (stdio transport, tool/resource registration) |
| [SwiftSoup](https://github.com/scinfu/SwiftSoup) | HTML parsing for search results |
