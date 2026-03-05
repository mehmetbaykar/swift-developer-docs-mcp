# swift-developer-docs-mcp

## Overview

Convert the TypeScript **sosumi.ai** codebase (in `old-code-base/sosumi.ai/`) to a Swift MCP server that makes Apple Developer Documentation accessible to LLMs. Apple's documentation requires JavaScript rendering — LLMs only see "This page requires JavaScript." This server fetches, parses, and renders Apple docs as AI-readable Markdown.

**Source codebase:** `old-code-base/sosumi.ai/src/` (TypeScript, ~1,400 lines across 6 modules)

## Goals & Non-Goals

### Goals
- Port all MCP functionality: 2 tools (`searchAppleDocumentation`, `fetchAppleDocumentation`) + 1 resource (`doc://{path}`)
- Run as a local CLI tool over stdio, configured in Claude Desktop
- Use FastMCP for the MCP server layer
- Use SwiftSoup for HTML parsing (search results)
- Use URLSession/Foundation for networking
- Structure code as library + executable for future HTTP server addition
- Port tests to Swift Testing with JSON fixtures
- Swift 6.2 concurrency: actors for shared state, structs/enums over classes

### Non-Goals
- HTTP web server (deferred — code structured to support it later)
- Cloudflare Workers deployment
- Web UI / landing page
- Cross-platform Linux support (macOS only, uses Foundation)

## Technical Design

### Package Structure

```
swift-developer-docs-mcp/
├── Package.swift
├── Sources/
│   ├── AppleDocsCore/           # Library target
│   │   ├── Types.swift          # Codable models for Apple's JSON format
│   │   ├── Fetcher.swift        # JSON fetching from Apple's API
│   │   ├── Search.swift         # HTML scraping of Apple search results
│   │   ├── Renderer.swift       # JSON → Markdown rendering
│   │   └── URLUtilities.swift   # Path normalization and validation
│   └── swift-developer-docs-mcp/ # Executable target
│       ├── Main.swift           # @main entry point with FastMCP builder
│       ├── Tools/
│       │   ├── SearchTool.swift          # searchAppleDocumentation MCPTool
│       │   └── FetchDocumentationTool.swift  # fetchAppleDocumentation MCPTool
│       └── Resources/
│           └── DocumentationResource.swift   # doc://{path} MCPResource
├── Tests/
│   ├── AppleDocsCoreTests/
│   │   ├── RendererTests.swift
│   │   ├── URLUtilitiesTests.swift
│   │   ├── FetcherTests.swift
│   │   └── Fixtures/
│   │       └── array.json       # Real Apple documentation JSON fixture
│   └── IntegrationTests/
│       └── SmokeTests.swift
└── old-code-base/               # Original TypeScript (reference only)
```

### Dependencies

```swift
dependencies: [
    .package(url: "https://github.com/mehmetbaykar/swift-fast-mcp", from: "1.0.2"),  // FastMCP
    .package(url: "https://github.com/scinfu/SwiftSoup", from: "2.7.0"),             // HTML parsing
]
```

**Targets:**
- `AppleDocsCore` — library, depends on SwiftSoup
- `swift-developer-docs-mcp` — executable, depends on AppleDocsCore + FastMCP
- `AppleDocsCoreTests` — tests, depends on AppleDocsCore

### Architecture

```
┌──────────────────────────────────────────┐
│  FastMCP Server (Main.swift)             │
│  - stdio transport                       │
│  - registers tools + resources           │
└────────┬─────────────┬───────────────────┘
         │             │
    ┌────▼────┐   ┌────▼──────────────┐
    │ Search  │   │ Fetch + Resource  │
    │ Tool    │   │ Tool              │
    └────┬────┘   └────┬──────────────┘
         │             │
    ┌────▼────┐   ┌────▼──────────────┐
    │ Search  │   │ URLUtilities      │
    │ (HTML)  │   │ (normalize path)  │
    └────┬────┘   └────┬──────────────┘
         │             │
         │        ┌────▼──────────────┐
         │        │ Fetcher           │
         │        │ (Apple JSON API)  │
         │        └────┬──────────────┘
         │             │
         │        ┌────▼──────────────┐
         │        │ Renderer          │
         │        │ (JSON → Markdown) │
         │        └───────────────────┘
         │
    ┌────▼────────────────────────────┐
    │ Apple Developer Search (HTML)   │
    │ developer.apple.com/search/     │
    └─────────────────────────────────┘
```

### Data Model (Types.swift)

Port all ~30 TypeScript types from `types.ts` as strict `Codable` structs/enums. Key types:

- `AppleDocJSON` — root document structure
- `ContentItem` — discriminated union via `type` field (heading, paragraph, codeListing, aside, unorderedList, orderedList, etc.)
- `InlineContent` — text, codeVoice, reference, emphasis, strong, image
- `Declaration`, `Parameter` — code structure types
- `TopicSection`, `SeeAlsoSection`, `PrimaryContentSection`
- `Platform`, `DocumentationMetadata`, `DocumentationIdentifier`
- Type variants: `LanguageVariant`, `ImageVariant`, `SymbolVariant` (with enum discrimination)

Use Swift enums with associated values for discriminated unions. Strict Codable — fail on unknown types.

### Fetcher (Fetcher.swift)

- Fetch JSON from `https://developer.apple.com/tutorials/data/documentation/{path}.json`
- Framework index from `https://developer.apple.com/tutorials/data/index/{framework}`
- **User-agent rotation**: Port all 26 Safari user-agent strings, randomly select per request
- Use `URLSession.shared` with async/await
- Return decoded `AppleDocJSON`
- Throw typed errors for HTTP failures

### Search (Search.swift)

- Fetch HTML from `https://developer.apple.com/search/?q={query}`
- Parse with **SwiftSoup** to extract:
  - Result titles and URLs (from links)
  - Descriptions (from paragraphs)
  - Breadcrumb navigation
  - Language/platform tags
- Return `SearchResponse` struct with `[SearchResult]`

### Renderer (Renderer.swift)

Single `DocumentRenderer` struct with methods for each content type. Ports `render.ts` (~538 lines):

- `renderFromJSON(jsonData:sourceURL:) -> String`
- Front matter generation (YAML: title, description, source, timestamp)
- Breadcrumb navigation
- Symbol type + title rendering
- Platform availability
- Abstract content
- Declaration sections (code blocks)
- Parameter documentation
- Content sections: headings, paragraphs, code listings, lists, callouts/asides
- Relationship sections (Inherited By, Conforming Types, etc.)
- Topic sections with identifiers and abstracts
- Index content for framework pages
- See Also sections
- Inline content: text, code voice, references → markdown links, emphasis, strong
- **Recursion depth limit** (port as-is from TypeScript)
- **100-character minimum content threshold** (port as-is)
- Identifier-to-URL conversion (`doc://` cross-references)
- Footer: "Generated by swift-developer-docs-mcp" + Apple copyright notice

### URLUtilities (URLUtilities.swift)

- `normalizeDocumentationPath(_ path: String) -> String` — strips leading slashes, `documentation/` prefix, trims whitespace
- `generateAppleDocURL(_ normalizedPath: String) -> URL` — constructs full Apple documentation URL
- `isValidAppleDocURL(_ url: URL) -> Bool` — validates URL is proper Apple docs URL

### MCP Server (Main.swift)

```swift
@main
struct AppleDocsServer {
    static func main() async throws {
        try await FastMCP.builder()
            .name("swift-developer-docs-mcp")
            .version("1.0.0")
            .addTools([
                SearchAppleDocsTool(),
                FetchAppleDocsTool()
            ])
            .addResources([DocumentationResource()])
            .transport(.stdio)
            .shutdownSignals([.sigterm, .sigint])
            .run()
    }
}
```

### Style Guidelines

- **Structs and enums over classes** — composable architecture style without TCA dependency
- **Actors for concurrency** — use actor isolation for any shared mutable state (Swift 6.2)
- **Sendable conformance** throughout
- **Typed throws** where FastMCP requires `throws(ToolError)`
- No classes unless absolutely necessary

## MCP Interface

### Tool: `searchAppleDocumentation`

| Field | Value |
|-------|-------|
| Name | `searchAppleDocumentation` |
| Description | Search Apple Developer Documentation |
| Parameters | `query: String` (required) |
| Returns | Structured JSON with results array: title, url, description, breadcrumbs, tags |
| Annotations | Read-only, no side effects |

### Tool: `fetchAppleDocumentation`

| Field | Value |
|-------|-------|
| Name | `fetchAppleDocumentation` |
| Description | Fetch Apple Developer Documentation as Markdown |
| Parameters | `path: String` (required) — full or relative documentation path |
| Returns | Rendered Markdown content |
| Annotations | Read-only, no side effects |

### Resource: `doc://{path}`

| Field | Value |
|-------|-------|
| URI Template | `doc://{path}` |
| Name | Apple Developer Documentation |
| Description | Get Apple Developer documentation as markdown |
| MIME Type | `text/markdown` |
| Returns | Rendered Markdown with front matter |

## Edge Cases & Error Handling

| Scenario | Behavior |
|----------|----------|
| Invalid documentation path | Throw descriptive error: "Invalid path. Expected format: swift/array" |
| Apple API returns 404 | Throw error: "Documentation not found at path: {path}" |
| Apple API returns non-200 | Throw error with HTTP status code |
| Rendered content < 100 chars | Throw error: "Insufficient content returned" |
| Recursion depth exceeded | Stop rendering, return content rendered so far |
| Network timeout | Let URLSession timeout propagate (default 60s) |
| Malformed JSON from Apple | Strict Codable decoding fails with descriptive error |
| Search returns no results | Return empty results array (not an error) |
| Empty/whitespace path input | Normalize to empty string, fail with invalid path error |

## Security & Privacy

- No credentials or API keys required (Apple's JSON API is public)
- No data stored locally — all fetching is transient
- User-agent rotation mimics Safari browser (same as TypeScript version)
- No analytics or telemetry
- Attribution footer links back to original Apple documentation
- Copyright notice preserved

## Performance

- **No caching** in the MCP server (caching is an HTTP server concern, deferred)
- Each tool call makes 1 HTTP request to Apple's API
- Search tool makes 1 HTTP request to Apple's search page
- Renderer operates in-memory on the fetched JSON — no I/O
- Recursion depth limit prevents stack overflow on pathological documents

## Migration & Compatibility

- This is a **new Swift implementation**, not a migration of running data
- The TypeScript version at sosumi.ai continues to run independently
- MCP tool names and parameters are identical to the TypeScript version for client compatibility
- Clients configured for the TypeScript MCP server can switch to this Swift server by changing only the command path

## Testing Strategy

### Unit Tests (Swift Testing)

| Test Suite | What It Tests |
|------------|---------------|
| `RendererTests` | All 15+ content types render correctly to Markdown. Uses `array.json` fixture. Tests front matter, declarations, parameters, callouts, lists, code blocks, inline content, relationships, topics, see-also, footer. |
| `URLUtilitiesTests` | Path normalization (leading slashes, `documentation/` prefix, whitespace). URL generation. URL validation. |
| `FetcherTests` | User-agent rotation produces valid agents. URL construction for paths and framework indexes. |
| `SearchTests` | HTML parsing extracts titles, URLs, descriptions, breadcrumbs, tags from sample HTML. |

### Integration Tests

| Test | What It Tests |
|------|---------------|
| `SmokeTests` | End-to-end: fetch real Apple documentation → render → validate output has expected sections. Skipped in CI (requires network). |

### Test Fixtures
- `array.json` — port from `tests/fixtures/array.json` (real Swift.Array documentation JSON)

## Open Questions

None — all ambiguities resolved during spec interview.

## Decision Log

| Decision | Rationale |
|----------|-----------|
| MCP-first, HTTP later | All functionality lives in the MCP tools/resources. HTTP server is just a thin wrapper — can be added later without restructuring. |
| SwiftSoup for HTML parsing | Well-maintained pure Swift library. Replaces Cloudflare's HTMLRewriter which has no Swift equivalent. |
| Local CLI tool (macOS) | Target use case is Claude Desktop integration via stdio. URLSession/Foundation is the natural fit. |
| Single DocumentRenderer struct | Mirrors the TypeScript closely. Simpler than protocol-based decomposition. 538 lines is manageable in one struct. |
| Keep 26 user-agent rotation | Same anti-blocking strategy as TypeScript. Local usage is lower volume but keeps parity. |
| Strict Codable | Prefer failing loudly over silently dropping content. Apple's JSON format is stable. |
| Port safety mechanisms as-is | Recursion depth limit and content threshold are battle-tested values from production TypeScript. |
| Library + executable split | Makes core logic testable independently. Enables future HTTP server target without code duplication. |
| "Generated by swift-developer-docs-mcp" footer | Replaces sosumi.ai branding per user preference. |
| Port tests to Swift Testing | Ensures rendering correctness, especially for the complex Markdown output. JSON fixtures provide real-world test data. |
