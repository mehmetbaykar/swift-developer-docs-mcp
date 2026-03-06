---
name: apple-docs
description: Search and fetch Apple developer documentation as clean, AI-readable Markdown. Use when any question involves Apple frameworks, APIs, Swift standard library, SwiftUI, UIKit, Foundation, Combine, or any Apple platform SDK. Returns full declarations, parameters, platform availability, topic sections, relationships, and see-also links.
argument-hint: <query or path>
allowed-tools: Bash(npx *)
---

Search and fetch Apple developer documentation for: $ARGUMENTS

## About this tool

Apple's developer documentation is JavaScript-rendered and invisible to LLMs. This tool fetches the underlying JSON data from developer.apple.com and converts it to clean, structured Markdown — including declarations, parameters, platform availability, topic sections, relationships, code examples, callouts, and see-also links.

## How to use

### Step 1: Search

Run the search command to find relevant documentation pages:

```bash
npx -y @mehmetbaykar/swift-developer-docs-mcp search "$ARGUMENTS"
```

Search returns results with: title, URL, description, breadcrumbs, and tags. The output includes both a human-readable list and structured JSON.

### Step 2: Fetch the best match

Extract the documentation path from the search results (the path after `/documentation/` in the URL). Then fetch the full page:

```bash
npx -y @mehmetbaykar/swift-developer-docs-mcp fetch <path>
```

**Path format examples:**
- `swift/array` — Swift Array
- `swiftui/view` — SwiftUI View protocol
- `foundation/urlsession` — Foundation URLSession
- `combine/publisher` — Combine Publisher
- `swift/array/append(_:)` — A specific method

The path is flexible — leading slashes, `documentation/` prefixes, and whitespace are all handled automatically.

### Step 3: Present the documentation

The fetched output is a complete Markdown document containing:

- **YAML front matter** with title, description, source URL, and timestamp
- **Breadcrumb navigation** showing the symbol's place in the hierarchy
- **Role heading** (Structure, Protocol, Class, Function, etc.)
- **Platform availability** (iOS, macOS, watchOS, tvOS, visionOS with version numbers and beta flags)
- **Abstract** as a blockquote summary
- **Swift declarations** in fenced code blocks
- **Parameters** with names and descriptions
- **Discussion** with paragraphs, code examples, and callouts (NOTE, WARNING, TIP, IMPORTANT, CAUTION)
- **Topic sections** organized by category (e.g., "Creating an Array", "Accessing Elements") with links to each member
- **Relationships** (conformances, inheritance)
- **See Also** with related documentation links

Present this documentation clearly. If the user asked about a specific API, highlight the relevant sections. If they asked a general question, summarize the key points.

## Tips

- If the query looks like a doc path (e.g., `swift/array`, `swiftui/view`), skip search and fetch directly.
- If search returns no results, suggest alternative search terms or try a broader query.
- You can fetch multiple pages to compare APIs or gather comprehensive information.
- The tool rotates through 26 user-agent strings to avoid rate limiting, so repeated calls are safe.
