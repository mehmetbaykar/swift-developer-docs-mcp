# Architecture

## Overview

The project has two targets:

- **AppleDocsCore** — a pure Swift library with no MCP dependencies. Handles fetching, parsing, and rendering Apple documentation.
- **swift-developer-docs-mcp** — a thin executable that wires the core library into an MCP server using FastMCP.

```
┌─────────────────────────────────┐
│    Claude Desktop / MCP Client  │
└──────────────┬──────────────────┘
               │ stdio (JSON-RPC)
┌──────────────▼──────────────────┐
│   swift-developer-docs-mcp     │
│   (FastMCP server)              │
│   ┌───────────┐ ┌────────────┐ │
│   │SearchTool │ │ FetchTool  │ │
│   └─────┬─────┘ └─────┬──────┘ │
└─────────┼──────────────┼────────┘
          │              │
┌─────────▼──────────────▼────────┐
│       AppleDocsCore             │
│  ┌─────────┐  ┌──────────────┐  │
│  │ Search  │  │   Fetcher    │  │
│  └────┬────┘  └──────┬───────┘  │
│       │              │          │
│       │       ┌──────▼───────┐  │
│       │       │  Renderer    │  │
│       │       └──────────────┘  │
│  ┌────▼──────────────────────┐  │
│  │  Types / URLUtilities     │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

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

## MCP Layer

### SearchTool

Wraps `AppleDocsSearcher.search()`. Returns human-readable formatted text plus JSON-encoded structured data.

### FetchTool

Wraps the fetch-and-render pipeline: normalize path, fetch JSON, render to Markdown, validate minimum content length.

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
