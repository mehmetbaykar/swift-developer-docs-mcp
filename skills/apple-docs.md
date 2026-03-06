---
name: apple-docs
description: Search and fetch Apple developer documentation. Use when any question involves Apple frameworks, APIs, or Swift standard library docs.
argument-hint: <query>
allowed-tools: Bash(npx *)
---

Search and fetch Apple developer documentation for: $ARGUMENTS

Follow these steps:

1. Run the search command:
```bash
npx -y @mehmetbaykar/swift-developer-docs-mcp search "$ARGUMENTS"
```

2. Review the search results. If a relevant documentation page is found, extract its path from the results (e.g., `swift/array`, `swiftui/view`).

3. Fetch the full documentation for the most relevant result:
```bash
npx -y @mehmetbaykar/swift-developer-docs-mcp fetch <path>
```

4. Present the fetched documentation to the user in a clear, readable format.

If the search returns no results, let the user know and suggest alternative search terms.
