---
name: apple-docs
description: Search and fetch Apple developer documentation, Human Interface Guidelines, WWDC video transcripts, and external Swift-DocC sites as clean, AI-readable Markdown. Use when any question involves Apple frameworks, APIs, Swift standard library, SwiftUI, UIKit, Foundation, Combine, design guidelines, WWDC sessions, or any Apple platform SDK.
argument-hint: <query or path>
allowed-tools: Bash(npx *)
---

Search and fetch Apple developer documentation for: $ARGUMENTS

## About this tool

Apple's developer documentation is JavaScript-rendered and invisible to LLMs. This tool fetches the underlying JSON data from developer.apple.com and converts it to clean, structured Markdown with full API details — declarations, parameters, platform availability, code examples, topic sections, conformances, and see-also links.

Supports four content types:
- **Reference documentation** — API docs for all Apple frameworks
- **Human Interface Guidelines** — Apple's design guidelines (HIG)
- **WWDC video transcripts** — Timestamped transcripts from Apple developer videos
- **External Swift-DocC sites** — Third-party documentation hosted as Swift-DocC (with SSRF protection)

## How to use

### Step 1: Search

Run the search command to find relevant documentation pages:

```bash
npx -y @mehmetbaykar/swift-developer-docs-mcp search "$ARGUMENTS"
```

Search returns a numbered list followed by structured JSON. Each result includes:
- **Title** and **URL**
- **Description** (abstract text)
- **Path** (breadcrumbs, e.g., `SwiftUI > NSHostingView > rootView`)
- **Tags** indicating result type: `DOCUMENTATION`, `DOCUMENTATION ARTICLE`, `SAMPLE CODE`, `WWDC VIDEO`, `NEWS`

### Step 2: Fetch the best match

Based on the URL pattern, use the appropriate command:

**Reference documentation** (URLs containing `/documentation/`):
```bash
npx -y @mehmetbaykar/swift-developer-docs-mcp fetch <path>
```
Path examples: `swift/array`, `swiftui/view`, `foundation/urlsession`, `swift/array/append(_:)`

**Human Interface Guidelines** (URLs containing `/design/human-interface-guidelines/`):
```bash
npx -y @mehmetbaykar/swift-developer-docs-mcp hig <path>
```
Path examples: `foundations/color`, `components/menus-and-actions/buttons`, `inputs/touch-interactions`

To get the full HIG table of contents:
```bash
npx -y @mehmetbaykar/swift-developer-docs-mcp hig
```

**WWDC video transcripts** (URLs containing `/videos/play/`):
```bash
npx -y @mehmetbaykar/swift-developer-docs-mcp video videos/play/<collection>/<id>
```
Path examples: `videos/play/wwdc2024/10133`, `videos/play/wwdc2023/10148`

**External Swift-DocC sites**:
```bash
npx -y @mehmetbaykar/swift-developer-docs-mcp external <url>
```
URL examples: `https://apple.github.io/swift-argument-parser/documentation/argumentparser`

**Auto-routing** — the `fetch` command can also auto-detect content type from the path:
```bash
npx -y @mehmetbaykar/swift-developer-docs-mcp fetch design/human-interface-guidelines/foundations/color
npx -y @mehmetbaykar/swift-developer-docs-mcp fetch videos/play/wwdc2024/10133
npx -y @mehmetbaykar/swift-developer-docs-mcp fetch https://apple.github.io/swift-argument-parser/documentation/argumentparser
```

### Step 3: Present the documentation

The fetched output is a comprehensive Markdown document. For example, `fetch swift/array` returns ~550 lines covering:

- **YAML front matter** — title, description, source URL, timestamp
- **Navigation breadcrumbs** — e.g., `[Swift](/documentation/swift)`
- **Role heading** — Structure, Protocol, Class, Function, etc.
- **Platform availability** — e.g., `iOS 8.0+, iPadOS 8.0+, macOS 10.10+, visionOS 1.0+`
- **Abstract** — blockquote summary
- **Swift declaration** — e.g., `@frozen struct Array<Element>`
- **Overview** — full prose documentation with code examples
- **Topic sections** — organized by category
- **Conformances** — full list
- **Related types** and **See Also** links

Present this documentation clearly. If the user asked about a specific API, highlight the relevant sections. If they asked a general question, summarize the key points and link to specific methods.

## Tips

- If the query looks like a doc path (contains `/`, e.g., `swift/array`, `swiftui/view`), skip search and fetch directly.
- If the query mentions "HIG", "design guidelines", or "human interface", use the `hig` command.
- If the query mentions a WWDC session number or "video transcript", use the `video` command.
- If the query includes a non-Apple URL (e.g., `github.io`), use the `external` command.
- If search returns no results, suggest alternative search terms or try a broader query.
- You can fetch multiple pages to compare APIs or gather comprehensive information.
- The tool rotates through 26 user-agent strings to avoid rate limiting, so repeated calls are safe.
- Search returns both human-readable text AND structured JSON — use the JSON when you need to programmatically extract paths.
- All commands support `--json` for structured JSON output.
