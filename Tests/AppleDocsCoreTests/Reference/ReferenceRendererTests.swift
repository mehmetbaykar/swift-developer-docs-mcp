import Foundation
import Testing

@testable import AppleDocsCore

@Suite("Renderer")
struct RendererTests {
  @Suite("Front Matter Generation")
  struct FrontMatter {
    @Test("Generates YAML front matter with title from metadata")
    func titleFromMetadata() {
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(title: "SwiftUI View | Apple Developer Documentation")
      )
      let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
      #expect(result.contains("title: SwiftUI View\n"))
      #expect(result.contains("source: https://test.com"))
      #expect(!result.contains("title: SwiftUI View | Apple Developer Documentation"))
    }

    @Test("Includes description from abstract")
    func descriptionFromAbstract() {
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(title: "Test Title"),
        abstract: [
          ContentItem(text: "This is the abstract description.", type: "text"),
          ContentItem(text: " Additional text.", type: "text"),
        ]
      )
      let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
      #expect(result.contains("description: This is the abstract description. Additional text."))
    }

    @Test("Handles missing title gracefully")
    func missingTitle() {
      let data = AppleDocJSON()
      let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
      #expect(result.hasPrefix("---\n"))
      #expect(result.contains("source: https://test.com"))
      #expect(!result.contains("title:"))
    }
  }

  @Suite("Breadcrumb Navigation")
  struct Breadcrumbs {
    @Test("Generates breadcrumbs for documentation URLs")
    func documentationURLs() {
      let data = AppleDocJSON()

      let result1 = DocumentRenderer.renderFromJSON(
        data, sourceURL: "https://developer.apple.com/documentation/swiftui/view")
      #expect(result1.contains("**Navigation:** [Swiftui](/documentation/swiftui)\n\n"))

      let result2 = DocumentRenderer.renderFromJSON(
        data, sourceURL: "https://developer.apple.com/documentation/swift/array/append")
      #expect(
        result2.contains(
          "**Navigation:** [Swift](/documentation/swift) › [array](/documentation/swift/array)\n\n")
      )

      let result3 = DocumentRenderer.renderFromJSON(
        data, sourceURL: "https://developer.apple.com/documentation/foundation/nsstring/init")
      #expect(
        result3.contains(
          "**Navigation:** [Foundation](/documentation/foundation) › [nsstring](/documentation/foundation/nsstring)\n\n"
        ))
    }

    @Test("Does not generate breadcrumbs for short paths")
    func shortPaths() {
      let data = AppleDocJSON()
      let shortUrls = [
        "https://developer.apple.com/documentation",
        "https://developer.apple.com/documentation/swiftui",
        "https://example.com/short",
      ]
      for url in shortUrls {
        let result = DocumentRenderer.renderFromJSON(data, sourceURL: url)
        #expect(!result.contains("**Navigation:**"))
      }
    }

    @Test("Capitalizes framework names properly")
    func capitalization() {
      let data = AppleDocJSON()
      let result = DocumentRenderer.renderFromJSON(
        data, sourceURL: "https://developer.apple.com/documentation/swiftui/view")
      #expect(result.contains("[Swiftui](/documentation/swiftui)"))
    }
  }

  @Suite("Declaration Rendering")
  struct Declarations {
    @Test("Renders Swift declarations with proper formatting")
    func basicDeclaration() {
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(title: "Declaration Test"),
        primaryContentSections: [
          PrimaryContentSection(
            kind: "declarations",
            declarations: [
              Declaration(tokens: [
                Token(text: "func", kind: "keyword"),
                Token(text: " ", kind: "text"),
                Token(text: "myFunction", kind: "identifier"),
                Token(text: "(", kind: "text"),
                Token(text: "param", kind: "externalParam"),
                Token(text: ": ", kind: "text"),
                Token(text: "String", kind: "typeIdentifier"),
                Token(text: ")", kind: "text"),
              ])
            ])
        ]
      )
      let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
      #expect(result.contains("```swift\nfunc myFunction(param: String)\n```"))
    }

    @Test("Handles multiple declarations")
    func multipleDeclarations() {
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(title: "Multiple Declarations"),
        primaryContentSections: [
          PrimaryContentSection(
            kind: "declarations",
            declarations: [
              Declaration(tokens: [
                Token(text: "var", kind: "keyword"),
                Token(text: " ", kind: "text"),
                Token(text: "property1", kind: "identifier"),
                Token(text: ": String", kind: "text"),
              ]),
              Declaration(tokens: [
                Token(text: "var", kind: "keyword"),
                Token(text: " ", kind: "text"),
                Token(text: "property2", kind: "identifier"),
                Token(text: ": Int", kind: "text"),
              ]),
            ])
        ]
      )
      let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
      #expect(result.contains("```swift\nvar property1: String\n```"))
      #expect(result.contains("```swift\nvar property2: Int\n```"))
    }

    @Test("Renders Objective-C declarations with objc fence")
    func objectiveCDeclaration() {
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(title: "Objective-C Declaration"),
        primaryContentSections: [
          PrimaryContentSection(
            kind: "declarations",
            declarations: [
              Declaration(
                tokens: [
                  Token(text: "@interface Foo : NSObject", kind: "text")
                ],
                languages: ["occ"])
            ])
        ]
      )
      let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
      #expect(result.contains("```objc\n@interface Foo : NSObject\n```"))
    }

    @Test("Handles empty or malformed token arrays")
    func malformedTokens() {
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(title: "Malformed Declarations"),
        primaryContentSections: [
          PrimaryContentSection(
            kind: "declarations",
            declarations: [
              Declaration(tokens: []),
              Declaration(tokens: [Token(text: nil, kind: "text")]),
              Declaration(tokens: nil),
            ])
        ]
      )
      let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
      #expect(result.contains("# Malformed Declarations"))
    }
  }

  @Suite("Aside/Callout Mapping")
  struct AsideMapping {
    @Test("Maps aside styles to proper GitHub callouts")
    func asideStyles() {
      let styles: [(style: String, expected: String)] = [
        ("warning", "[!WARNING]"),
        ("important", "[!IMPORTANT]"),
        ("caution", "[!CAUTION]"),
        ("tip", "[!TIP]"),
        ("deprecated", "[!WARNING]"),
        ("note", "[!NOTE]"),
        ("unknown", "[!NOTE]"),
      ]

      for (style, expected) in styles {
        let data = AppleDocJSON(
          metadata: DocumentationMetadata(title: "\(style) Test"),
          primaryContentSections: [
            PrimaryContentSection(
              kind: "content",
              content: [
                ContentItem(
                  type: "aside",
                  content: [
                    ContentItem(
                      type: "paragraph",
                      inlineContent: [
                        ContentItem(text: "This is a \(style) aside.", type: "text")
                      ])
                  ], style: style)
              ])
          ]
        )
        let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
        #expect(result.contains("> \(expected)"))
        #expect(result.contains("> This is a \(style) aside."))
      }
    }

    @Test("Handles aside without style (defaults to note)")
    func defaultAside() {
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(title: "Default Aside"),
        primaryContentSections: [
          PrimaryContentSection(
            kind: "content",
            content: [
              ContentItem(
                type: "aside",
                content: [
                  ContentItem(
                    type: "paragraph",
                    inlineContent: [
                      ContentItem(text: "Default aside content.", type: "text")
                    ])
                ])
            ])
        ]
      )
      let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
      #expect(result.contains("> [!NOTE]"))
      #expect(result.contains("> Default aside content."))
    }
  }

  @Suite("Deprecation Rendering")
  struct DeprecationRendering {
    @Test("Marks deprecated symbols in front matter and renders summary")
    func deprecationSummary() {
      let symbolID = "doc://com.example/documentation/Example/legacy()"
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(title: "legacy()"),
        identifier: DocumentationIdentifier(url: symbolID, interfaceLanguage: nil),
        abstract: [ContentItem(text: "A legacy API.", type: "text")],
        deprecationSummary: [
          ContentItem(
            type: "paragraph",
            inlineContent: [
              ContentItem(text: "Use ", type: "text"),
              ContentItem(
                type: "reference", title: "modern()",
                identifier: "doc://com.example/documentation/Example/modern()"),
              ContentItem(text: " instead.", type: "text"),
            ])
        ],
        references: [
          "doc://com.example/documentation/Example/modern()": ContentItem(
            url: "/documentation/Example/modern()")
        ]
      )

      let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
      #expect(result.contains("deprecated: true"))
      #expect(result.contains("> [!WARNING]"))
      #expect(result.contains("> **Deprecated**"))
      #expect(result.contains("[modern()](/documentation/Example/modern()) instead."))
    }

    @Test("Uses platform deprecation message without summary")
    func platformDeprecationMessage() {
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(
          title: "legacyMethod()",
          platforms: [
            Platform(
              name: "iOS",
              introducedAt: "2.0",
              deprecatedAt: "8.0",
              message: "Use modernMethod() instead.")
          ]),
        abstract: [ContentItem(text: "A legacy API.", type: "text")]
      )

      let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
      #expect(result.contains("deprecated: true"))
      #expect(result.contains("> Use modernMethod() instead."))
    }

    @Test("Uses default message when self reference is deprecated")
    func deprecatedSelfReference() {
      let symbolID = "doc://com.example/documentation/Example/legacy()"
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(title: "legacy()"),
        identifier: DocumentationIdentifier(url: symbolID, interfaceLanguage: nil),
        references: [
          symbolID: ContentItem(title: "legacy()", deprecated: true)
        ]
      )

      let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
      #expect(result.contains("deprecated: true"))
      #expect(result.contains("> This symbol is deprecated."))
    }
  }

  @Suite("URL Conversion")
  struct URLConversion {
    @Test("Converts SwiftUI doc identifiers to proper URLs")
    func swiftUIIdentifiers() {
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(title: "URL Conversion Test"),
        primaryContentSections: [
          PrimaryContentSection(
            kind: "content",
            content: [
              ContentItem(
                type: "paragraph",
                inlineContent: [
                  ContentItem(
                    type: "reference", title: "View",
                    identifier: "doc://com.apple.SwiftUI/documentation/SwiftUI/View")
                ])
            ])
        ]
      )
      let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
      #expect(result.contains("[View](/documentation/SwiftUI/View)"))
    }

    @Test("Handles other Apple framework identifiers")
    func otherFrameworks() {
      let identifiers: [(id: String, expected: String)] = [
        (
          "doc://com.apple.Foundation/documentation/Foundation/NSString",
          "/documentation/Foundation/NSString"
        ),
        ("doc://com.apple.Swift/documentation/Swift/Array", "/documentation/Swift/Array"),
        ("doc://com.apple.UIKit/documentation/UIKit/UIView", "/documentation/UIKit/UIView"),
      ]

      for (id, expected) in identifiers {
        let data = AppleDocJSON(
          metadata: DocumentationMetadata(title: "Identifier Test"),
          primaryContentSections: [
            PrimaryContentSection(
              kind: "content",
              content: [
                ContentItem(
                  type: "paragraph",
                  inlineContent: [
                    ContentItem(type: "reference", title: "Test Reference", identifier: id)
                  ])
              ])
          ]
        )
        let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
        #expect(result.contains("[Test Reference](\(expected))"))
      }
    }

    @Test("Uses reference URL when available")
    func referenceURL() {
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(title: "Reference URL Test"),
        primaryContentSections: [
          PrimaryContentSection(
            kind: "content",
            content: [
              ContentItem(
                type: "paragraph",
                inlineContent: [
                  ContentItem(
                    type: "reference", title: "Test Reference",
                    identifier: "doc://test/ref")
                ])
            ])
        ],
        references: [
          "doc://test/ref": ContentItem(title: "Reference Title", url: "https://custom.url/path")
        ]
      )
      let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
      #expect(result.contains("[Test Reference](https://custom.url/path)"))
    }

    @Test("Falls back to identifier when no reference URL available")
    func fallbackToIdentifier() {
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(title: "Fallback Test"),
        primaryContentSections: [
          PrimaryContentSection(
            kind: "content",
            content: [
              ContentItem(
                type: "paragraph",
                inlineContent: [
                  ContentItem(
                    type: "reference", title: "Unknown Reference",
                    identifier: "unknown://identifier/format")
                ])
            ])
        ]
      )
      let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
      #expect(result.contains("[Unknown Reference](unknown://identifier/format)"))
    }
  }

  @Suite("Title Extraction from Identifiers")
  struct TitleExtraction {
    @Test("Extracts readable titles from method signatures")
    func methodSignatures() {
      let methodIdentifiers: [(id: String, expectedTitle: String)] = [
        ("doc://test/init(exactly:)-63925", "init(exactly:)"),
        ("doc://test/append(_:)-1234", "append(_:)"),
        ("doc://test/forEach(perform:)-abcd", "forEach(perform:)"),
      ]

      for (id, expectedTitle) in methodIdentifiers {
        let data = AppleDocJSON(
          metadata: DocumentationMetadata(title: "Title Extraction Test"),
          topicSections: [TopicSection(title: "Methods", identifiers: [id])]
        )
        let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
        #expect(result.contains("[\(expectedTitle)]"))
      }
    }

    @Test("Converts camelCase identifiers to readable format")
    func camelCase() {
      let identifiers: [(id: String, expectedTitle: String)] = [
        ("doc://test/somePropertyName", "some Property Name"),
        ("doc://test/anotherMethodName", "another Method Name"),
        ("doc://test/XMLHttpRequest", "XMLHttp Request"),
      ]

      for (id, expectedTitle) in identifiers {
        let data = AppleDocJSON(
          metadata: DocumentationMetadata(title: "CamelCase Test"),
          topicSections: [TopicSection(title: "Properties", identifiers: [id])]
        )
        let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
        #expect(result.contains("[\(expectedTitle)]"))
      }
    }

    @Test("Preserves method signatures with parentheses")
    func methodSignaturesPreserved() {
      let signatures = ["init()", "init(from:)", "append(_:)", "forEach(perform:)", "reduce(_:_:)"]

      for signature in signatures {
        let data = AppleDocJSON(
          metadata: DocumentationMetadata(title: "Method Signature Test"),
          topicSections: [TopicSection(title: "Methods", identifiers: ["doc://test/\(signature)"])]
        )
        let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
        #expect(result.contains("[\(signature)]"))
      }
    }
  }

  @Suite("Platform Information Rendering")
  struct PlatformInfo {
    @Test("Renders platform availability information")
    func platformAvailability() {
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(
          title: "Platform Test",
          platforms: [
            Platform(name: "iOS", introducedAt: "14.0"),
            Platform(name: "macOS", introducedAt: "11.0", beta: true),
            Platform(name: "watchOS", introducedAt: "7.0"),
          ]
        )
      )
      let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
      #expect(result.contains("**Available on:** iOS 14.0+, macOS 11.0+ Beta, watchOS 7.0+"))
    }

    @Test("Handles single platform")
    func singlePlatform() {
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(
          title: "Single Platform Test",
          platforms: [Platform(name: "iOS", introducedAt: "15.0")]
        )
      )
      let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
      #expect(result.contains("**Available on:** iOS 15.0+"))
    }

    @Test("Handles platforms without beta flag")
    func noBetaFlag() {
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(
          title: "Platform Without Flag Test",
          platforms: [Platform(name: "iOS", introducedAt: "13.0", beta: false)]
        )
      )
      let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
      #expect(result.contains("**Available on:** iOS 13.0+"))
      #expect(!result.contains(" Beta"))
    }
  }

  @Suite("Recursion Protection")
  struct RecursionProtection {
    @Test("Prevents infinite loops with deeply nested content")
    func deepContentNesting() {
      func createDeepContent(depth: Int) -> ContentItem {
        if depth <= 0 {
          return ContentItem(
            type: "paragraph",
            inlineContent: [
              ContentItem(text: "Bottom of the rabbit hole", type: "text")
            ])
        }
        return ContentItem(
          type: "aside", content: [createDeepContent(depth: depth - 1)], style: "note")
      }

      let data = AppleDocJSON(
        metadata: DocumentationMetadata(title: "Extreme Depth Test"),
        primaryContentSections: [
          PrimaryContentSection(kind: "content", content: [createDeepContent(depth: 55)])
        ]
      )
      let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
      #expect(result.contains("Extreme Depth Test"))
      #expect(result.contains("[Content too deeply nested]"))
    }

    @Test("Prevents infinite loops with deeply nested inline content")
    func deepInlineNesting() {
      func createDeepInline(depth: Int) -> ContentItem {
        if depth <= 0 {
          return ContentItem(text: "Deep inline text", type: "text")
        }
        return ContentItem(
          type: depth % 2 == 0 ? "emphasis" : "strong",
          inlineContent: [createDeepInline(depth: depth - 1)]
        )
      }

      let data = AppleDocJSON(
        metadata: DocumentationMetadata(title: "Extreme Inline Depth Test"),
        primaryContentSections: [
          PrimaryContentSection(
            kind: "content",
            content: [
              ContentItem(type: "paragraph", inlineContent: [createDeepInline(depth: 25)])
            ])
        ]
      )
      let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
      #expect(result.contains("Extreme Inline Depth Test"))
      #expect(result.contains("[Inline content too deeply nested]"))
    }

    @Test("Handles self-referencing emphasis/strong tags")
    func selfReferencingTags() {
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(title: "Self Reference Test"),
        primaryContentSections: [
          PrimaryContentSection(
            kind: "content",
            content: [
              ContentItem(
                type: "paragraph",
                inlineContent: [
                  ContentItem(
                    type: "emphasis",
                    inlineContent: [
                      ContentItem(
                        type: "strong",
                        inlineContent: [
                          ContentItem(
                            type: "emphasis",
                            inlineContent: [
                              ContentItem(text: "deeply nested", type: "text")
                            ])
                        ])
                    ])
                ])
            ])
        ]
      )
      let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
      #expect(result.contains("deeply nested"))
      #expect(result.contains("***"))
    }
  }

  @Suite("Performance")
  struct Performance {
    @Test("Completes complex rendering within reasonable time")
    func complexRendering() {
      let content = (0..<50).map { i in
        ContentItem(
          type: "paragraph",
          inlineContent: [
            ContentItem(text: "Paragraph \(i) with ", type: "text"),
            ContentItem(
              type: "reference", title: "Reference \(i)", identifier: "doc://test/ref\(i)"),
            ContentItem(
              type: "emphasis",
              inlineContent: [
                ContentItem(
                  type: "strong",
                  inlineContent: [
                    ContentItem(text: "nested content", type: "text")
                  ])
              ]),
          ])
      }

      var refs: [String: ContentItem] = [:]
      for i in 0..<50 {
        refs["doc://test/ref\(i)"] = ContentItem(title: "Reference \(i)", url: "/test/ref\(i)")
      }

      let data = AppleDocJSON(
        metadata: DocumentationMetadata(title: "Complex Document", roleHeading: "Framework"),
        primaryContentSections: [PrimaryContentSection(kind: "content", content: content)],
        references: refs
      )

      let start = Date()
      let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
      let elapsed = Date().timeIntervalSince(start)

      #expect(elapsed < 2.0)
      #expect(result.contains("Complex Document"))
      #expect(result.split(separator: "Paragraph").count > 45)
    }
  }

  @Suite("Circular References")
  struct CircularReferences {
    @Test("Handles circular references without infinite loop")
    func circularRefs() {
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(title: "Test Circular Reference", roleHeading: "Type"),
        abstract: [ContentItem(text: "A test type with circular references", type: "text")],
        primaryContentSections: [
          PrimaryContentSection(
            kind: "content",
            content: [
              ContentItem(
                type: "paragraph",
                inlineContent: [
                  ContentItem(text: "This references ", type: "text"),
                  ContentItem(
                    type: "reference", title: "Reference 1", identifier: "doc://test/ref1"),
                  ContentItem(text: " which has ", type: "text"),
                  ContentItem(
                    type: "emphasis",
                    inlineContent: [
                      ContentItem(
                        type: "reference", title: "Reference 2", identifier: "doc://test/ref2"),
                      ContentItem(
                        type: "strong",
                        inlineContent: [
                          ContentItem(
                            type: "reference", title: "Back to Reference 1",
                            identifier: "doc://test/ref1")
                        ]),
                    ]),
                ])
            ])
        ],
        references: [
          "doc://test/ref1": ContentItem(
            title: "Reference 1", url: "/test/ref1",
            abstract: [ContentItem(text: "This references ref2", type: "text")]),
          "doc://test/ref2": ContentItem(
            title: "Reference 2", url: "/test/ref2",
            abstract: [ContentItem(text: "This references ref1", type: "text")]),
        ]
      )
      let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
      #expect(result.contains("Test Circular Reference"))
      #expect(result.contains("Reference 1"))
      #expect(result.contains("Reference 2"))
    }
  }

  @Suite("Malformed Content")
  struct MalformedContent {
    @Test("Handles references to non-existent entries")
    func missingReferences() {
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(title: "Missing Reference Test"),
        primaryContentSections: [
          PrimaryContentSection(
            kind: "content",
            content: [
              ContentItem(
                type: "paragraph",
                inlineContent: [
                  ContentItem(
                    type: "reference", title: "Missing Reference",
                    identifier: "doc://test/nonexistent")
                ])
            ])
        ],
        references: [:]
      )
      let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
      #expect(result.contains("Missing Reference"))
    }

    @Test("Handles malformed inlineContent")
    func malformedInlineContent() {
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(title: "Malformed Content Test"),
        primaryContentSections: [
          PrimaryContentSection(
            kind: "content",
            content: [
              ContentItem(
                type: "paragraph",
                inlineContent: [
                  ContentItem(
                    type: "emphasis",
                    inlineContent: [
                      ContentItem(
                        type: "strong",
                        inlineContent: [
                          ContentItem(
                            type: "emphasis",
                            inlineContent: [
                              ContentItem(
                                type: "emphasis",
                                inlineContent: [
                                  ContentItem(text: "nested text", type: "text")
                                ])
                            ])
                        ])
                    ])
                ])
            ])
        ]
      )
      let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
      #expect(result.contains("nested text"))
    }
  }

  @Suite("Abstract rendering")
  struct AbstractRendering {
    private static let references: [String: ContentItem] = [
      "doc://com.apple.SwiftData/documentation/SwiftData/ResultsSection": ContentItem(
        title: "ResultsSection",
        url: "/documentation/swiftdata/resultssection",
        kind: "symbol"
      ),
      "doc://com.apple.SwiftData/documentation/SwiftData/SectionedResults/sections": ContentItem(
        title: "sections",
        url: "/documentation/swiftdata/sectionedresults/sections",
        abstract: [
          ContentItem(text: "The ", type: "text"),
          ContentItem(type: "codeVoice", code: .single("ResultsSection")),
          ContentItem(text: " values.", type: "text"),
        ],
        kind: "symbol"
      ),
    ]

    private static let abstract: [ContentItem] = [
      ContentItem(text: "A ", type: "text"),
      ContentItem(type: "codeVoice", code: .single("RandomAccessCollection")),
      ContentItem(text: " of ", type: "text"),
      ContentItem(
        type: "reference",
        identifier: "doc://com.apple.SwiftData/documentation/SwiftData/ResultsSection"),
      ContentItem(text: " instances.", type: "text"),
    ]

    @Test("Keeps code spans and references in the abstract")
    func abstractCodeAndReferences() {
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(title: "SectionedResults"),
        abstract: Self.abstract,
        references: Self.references
      )
      let result = DocumentRenderer.renderFromJSON(
        data, sourceURL: "https://developer.apple.com/documentation/swiftdata/sectionedresults")
      #expect(
        result.contains(
          "> A `RandomAccessCollection` of [ResultsSection](/documentation/swiftdata/resultssection) instances."
        ))
    }

    @Test("Keeps code and reference titles as plain text in the description")
    func plainDescription() {
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(title: "SectionedResults"),
        abstract: Self.abstract,
        references: Self.references
      )
      let result = DocumentRenderer.renderFromJSON(
        data, sourceURL: "https://developer.apple.com/documentation/swiftdata/sectionedresults")
      #expect(
        result.contains("description: A RandomAccessCollection of ResultsSection instances.\n"))
    }

    @Test("Keeps code spans in topic abstracts")
    func topicAbstractCodeSpans() {
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(title: "SectionedResults"),
        topicSections: [
          TopicSection(
            title: "Instance Properties",
            identifiers: [
              "doc://com.apple.SwiftData/documentation/SwiftData/SectionedResults/sections"
            ])
        ],
        references: Self.references
      )
      let result = DocumentRenderer.renderFromJSON(
        data, sourceURL: "https://developer.apple.com/documentation/swiftdata/sectionedresults")
      #expect(
        result.contains(
          "- [sections](/documentation/swiftdata/sectionedresults/sections) The `ResultsSection` values."
        ))
    }
  }

  @Suite("Platform availability")
  struct PlatformWithoutVersion {
    @Test("Shows a platform without a version by its name only")
    func nameOnly() throws {
      let json = """
        {
          "metadata": {
            "title": "autocorrectionType",
            "platforms": [
              {"name": "iOS", "introducedAt": "2.0"},
              {"name": "visionOS", "beta": true},
              {"name": "tvOS"}
            ]
          }
        }
        """.data(using: .utf8)!
      let data = try JSONDecoder().decode(AppleDocJSON.self, from: json)
      #expect(data.metadata?.platforms?[1].introducedAt == nil)
      #expect(data.metadata?.platforms?[2].introducedAt == nil)
      let result = DocumentRenderer.renderFromJSON(
        data,
        sourceURL:
          "https://developer.apple.com/documentation/uikit/uitextinputtraits/autocorrectiontype"
      )
      #expect(result.contains("**Available on:** iOS 2.0+, visionOS Beta, tvOS\n"))
      #expect(!result.contains("undefined"))
    }
  }

  @Suite("Objective-C pages")
  struct ObjectiveCPages {
    private static let swiftVariant = Variant.language(
      LanguageVariant(
        traits: [LanguageTrait(interfaceLanguage: "swift")],
        paths: ["/documentation/foundation/datecomponents"]
      )
    )
    private static let objcVariant = Variant.language(
      LanguageVariant(
        traits: [LanguageTrait(interfaceLanguage: "occ")],
        paths: ["/documentation/foundation/nsdatecomponents"]
      )
    )

    @Test("Links the Swift version of an Objective-C page")
    func linksSwiftVersion() {
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(title: "NSDateComponents"),
        identifier: DocumentationIdentifier(
          url: "doc://com.apple.foundation/documentation/Foundation/NSDateComponents",
          interfaceLanguage: "occ"
        ),
        variants: [Self.swiftVariant, Self.objcVariant]
      )
      let result = DocumentRenderer.renderFromJSON(
        data, sourceURL: "https://developer.apple.com/documentation/foundation/nsdatecomponents")
      #expect(
        result.contains(
          "> [!NOTE]\n> This page documents the Objective-C API. For the Swift API, see [/documentation/foundation/datecomponents](/documentation/foundation/datecomponents)."
        ))
    }

    @Test("Says when an Objective-C page has no Swift version")
    func noSwiftVersion() {
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(title: "era"),
        identifier: DocumentationIdentifier(
          url: "doc://com.apple.foundation/documentation/Foundation/NSDateComponents/era",
          interfaceLanguage: "occ"
        ),
        variants: [Self.objcVariant]
      )
      let result = DocumentRenderer.renderFromJSON(
        data, sourceURL: "https://developer.apple.com/documentation/foundation/nsdatecomponents/era"
      )
      #expect(
        result.contains(
          "> This page documents the Objective-C API. Apple's documentation doesn't link a Swift version of this symbol"
        ))
    }

    @Test("Does not add a note to a Swift page")
    func swiftPage() {
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(title: "DateComponents"),
        identifier: DocumentationIdentifier(
          url: "doc://com.apple.foundation/documentation/Foundation/DateComponents",
          interfaceLanguage: "swift"
        ),
        variants: [Self.swiftVariant, Self.objcVariant]
      )
      let result = DocumentRenderer.renderFromJSON(
        data, sourceURL: "https://developer.apple.com/documentation/foundation/datecomponents")
      #expect(!result.contains("Objective-C"))
    }
  }

  @Suite("Reference link titles")
  struct ReferenceLinkTitles {
    @Test("Uses the reference title for inline links without an inline title")
    func referenceTitle() {
      let url = "https://github.com/apple/foundation-models-utilities"
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(title: "Workaround Test"),
        primaryContentSections: [
          PrimaryContentSection(
            kind: "content",
            content: [
              ContentItem(
                type: "paragraph",
                inlineContent: [
                  ContentItem(text: "Import the ", type: "text"),
                  ContentItem(type: "reference", identifier: url),
                  ContentItem(text: " package.", type: "text"),
                ])
            ])
        ],
        references: [
          url: ContentItem(type: "link", title: "Foundation Models framework utilities", url: url)
        ]
      )
      let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
      #expect(result.contains("[Foundation Models framework utilities](\(url))"))
      #expect(!result.contains("[foundation-models]"))
    }

    @Test("Preserves code spans in inline link text via titleInlineContent")
    func titleInlineContent() {
      let url =
        "https://developer.apple.com/documentation/storekit/transaction/revocationtype-swift.property"
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(title: "Release Notes"),
        primaryContentSections: [
          PrimaryContentSection(
            kind: "content",
            content: [
              ContentItem(
                type: "paragraph",
                inlineContent: [
                  ContentItem(text: "New fields ", type: "text"),
                  ContentItem(type: "reference", identifier: url),
                  ContentItem(text: " have been added.", type: "text"),
                ])
            ])
        ],
        references: [
          url: ContentItem(
            type: "link",
            title: "revocationType",
            titleInlineContent: [ContentItem(type: "codeVoice", code: .single("revocationType"))],
            url: url
          )
        ]
      )
      let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
      #expect(result.contains("[`revocationType`](\(url))"))
    }

    @Test("Backticks inline symbol links that lack titleInlineContent")
    func symbolWithoutRichTitle() {
      let id =
        "doc://com.apple.documentation/documentation/Metal/MTLAccelerationStructure/gpuResourceID"
      let url = "/documentation/Metal/MTLAccelerationStructure/gpuResourceID"
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(title: "Release Notes"),
        primaryContentSections: [
          PrimaryContentSection(
            kind: "content",
            content: [
              ContentItem(
                type: "paragraph",
                inlineContent: [
                  ContentItem(text: "Use ", type: "text"),
                  ContentItem(type: "reference", identifier: id),
                  ContentItem(text: " instead.", type: "text"),
                ])
            ])
        ],
        references: [
          id: ContentItem(
            type: "topic", title: "gpuResourceID", identifier: id, url: url, role: "symbol",
            kind: "symbol")
        ]
      )
      let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
      #expect(result.contains("[`gpuResourceID`](\(url))"))
    }

    @Test("Does not backtick collection references")
    func collectionReference() {
      let id = "doc://com.apple.documentation/documentation/StoreKit"
      let url = "/documentation/StoreKit"
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(title: "Release Notes"),
        primaryContentSections: [
          PrimaryContentSection(
            kind: "content",
            content: [
              ContentItem(
                type: "paragraph",
                inlineContent: [
                  ContentItem(text: "See ", type: "text"),
                  ContentItem(type: "reference", identifier: id),
                  ContentItem(text: ".", type: "text"),
                ])
            ])
        ],
        references: [
          id: ContentItem(
            type: "topic", title: "StoreKit", identifier: id, url: url, role: "collection",
            kind: "symbol")
        ]
      )
      let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
      #expect(result.contains("[StoreKit](\(url))"))
      #expect(!result.contains("[`StoreKit`]"))
    }

    @Test("Backticks symbol links in topic sections")
    func topicSymbolLinks() {
      let id = "doc://test/HStack"
      let url = "/documentation/SwiftUI/HStack"
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(title: "SwiftUI"),
        topicSections: [TopicSection(title: "Containers", identifiers: [id])],
        references: [
          id: ContentItem(
            type: "topic", title: "HStack", identifier: id, url: url, role: "symbol",
            kind: "symbol")
        ]
      )
      let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
      #expect(result.contains("- [`HStack`](\(url))"))
    }
  }

  @Suite("Topic Sections")
  struct UntitledTopicSections {
    @Test("Renders topic sections that have no title")
    func missingTitle() throws {
      let json = """
        {
          "metadata": {"title": "Migration Guide"},
          "topicSections": [
            {"identifiers": ["doc://test/DataRaceSafety", "doc://test/MigrationStrategy"]},
            {"title": "Swift Concurrency in Depth", "identifiers": ["doc://test/RuntimeBehavior"]}
          ]
        }
        """.data(using: .utf8)!
      let data = try JSONDecoder().decode(AppleDocJSON.self, from: json)
      let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
      #expect(result.contains("[Data Race Safety]"))
      #expect(result.contains("[Migration Strategy]"))
      #expect(result.contains("## Swift Concurrency in Depth"))
      #expect(result.contains("[Runtime Behavior]"))
    }
  }

  @Suite("Relationships")
  struct ConditionalRelationships {
    private static func hashableCondition() -> ConformanceInfo {
      ConformanceInfo(
        constraints: [
          ContentItem(type: "codeVoice", code: .single("Element")),
          ContentItem(text: " conforms to ", type: "text"),
          ContentItem(type: "codeVoice", code: .single("Hashable")),
          ContentItem(text: ".", type: "text"),
        ],
        conformancePrefix: [ContentItem(text: "Conforms when", type: "text")],
        availabilityPrefix: [ContentItem(text: "Available when", type: "text")]
      )
    }

    @Test("Renders the conditions of a conditional conformance")
    func conditionalConformance() {
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(title: "LanguageModelSession.SessionProperty"),
        relationshipsSections: [
          ContentItem(
            type: "conformsTo", title: "Conforms To",
            identifiers: ["doc://test/Sendable", "doc://test/SendableMetatype"],
            kind: "relationships")
        ],
        references: [
          "doc://test/Sendable": ContentItem(
            type: "topic",
            title: "Sendable",
            url: "/documentation/swift/sendable",
            role: "symbol",
            conformance: ConformanceInfo(
              constraints: [
                ContentItem(type: "codeVoice", code: .single("Value")),
                ContentItem(text: " conforms to ", type: "text"),
                ContentItem(type: "codeVoice", code: .single("Sendable")),
                ContentItem(text: ".", type: "text"),
              ],
              conformancePrefix: [ContentItem(text: "Conforms when", type: "text")],
              availabilityPrefix: [ContentItem(text: "Available when", type: "text")]
            )
          ),
          "doc://test/SendableMetatype": ContentItem(
            type: "topic",
            title: "SendableMetatype",
            url: "/documentation/swift/sendablemetatype",
            role: "symbol"
          ),
        ]
      )
      let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
      #expect(
        result.contains(
          "- [`Sendable`](/documentation/swift/sendable) Conforms when `Value` conforms to `Sendable`.\n"
        ))
      #expect(
        result.contains("- [`SendableMetatype`](/documentation/swift/sendablemetatype)\n"))
    }

    @Test("Renders the conditions of conditionally available members")
    func conditionalMembers() {
      let condition = Self.hashableCondition()
      let data = AppleDocJSON(
        metadata: DocumentationMetadata(title: "Array"),
        topicSections: [
          TopicSection(
            title: "Hashing", identifiers: ["doc://test/hash(into:)", "doc://test/count"])
        ],
        seeAlsoSections: [
          SeeAlsoSection(title: "Related", identifiers: ["doc://test/hashValue"])
        ],
        references: [
          "doc://test/hash(into:)": ContentItem(
            type: "topic",
            title: "hash(into:)",
            url: "/documentation/swift/array/hash(into:)",
            abstract: [
              ContentItem(text: "Hashes the essential components of this value.", type: "text")
            ],
            role: "symbol",
            conformance: condition
          ),
          "doc://test/count": ContentItem(
            type: "topic",
            title: "count",
            url: "/documentation/swift/array/count",
            abstract: [ContentItem(text: "The number of elements in the array.", type: "text")],
            role: "symbol"
          ),
          "doc://test/hashValue": ContentItem(
            type: "topic",
            title: "hashValue",
            url: "/documentation/swift/array/hashvalue",
            role: "symbol",
            conformance: condition
          ),
        ]
      )
      let result = DocumentRenderer.renderFromJSON(data, sourceURL: "https://test.com")
      #expect(
        result.contains(
          "- [`hash(into:)`](/documentation/swift/array/hash(into:)) Hashes the essential components of this value. Available when `Element` conforms to `Hashable`.\n"
        ))
      #expect(
        result.contains(
          "- [`count`](/documentation/swift/array/count) The number of elements in the array.\n"))
      #expect(
        result.contains(
          "- [`hashValue`](/documentation/swift/array/hashvalue) Available when `Element` conforms to `Hashable`.\n"
        ))
    }
  }
}
