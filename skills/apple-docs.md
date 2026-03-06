---
name: apple-docs
description: Search and fetch Apple developer documentation as clean, AI-readable Markdown. Use when any question involves Apple frameworks, APIs, Swift standard library, SwiftUI, UIKit, Foundation, Combine, or any Apple platform SDK. Returns full declarations, parameters, platform availability, topic sections, relationships, and see-also links.
argument-hint: <query or path>
allowed-tools: Bash(npx *)
---

Search and fetch Apple developer documentation for: $ARGUMENTS

## About this tool

Apple's developer documentation is JavaScript-rendered and invisible to LLMs. This tool fetches the underlying JSON data from developer.apple.com and converts it to clean, structured Markdown with full API details — declarations, parameters, platform availability, code examples, topic sections, conformances, and see-also links.

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

**Important:** Only results with `/documentation/` in their URL can be fetched. Results pointing to `/videos/`, `/pathways/`, `/articles/`, or general Apple pages are not fetchable — use them as references only.

### Step 2: Fetch the best match

Extract the documentation path from the URL of the best result. The path is everything after `/documentation/` in the URL. Then fetch the full page:

```bash
npx -y @mehmetbaykar/swift-developer-docs-mcp fetch <path>
```

**Path format examples:**
- `swift/array` — Swift Array struct
- `swiftui/view` — SwiftUI View protocol
- `foundation/urlsession` — Foundation URLSession
- `combine/publisher` — Combine Publisher protocol
- `swift/array/append(_:)` — A specific method
- `swiftui/nshostingview` — A specific class

The path is flexible — leading slashes, `documentation/` prefixes, and whitespace are all handled automatically.

### Step 3: Present the documentation

The fetched output is a comprehensive Markdown document. For example, `fetch swift/array` returns ~550 lines covering:

- **YAML front matter** — title, description, source URL, timestamp
- **Navigation breadcrumbs** — e.g., `[Swift](/documentation/swift)`
- **Role heading** — Structure, Protocol, Class, Function, etc.
- **Platform availability** — e.g., `iOS 8.0+, iPadOS 8.0+, macOS 10.10+, visionOS 1.0+`
- **Abstract** — blockquote summary
- **Swift declaration** — e.g., `@frozen struct Array<Element>`
- **Overview** — full prose documentation with code examples
- **Topic sections** — organized by category:
  - Creating an Array, Inspecting an Array, Accessing Elements
  - Adding Elements, Combining Arrays, Removing Elements
  - Finding Elements, Selecting Elements, Transforming an Array
  - Reordering, Splitting/Joining, Encoding/Decoding, etc.
- **Conformances** — full list (Sequence, Collection, Equatable, Codable, Sendable, etc.)
- **Related types** — ContiguousArray, ArraySlice, NSArray
- **See Also** — links to related documentation

Present this documentation clearly. If the user asked about a specific API, highlight the relevant sections. If they asked a general question, summarize the key points and link to specific methods.

## Tips

- If the query looks like a doc path (contains `/`, e.g., `swift/array`, `swiftui/view`), skip search and fetch directly.
- If search returns no results, suggest alternative search terms or try a broader query.
- You can fetch multiple pages to compare APIs or gather comprehensive information.
- The tool rotates through 26 user-agent strings to avoid rate limiting, so repeated calls are safe.
- Search returns both human-readable text AND structured JSON — use the JSON when you need to programmatically extract paths.
- Only results tagged `DOCUMENTATION` have fetchable paths. `WWDC VIDEO`, `SAMPLE CODE`, and `NEWS` results are reference-only.
