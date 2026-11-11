# Architecture

## Overview

The project has two targets:

- **AppleDocsCore** — a pure Swift library with no MCP dependencies. Handles fetching, parsing, rendering, and shared action logic for reference docs, HIG, video transcripts, and external documentation.
- **swift-developer-docs-mcp** — an executable that provides a CLI interface, an MCP server, and an HTTP server (Hummingbird), all backed by the same core library.

```
┌─────────────────────────────┐  ┌──────────────┐  ┌──────────────┐
│  Claude Desktop / MCP Client│  │  CLI / Shell  │  │ HTTP Clients │
└──────────────┬──────────────┘  └──────┬───────┘  └──────┬───────┘
               │ stdio (JSON-RPC)       │ subcommands     │ REST
┌──────────────▼────────────────────────▼─────────────────▼───────┐
│                    swift-developer-docs-mcp                     │
│                                                                 │
│  ┌─────────────────────┐  ┌─────────────────┐  ┌────────────┐  │
│  │     MCP Tools (4)   │  │  Commands (6)   │  │ HTTP Server│  │
│  │ SearchAppleDocs     │  │ search          │  │ Hummingbird│  │
│  │ FetchAppleDocs      │  │ fetch           │  │ /docs/*    │  │
│  │ FetchExternalDoc    │  │ hig             │  │ /search    │  │
│  │ FetchVideoTranscript│  │ video           │  │ /hig/*     │  │
│  └─────────┬───────────┘  │ external        │  │ /videos/*  │  │
│            │              │ serve           │  │ /external/*│  │
│            │              └────────┬────────┘  └─────┬──────┘  │
│            │                       │                  │         │
│  ┌─────────▼───────────────────────▼──────────────────▼──────┐  │
│  │              Middleware Stack                              │  │
│  │  TrailingSlash → SecurityHeaders → CORS                   │  │
│  └───────────────────────────────────────────────────────────┘  │
└────────────────────────────────┬────────────────────────────────┘
                                 │
┌────────────────────────────────▼────────────────────────────────┐
│                        AppleDocsCore                            │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              AppleDocsClient (injectable struct)          │   │
│  │  .fetch(path:)          → String (markdown)              │   │
│  │  .search(query:)        → SearchOutput                   │   │
│  │  .fetchHIG(path:)       → String (markdown)              │   │
│  │  .fetchHIGTableOfContents() → String (markdown)          │   │
│  │  .fetchVideo(path:)     → String (markdown)              │   │
│  │  .fetchExternal(url:)   → String (markdown)              │   │
│  │  .unifiedFetch(input:)  → String (auto-routes by path)   │   │
│  └────────┬──────────┬──────────┬──────────┬────────────────┘   │
│           │          │          │          │                     │
│  ┌────────▼───┐ ┌────▼────┐ ┌──▼───┐ ┌───▼──────────────────┐  │
│  │ Reference  │ │  Search │ │ HIG  │ │ Video │ External     │  │
│  │            │ │         │ │      │ │       │              │  │
│  │ Renderer   │ │ Parser  │ │Fetch │ │Trans- │ Policy       │  │
│  │ Fetcher    │ │ Client  │ │Render│ │cript  │ Robots       │  │
│  │ Resolver   │ │ Types   │ │Resolv│ │       │ Fetcher      │  │
│  └────────────┘ └─────────┘ │Types │ │       │ Renderer     │  │
│                              └──────┘ └───────┴──────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    Shared                                │   │
│  │  Types, Fetcher, ContentRenderer, MarkdownFormatting,    │   │
│  │  RenderingContext, RenderConfig, AppleDocsError,         │   │
│  │  VariantTypes, URLUtils                                  │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Project Structure

```
Sources/AppleDocsCore/
├── Shared/
│   ├── Types.swift              — Codable types (ContentItem, AppleDocJSON, etc.)
│   ├── AppleDocsError.swift     — Unified error enum (11 cases)
│   ├── VariantTypes.swift       — LanguageVariant, ImageVariant, SymbolVariant
│   ├── Fetcher.swift            — Injectable HTTP client with UA rotation
│   ├── ContentRenderer.swift    — Shared rendering (inline, blocks, tables, asides)
│   ├── MarkdownFormatting.swift — Shared list, code block, table, and callout formatting
│   ├── RenderingContext.swift   — Injectable rendering closures
│   ├── RenderConfig.swift       — Rendering state (basePath, isExternal, etc.)
│   └── URLUtilities.swift       — Path normalization, URL generation
├── Reference/
│   ├── ReferenceRenderer.swift  — Reference doc → Markdown
│   ├── ReferenceFetcher.swift   — Injectable reference doc fetching
│   └── DocumentationPageResolver.swift — Path resolution for missing symbol pages
├── Search/
│   ├── SearchParser.swift       — Apple search JSONL client + result normalization
│   ├── SearchClient.swift       — Injectable search struct
│   └── SearchTypes.swift        — SearchResult, SearchOptions
├── HIG/
│   ├── HIGTypes.swift           — HIGPageJSON, HIGTableOfContents, etc.
│   ├── HIGFetcher.swift         — ToC fetch, page fetch, path extraction
│   ├── HIGRenderer.swift        — HIG page + ToC Markdown rendering
│   └── HIGPathResolver.swift    — Moved-topic path resolution
├── Video/
│   └── VideoTranscript.swift    — HTML fetch, transcript extraction, MM:SS
├── External/
│   ├── ExternalPolicy.swift     — SSRF protection (IP blocking, allowlist/blocklist)
│   ├── RobotsPolicy.swift       — robots.txt caching, X-Robots-Tag
│   ├── ExternalFetcher.swift    — External DocC JSON fetching
│   └── ExternalRenderer.swift   — External doc rendering with path rewriting
└── AppleDocsClient.swift        — Injectable actions struct with unified routing

Sources/swift-developer-docs-mcp/
├── Main.swift                   — Entry point: CLI → MCP → serve
├── AppleDocsMCPServer.swift     — MCP server metadata and tool registration
├── Commands/
│   ├── CLICommand.swift         — Protocol definition
│   ├── CLIRouter.swift          — Subcommand dispatch
│   ├── CLIArgParser.swift       — --json flag parsing
│   ├── SearchCommand.swift      — search <query>
│   ├── FetchCommand.swift       — fetch <path-or-url>
│   ├── HIGCommand.swift         — hig [path]
│   ├── VideoCommand.swift       — video <path>
│   ├── ExternalCommand.swift    — external <url>
│   └── ServeCommand.swift       — serve [--port N]
├── Tools/
│   ├── SearchTool.swift         — searchAppleDocumentation
│   ├── FetchDocumentationTool.swift — fetchAppleDocumentation
│   ├── FetchExternalDocTool.swift   — fetchExternalDocumentation
│   ├── FetchVideoTranscriptTool.swift — fetchAppleVideoTranscript
│   └── ToolExecutionError.swift — Failure raised as an MCP tool error
├── Server/
│   ├── ServerApp.swift          — Hummingbird routes + llms.txt
│   ├── AgentDiscovery.swift     — SKILL.md, agent card, api-catalog, agent-skills index
│   ├── SecurityHeadersMiddleware.swift
│   ├── CORSMiddleware.swift
│   └── TrailingSlashMiddleware.swift
└── Resources/
    └── llms.txt
```

## Entry Point

`Main.swift` creates an `AppleDocsMCPServer`, then a `CLIRouter`, and checks for subcommands. If a subcommand matches, it runs in CLI mode and exits. Otherwise, it starts the MCP server on stdio via the FastMCP builder.

```
args present? ──yes──▶ CLIRouter ──▶ matched command ──▶ run & exit
      │
      no
      │
      ▼
  FastMCP server (stdio)
```

The `serve` command starts a Hummingbird HTTP server instead of the MCP server.

## Injectable Dependency Pattern

All core components use an injectable struct pattern (inspired by swift-dependencies, without the library):

```swift
struct Fetcher: Sendable {
    var fetchJSON: @Sendable (URL) async throws -> Data
    var fetchHTML: @Sendable (URL) async throws -> String
}
extension Fetcher {
    static let live = Fetcher(fetchJSON: { ... }, fetchHTML: { ... })
}
```

This pattern is used by: `Fetcher`, `RenderingContext`, `SearchClient`, `ReferenceFetcher`, and `AppleDocsClient`. Tests use mock implementations injected via the same closures.

## Shared Action Layer

`AppleDocsClient` is the injectable actions struct with a `.live` static that delegates to `AppleDocsActions`. It provides:

- `fetch(path:)` — Reference documentation
- `search(query:)` — Search with formatted + JSON output
- `fetchHIG(path:)` — HIG page with path resolution for moved topics
- `fetchHIGTableOfContents()` — Full HIG table of contents
- `fetchVideo(path:)` — WWDC video transcript extraction
- `fetchExternal(url:)` — External DocC documentation with SSRF protection
- `unifiedFetch(input:)` — Auto-routes based on path pattern

`unifiedFetch` detects the content type from the path:
- `design/human-interface-guidelines/*` → HIG
- `videos/play/*` → Video transcript
- `external/*` → External documentation
- Everything else → Reference documentation

## CLI Layer

The CLI uses a protocol-based design with 6 commands:

| Command | Description |
|---------|-------------|
| `search <query>` | Search Apple Developer documentation |
| `fetch <path-or-url>` | Fetch any doc type (auto-routes) |
| `hig [path]` | Fetch HIG pages (no path = table of contents) |
| `video <path>` | Fetch WWDC video transcripts |
| `external <url>` | Fetch external Swift-DocC documentation |
| `serve [--port N]` | Start HTTP server (default: 8080) |

All commands support `--json` for JSON output. When a command fails, it prints one line `swift-developer-docs-mcp: <message>` to standard error and exits with status 1. `fetch --json` puts the URL of the resolved page in `url`.

## MCP Tools

4 MCP tools registered via FastMCP macros. The names are `searchAppleDocumentation`, `fetchAppleDocumentation`, `fetchExternalDocumentation`, and `fetchAppleVideoTranscript`.

| Tool | Input | Description |
|------|-------|-------------|
| `searchAppleDocumentation` | `query: String` | Search with readable text + native structured output |
| `fetchAppleDocumentation` | `path: String` | Fetch reference docs, HIG, video transcripts, or external docs via auto-routing |
| `fetchExternalDocumentation` | `url: String` | Fetch external DocC with SSRF protection |
| `fetchAppleVideoTranscript` | `path: String` | Fetch video transcripts |

The three fetch tools return plain Markdown text. `fetchAppleDocumentation` puts a text block before the Markdown when the page is at another path than the requested path: `No page exists at /documentation/<requested>. This is the page at /documentation/<resolved>.` A failure is a tool error (`isError`). The server instructions say that conformance conditions in Apple's data can be missing or wrong.

## HTTP Server

Hummingbird-based HTTP server with these routes:

| Route | Description |
|-------|-------------|
| `GET /` | HTML landing page, or `llms.txt` when `Accept: text/markdown` |
| `GET /llms.txt` | llms.txt content |
| `GET /search?q=...` | Search with content negotiation |
| `GET /documentation/{path+}` | Reference documentation |
| `GET /design/human-interface-guidelines` | HIG table of contents |
| `GET /design/human-interface-guidelines/{path+}` | HIG pages |
| `GET /videos/play/{collection}/{id}` | Video transcripts |
| `GET /external/{path+}` | External documentation |
| `GET /{path+}` | Catch-all 404 handler |

Middleware stack: TrailingSlashMiddleware → SecurityHeadersMiddleware → CORSMiddleware

Content negotiation: `GET /` returns HTML by default and `llms.txt` when `Accept: text/markdown` is sent. Documentation routes return JSON for `Accept: application/json`, otherwise Markdown. Responses include `ETag`, `Cache-Control`, and `Content-Location` headers. `GET /documentation/{path}` sets `Content-Location` to the URL of the resolved page. A missing page returns status 404. When more than one symbol matches, the Markdown answer has a `## Did you mean:` list and the JSON answer has a `candidates` array of objects with `title` and `path`.

## Core Library Modules

### Shared/Types.swift
All Codable & Sendable types mapping to Apple's documentation JSON API. Root type is `AppleDocJSON`. Key types: `ContentItem` (flexible union), `CodeValue` (string or array), `TextFragment`, `PropertyItem`, `FragmentItem`, `ConformanceInfo`, `ExternalOrigin`.

### Shared/ContentRenderer.swift
Shared rendering engine used by both ReferenceRenderer and ExternalRenderer:
- `renderInlineContent` — text, codeVoice, reference, emphasis, strong, image, superscript, subscript, strikethrough, newTerm
- `renderContentArray` — heading, paragraph, codeListing, lists, aside, table, row/column layout
- `renderTable`, `renderAside`, `renderImage`, `renderProperties`, `renderRelationships`
- Depth-limited (max content depth 50, max inline depth 20) to prevent stack overflow on malformed data while still supporting deeply nested Apple docs
- `MarkdownFormatting` formats lists, code blocks, tables, and callouts. Nested lists are indented.

### Reference pages
`DocumentationPageResolver` resolves a path before the page is rendered. Apple's paths for functions, methods, and overloaded symbols include a signature or a disambiguation suffix. When the requested page does not exist, the fetcher looks for the symbol in the references of the parent page. Exactly one match returns that page: `uniformtypeidentifiers/uttype/markdown` opens `uniformtypeidentifiers/uttype-swift.struct/markdown`. More than one match is an error that lists the candidate paths: `swiftui/view/body` lists `body-swift.associatedtype` and `body-8kl5o`. A slash at the end of a path is removed. Framework pages such as `/documentation/swiftui` come from the page JSON.

Abstracts keep code spans and links. Symbol link titles are in backticks. Relationship, topic, and see-also items show conditions such as "Conforms when `Element` conforms to `Equatable`." A page that documents an Objective-C symbol includes a note that links the Swift version.

### Search
Live search posts to `https://devintserv.msc.sbz.apple.com/api/v1/query` and reads the JSONL answer in `SearchParser.swift`. A result has title, url, description, breadcrumbs, tags, and type. A failed search is an error, not an empty list. `SearchParser.swift` still contains an HTML parser; live search does not use it.

### HIG Module
Full Human Interface Guidelines support:
- ToC fetch from Apple's index API. The table of contents lists every section.
- Page rendering with breadcrumbs, front matter, and content sections. Each tab of a tabbed section is rendered, including the Dynamic Type size tables on the Typography page.
- Path resolution for moved/renamed topics (leaf slug matching)

### Video Module
WWDC video transcript extraction:
- HTML fetch from developer.apple.com/videos/play/
- SwiftSoup parsing of `span[data-start]` elements
- MM:SS timestamp formatting

### External Module
External Swift-DocC documentation with full SSRF protection:
- URL validation (HTTPS-only, no credentials/fragments)
- Private IP blocking (IPv4: 10.x, 127.x, 172.16-31.x, 192.168.x; IPv6: ::1, fc00::/7, fe80::/10)
- Host allowlist/blocklist via environment variables
- robots.txt caching (5-min TTL, 1000 max entries, in-flight deduplication)
- X-Robots-Tag header inspection (none, noindex, noai, noimageai)
- doc:// identifier rewriting for external URLs

## Dependencies

| Package | Purpose |
|---------|---------|
| [swift-fast-mcp](https://github.com/mehmetbaykar/swift-fast-mcp) | MCP server framework (stdio transport, macro-based tool registration) |
| [SwiftSoup](https://github.com/scinfu/SwiftSoup) | HTML parsing for video transcripts. `SearchParser.swift` still contains an HTML parser; live search does not use it. |
| [Hummingbird](https://github.com/hummingbird-project/hummingbird) | HTTP server framework |

## Test Coverage

The test suite covers:
- Reference rendering (smoke tests, snapshot tests, content renderer tests)
- Search parsing (JSONL search service, plus the HTML parser)
- HIG (fetcher, renderer, path resolver, types codability)
- Video transcripts (path parsing, title extraction, timestamp formatting)
- External docs (SSRF policy, robots.txt caching, fetcher, renderer)
- Client routing (endpoint resolution, unified fetch dispatch)
- Error handling (error types, discrimination, edge cases)
- Concurrency (TaskGroup, Sendable verification)
- User agent rotation (diversity, format validation)
- Integration tests (opt-in real API calls via INTEGRATION_TESTS=1)
