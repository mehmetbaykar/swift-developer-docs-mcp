---
name: apple-docs
description: Search and fetch Apple developer documentation, Human Interface Guidelines, WWDC video transcripts, and external Swift-DocC sites as clean, AI-readable Markdown. Use when any question involves Apple frameworks, APIs, Swift standard library, SwiftUI, UIKit, Foundation, Combine, design guidelines, WWDC sessions, or any Apple platform SDK.
---

Search and fetch Apple developer documentation for: $ARGUMENTS

# apple-docs Skill

Use this skill to reliably fetch Apple docs as Markdown when coding agents need precise API details.

## When to Use

Use this skill when the request involves any of the following:

- Apple platform APIs (`Swift`, `SwiftUI`, `UIKit`, `AppKit`, `Foundation`, etc.)
- API signatures, availability, parameter behavior, or return semantics
- Human Interface Guidelines questions
- WWDC session transcript lookup
- External Swift-DocC documentation (for example, GitHub Pages or Swift Package Index hosts)

## Core Workflow

1. If you already know the exact path, fetch it directly.
2. If you do not know the exact page path, search first, then fetch the best match.
3. Prefer specific symbol pages instead of broad top-level pages when answering implementation questions.

## CLI Usage

### Search

```bash
npx -y -p @mehmetbaykar/swift-developer-docs-mcp \
  swift-developer-docs-mcp search "$ARGUMENTS"
```

### Apple API Reference

```bash
npx -y -p @mehmetbaykar/swift-developer-docs-mcp \
  swift-developer-docs-mcp fetch swift/array
npx -y -p @mehmetbaykar/swift-developer-docs-mcp \
  swift-developer-docs-mcp fetch swiftui/view
```

### Human Interface Guidelines

```bash
npx -y -p @mehmetbaykar/swift-developer-docs-mcp \
  swift-developer-docs-mcp hig
npx -y -p @mehmetbaykar/swift-developer-docs-mcp \
  swift-developer-docs-mcp hig foundations/color
```

### Apple Video Transcripts

```bash
npx -y -p @mehmetbaykar/swift-developer-docs-mcp \
  swift-developer-docs-mcp video videos/play/wwdc2024/10133
```

### External Swift-DocC

```bash
npx -y -p @mehmetbaykar/swift-developer-docs-mcp \
  swift-developer-docs-mcp external https://apple.github.io/swift-argument-parser/documentation/argumentparser
```

### Auto-routing

```bash
npx -y -p @mehmetbaykar/swift-developer-docs-mcp \
  swift-developer-docs-mcp fetch design/human-interface-guidelines/foundations/color
npx -y -p @mehmetbaykar/swift-developer-docs-mcp \
  swift-developer-docs-mcp fetch videos/play/wwdc2024/10133
npx -y -p @mehmetbaykar/swift-developer-docs-mcp \
  swift-developer-docs-mcp fetch https://apple.github.io/swift-argument-parser/documentation/argumentparser
```

## MCP Tools Quick Reference

Use these when `swift-developer-docs-mcp` is configured as an MCP server, either over stdio or HTTP (`/mcp`):

| Tool | Parameters | Use |
|---|---|---|
| `searchAppleDocumentation` | `query: string` | Search Apple documentation and return readable text plus native structured MCP output |
| `fetchAppleDocumentation` | `path: string` | Fetch Apple docs, HIG content, video transcripts, or external docs via auto-routing |
| `fetchAppleVideoTranscript` | `path: string` | Fetch Apple video transcript by `/videos/play/...` path |
| `fetchExternalDocumentation` | `url: string` | Fetch external Swift-DocC page by absolute HTTPS URL |

## Best Practices

- Search first if the exact path is unknown.
- Fetch targeted symbol pages for coding questions.
- Keep source links in answers so users can verify details quickly.
- Use the CLI `fetch` command when you want automatic routing across documentation, HIG, video, and external docs.
- Prefer `npx -p ... swift-developer-docs-mcp ...` over the shorthand `npx <package> ...` form so the binary is invoked explicitly.

## Troubleshooting

### 404 or sparse output

- The path may be incorrect or too broad.
- Run a search query first, then fetch a specific result path.

### External page cannot be fetched

- The host may block access via `robots.txt` or `X-Robots-Tag` directives.
- Try another canonical page URL for the same symbol.

### Search clients only show text

- `searchAppleDocumentation` now publishes native `structuredContent` and `outputSchema`.
- Some MCP clients still display only text content, so the tool also keeps a readable summary in the normal content payload.
