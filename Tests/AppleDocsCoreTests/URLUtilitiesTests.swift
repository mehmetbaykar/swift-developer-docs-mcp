import Testing

@testable import AppleDocsCore

@Suite("URL Utilities")
struct URLUtilitiesTests {
  @Suite("Basic Path Normalization")
  struct BasicNormalization {
    @Test("Normalizes simple paths")
    func simplePaths() {
      #expect(URLUtilities.normalizeDocumentationPath("swift/array") == "swift/array")
      #expect(URLUtilities.normalizeDocumentationPath("swiftui/view") == "swiftui/view")
      #expect(URLUtilities.normalizeDocumentationPath("foundation/url") == "foundation/url")
    }

    @Test("Removes leading slashes")
    func leadingSlashes() {
      #expect(URLUtilities.normalizeDocumentationPath("/swift/array") == "swift/array")
      #expect(URLUtilities.normalizeDocumentationPath("//swiftui/view") == "/swiftui/view")
      #expect(URLUtilities.normalizeDocumentationPath("///foundation/url") == "//foundation/url")
    }

    @Test("Trims whitespace")
    func whitespace() {
      #expect(URLUtilities.normalizeDocumentationPath("  swift/array  ") == "swift/array")
      #expect(URLUtilities.normalizeDocumentationPath("\tswiftui/view\n") == "swiftui/view")
      #expect(
        URLUtilities.normalizeDocumentationPath("  \n  foundation/url  \t  ") == "foundation/url")
    }
  }

  @Suite("Documentation Prefix Handling")
  struct PrefixHandling {
    @Test("Removes documentation/ prefix")
    func withSlash() {
      #expect(URLUtilities.normalizeDocumentationPath("documentation/swift/array") == "swift/array")
      #expect(
        URLUtilities.normalizeDocumentationPath("documentation/swiftui/view") == "swiftui/view")
      #expect(
        URLUtilities.normalizeDocumentationPath("documentation/foundation/url") == "foundation/url")
    }

    @Test("Removes documentation prefix without trailing slash")
    func withoutSlash() {
      #expect(URLUtilities.normalizeDocumentationPath("documentationswift/array") == "swift/array")
      #expect(
        URLUtilities.normalizeDocumentationPath("documentationswiftui/view") == "swiftui/view")
      #expect(
        URLUtilities.normalizeDocumentationPath("documentationfoundation/url") == "foundation/url")
    }

    @Test("Handles mixed cases")
    func mixed() {
      #expect(
        URLUtilities.normalizeDocumentationPath("/documentation/swift/array") == "swift/array")
      #expect(
        URLUtilities.normalizeDocumentationPath("  documentation/swiftui/view  ") == "swiftui/view")
      #expect(
        URLUtilities.normalizeDocumentationPath("\tdocumentationfoundation/url\n")
          == "foundation/url")
    }
  }

  @Suite("Edge Cases")
  struct EdgeCases {
    @Test("Handles empty strings")
    func emptyStrings() {
      #expect(URLUtilities.normalizeDocumentationPath("") == "")
      #expect(URLUtilities.normalizeDocumentationPath("   ") == "")
      #expect(URLUtilities.normalizeDocumentationPath("\t\n") == "")
    }

    @Test("Handles single components")
    func singleComponents() {
      #expect(URLUtilities.normalizeDocumentationPath("swift") == "swift")
      #expect(URLUtilities.normalizeDocumentationPath("/swift") == "swift")
      #expect(URLUtilities.normalizeDocumentationPath("documentation/swift") == "swift")
      #expect(URLUtilities.normalizeDocumentationPath("/documentation/swift") == "swift")
    }

    @Test("Handles paths with multiple slashes")
    func multipleSlashes() {
      #expect(URLUtilities.normalizeDocumentationPath("swift//array") == "swift//array")
      #expect(URLUtilities.normalizeDocumentationPath("swift///array") == "swift///array")
      #expect(URLUtilities.normalizeDocumentationPath("/swift//array") == "swift//array")
    }

    @Test("Handles paths ending with slashes")
    func trailingSlashes() {
      #expect(URLUtilities.normalizeDocumentationPath("swift/array/") == "swift/array/")
      #expect(URLUtilities.normalizeDocumentationPath("/swift/array/") == "swift/array/")
      #expect(
        URLUtilities.normalizeDocumentationPath("documentation/swift/array/") == "swift/array/")
    }
  }

  @Suite("Real-World Examples")
  struct RealWorldExamples {
    @Test("Handles typical Apple documentation paths")
    func typicalPaths() {
      let testCases: [(input: String, expected: String)] = [
        ("swift/array", "swift/array"),
        ("swiftui/view", "swiftui/view"),
        ("foundation/nsstring", "foundation/nsstring"),
        ("/swift/array", "swift/array"),
        ("/swiftui/view", "swiftui/view"),
        ("documentation/swift/array", "swift/array"),
        ("documentation/swiftui/view", "swiftui/view"),
        ("/documentation/swift/array", "swift/array"),
        ("/documentation/swiftui/view", "swiftui/view"),
        ("  swift/array  ", "swift/array"),
        ("\tdocumentation/swiftui/view\n", "swiftui/view"),
        ("/documentation/swift/array/append", "swift/array/append"),
        ("documentation/foundation/nsstring/init", "foundation/nsstring/init"),
        ("  /documentation/swiftui/view/onappear  ", "swiftui/view/onappear"),
      ]

      for (input, expected) in testCases {
        #expect(URLUtilities.normalizeDocumentationPath(input) == expected)
      }
    }
  }

  @Suite("Preserves Valid Paths")
  struct PreservesValidPaths {
    @Test("Does not modify already normalized paths")
    func alreadyNormalized() {
      let validPaths = [
        "swift/array", "swiftui/view", "foundation/url",
        "swift/array/append", "swiftui/view/onappear", "foundation/nsstring/init",
      ]
      for path in validPaths {
        #expect(URLUtilities.normalizeDocumentationPath(path) == path)
      }
    }
  }

  @Suite("generateAppleDocURL")
  struct GenerateURL {
    @Test("Generates correct Apple Developer URLs")
    func correctURLs() {
      #expect(
        URLUtilities.generateAppleDocURL("swift/array")
          == "https://developer.apple.com/documentation/swift/array")
      #expect(
        URLUtilities.generateAppleDocURL("swiftui/view")
          == "https://developer.apple.com/documentation/swiftui/view")
      #expect(
        URLUtilities.generateAppleDocURL("foundation/url")
          == "https://developer.apple.com/documentation/foundation/url")
    }

    @Test("Handles empty paths")
    func emptyPath() {
      #expect(URLUtilities.generateAppleDocURL("") == "https://developer.apple.com/documentation/")
    }
  }

  @Suite("isValidAppleDocURL")
  struct ValidateURL {
    @Test("Validates correct Apple Developer URLs")
    func validURLs() {
      #expect(
        URLUtilities.isValidAppleDocURL("https://developer.apple.com/documentation/swift/array")
          == true)
      #expect(
        URLUtilities.isValidAppleDocURL("https://developer.apple.com/documentation/swiftui/view")
          == true)
      #expect(
        URLUtilities.isValidAppleDocURL("https://developer.apple.com/documentation/foundation/url")
          == true)
    }

    @Test("Rejects invalid URLs")
    func invalidURLs() {
      #expect(URLUtilities.isValidAppleDocURL("https://developer.apple.com/swift/array") == false)
      #expect(URLUtilities.isValidAppleDocURL("https://example.com/documentation/swift") == false)
      #expect(
        URLUtilities.isValidAppleDocURL("http://developer.apple.com/documentation/swift") == false)
      #expect(URLUtilities.isValidAppleDocURL("not-a-url") == false)
    }
  }

  @Suite("Normalize and Generate URL Workflow")
  struct Workflow {
    @Test("Normalizes path and generates valid URL")
    func basicWorkflow() {
      let normalizedPath = URLUtilities.normalizeDocumentationPath("/documentation/swift/array")
      let url = URLUtilities.generateAppleDocURL(normalizedPath)
      #expect(normalizedPath == "swift/array")
      #expect(url == "https://developer.apple.com/documentation/swift/array")
    }

    @Test("Handles various input formats")
    func variousFormats() {
      let testCases: [(input: String, expectedPath: String, expectedURL: String)] = [
        ("swift/array", "swift/array", "https://developer.apple.com/documentation/swift/array"),
        ("/swift/array", "swift/array", "https://developer.apple.com/documentation/swift/array"),
        (
          "documentation/swift/array", "swift/array",
          "https://developer.apple.com/documentation/swift/array"
        ),
        (
          "/documentation/swift/array", "swift/array",
          "https://developer.apple.com/documentation/swift/array"
        ),
        ("  swift/array  ", "swift/array", "https://developer.apple.com/documentation/swift/array"),
      ]

      for (input, expectedPath, expectedURL) in testCases {
        let normalizedPath = URLUtilities.normalizeDocumentationPath(input)
        let url = URLUtilities.generateAppleDocURL(normalizedPath)
        #expect(normalizedPath == expectedPath)
        #expect(url == expectedURL)
      }
    }

    @Test("Handles special characters in paths")
    func specialCharacters() {
      let normalizedPath = URLUtilities.normalizeDocumentationPath(
        "invalid/path/with/special/chars!@#")
      let url = URLUtilities.generateAppleDocURL(normalizedPath)
      #expect(normalizedPath == "invalid/path/with/special/chars!@#")
      #expect(url == "https://developer.apple.com/documentation/invalid/path/with/special/chars!@#")
    }
  }
}
