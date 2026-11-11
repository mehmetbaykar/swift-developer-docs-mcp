import Testing

@testable import AppleDocsCore

@Suite("MarkdownFormatting")
struct MarkdownFormattingTests {
  @Test("Indents an unordered list nested three levels inside an ordered list")
  func threeLevelNestedList() {
    let level3 = MarkdownFormatting.formatList(["Level 3\n\n"], ordered: false)
    let level2 = MarkdownFormatting.formatList(["Level 2\n\n" + level3], ordered: false)
    let level1 = MarkdownFormatting.formatList(["Level 1\n\n" + level2], ordered: true)
    #expect(level1 == "1. Level 1\n   - Level 2\n     - Level 3\n\n")
  }

  @Test("Preserves paragraph breaks inside a list item")
  func twoParagraphs() {
    let result = MarkdownFormatting.formatList(
      ["First paragraph.\n\nSecond paragraph.\n\n"],
      ordered: false
    )
    #expect(result == "- First paragraph.\n\n  Second paragraph.\n\n")
  }

  @Test("Indents a code block inside a list item")
  func codeBlockInListItem() {
    let code = MarkdownFormatting.formatCodeBlock("let x = 1", syntax: "swift")
    let result = MarkdownFormatting.formatList(["See:\n\n" + code], ordered: false)
    #expect(result == "- See:\n\n  ```swift\n  let x = 1\n  ```\n\n")
  }

  @Test("Does not indent blank lines inside a list item")
  func blankLinesStayEmpty() {
    let result = MarkdownFormatting.formatList(["A\n\n\nB\n\n"], ordered: false)
    #expect(result == "- A\n\n\n  B\n\n")
  }

  @Test("Drops the trailing space from an empty list item marker")
  func emptyListItem() {
    #expect(MarkdownFormatting.formatList([""], ordered: false) == "-\n\n")
    #expect(MarkdownFormatting.formatList([""], ordered: true) == "1.\n\n")
  }

  @Test("Escapes a pipe and flattens a line break in a table cell")
  func tablePipeAndLineBreak() {
    let result = MarkdownFormatting.formatTable(
      [["a|b\nnext line", "plain"]],
      hasHeaderRow: true
    )
    #expect(result == "| a\\|b next line | plain |\n| --- | --- |\n\n")
  }

  @Test("Quotes each line of a two-paragraph callout")
  func calloutTwoParagraphs() {
    let result = MarkdownFormatting.formatCallout(
      type: "NOTE",
      content: "First.\n\nSecond.\n\n"
    )
    #expect(result == "> [!NOTE]\n> First.\n>\n> Second.\n\n")
  }

  @Test("Places a lead ahead of callout content")
  func calloutWithLead() {
    let result = MarkdownFormatting.formatCallout(
      type: "WARNING",
      content: "Body.\n\n",
      lead: "**Deprecated**"
    )
    #expect(result == "> [!WARNING]\n> **Deprecated**\n>\n> Body.\n\n")
  }

  @Test("Renders an empty callout as nothing")
  func emptyCallout() {
    #expect(MarkdownFormatting.formatCallout(type: "NOTE", content: " \n\n") == "")
    #expect(MarkdownFormatting.formatCallout(type: "NOTE", content: "", lead: "") == "")
  }

  @Test("Maps DocC occ syntax to objc and defaults empty syntax to swift")
  func codeFenceLanguage() {
    #expect(
      MarkdownFormatting.formatCodeBlock("NSButton *button;", syntax: "occ")
        == "```objc\nNSButton *button;\n```\n\n"
    )
    #expect(
      MarkdownFormatting.formatCodeBlock("let x = 1", syntax: nil)
        == "```swift\nlet x = 1\n```\n\n"
    )
    #expect(
      MarkdownFormatting.formatCodeBlock("let x = 1", syntax: "")
        == "```swift\nlet x = 1\n```\n\n"
    )
  }

  @Test("Maps aside styles to GitHub callout types")
  func asideStyles() {
    #expect(MarkdownFormatting.mapAsideStyleToCallout("warning") == "WARNING")
    #expect(MarkdownFormatting.mapAsideStyleToCallout("important") == "IMPORTANT")
    #expect(MarkdownFormatting.mapAsideStyleToCallout("caution") == "CAUTION")
    #expect(MarkdownFormatting.mapAsideStyleToCallout("tip") == "TIP")
    #expect(MarkdownFormatting.mapAsideStyleToCallout("deprecated") == "WARNING")
    #expect(MarkdownFormatting.mapAsideStyleToCallout("experiment") == "NOTE")
    #expect(MarkdownFormatting.mapAsideStyleToCallout("custom") == "NOTE")
    #expect(MarkdownFormatting.mapAsideStyleToCallout("WARNING") == "WARNING")
  }

  @Test("Exposes the shared depth-guard placeholders")
  func depthPlaceholders() {
    #expect(MarkdownFormatting.maxContentDepth == 50)
    #expect(MarkdownFormatting.maxInlineDepth == 20)
    #expect(MarkdownFormatting.contentTooDeep == "[Content too deeply nested]")
    #expect(MarkdownFormatting.inlineContentTooDeep == "[Inline content too deeply nested]")
  }
}
