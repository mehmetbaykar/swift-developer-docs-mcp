import Foundation
import SwiftSoup

public struct SearchResult: Codable, Sendable {
    public let title: String
    public let url: String
    public let description: String
    public let breadcrumbs: [String]
    public let tags: [String]
    public let type: String
}

public struct SearchResponse: Codable, Sendable {
    public let query: String
    public let results: [SearchResult]
}

public struct AppleDocsSearcher: Sendable {
    public static func search(query: String) async throws -> SearchResponse {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let searchUrl = "https://developer.apple.com/search/?q=\(encoded)"

        guard let url = URL(string: searchUrl) else {
            return SearchResponse(query: query, results: [])
        }

        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            return SearchResponse(query: query, results: [])
        }
        guard let html = String(data: data, encoding: .utf8) else {
            return SearchResponse(query: query, results: [])
        }

        let doc = try SwiftSoup.parse(html)
        let searchResults = try doc.select("li")
        var results: [SearchResult] = []

        for element in searchResults {
            let className = try element.className()
            guard className.contains("search-result") else { continue }

            let type: String
            if className.contains("documentation") {
                type = "documentation"
            } else if className.contains("general") {
                type = "general"
            } else {
                type = "other"
            }

            let link = try element.select("a.click-analytics-result").first()
            guard let link else { continue }

            var href = try link.attr("href")
            if href.hasPrefix("/") {
                href = "https://developer.apple.com\(href)"
            }

            let title = try link.text().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }

            let description = try element.select("p.result-description").first()?.text() ?? ""

            var breadcrumbs: [String] = []
            let breadcrumbElements = try element.select("li.breadcrumb-list-item")
            for bc in breadcrumbElements {
                let text = try bc.text().trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { breadcrumbs.append(text) }
            }

            var tags: [String] = []
            let tagElements = try element.select("li.result-tag")
            for tag in tagElements {
                let text = try tag.text().trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { tags.append(text) }
            }

            results.append(SearchResult(
                title: title,
                url: href,
                description: description,
                breadcrumbs: breadcrumbs,
                tags: tags,
                type: type
            ))
        }

        return SearchResponse(query: query, results: results)
    }
}
