import Foundation
import SwiftData

/// An article we've discovered exists (by scraping an issue TOC page).
/// Distinct from ReadArticle, which tracks any URL the user has actually viewed.
/// An issue is "complete" when every Article whose issuePath matches is in ReadArticle.
@Model
final class Article {
    @Attribute(.unique) var urlString: String
    var issuePath: String
    var discoveredAt: Date

    init(urlString: String, issuePath: String, discoveredAt: Date = .now) {
        self.urlString = urlString
        self.issuePath = issuePath
        self.discoveredAt = discoveredAt
    }
}

extension URL {
    /// Strip query and fragment so a URL with #footnotes matches one without.
    var canonicalArticleString: String {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.fragment = nil
        components?.query = nil
        return components?.url?.absoluteString ?? absoluteString
    }

    /// /the-paper/v48/n09/john/article → /the-paper/v48/n09
    /// /the-paper/v48/n09/letters    → /the-paper/v48/n09
    /// Returns nil for paths that don't fit the issue/article shape.
    var lrbIssuePath: String? {
        let parts = path.split(separator: "/").map(String.init)
        guard parts.count >= 4,
              parts[0] == "the-paper",
              parts[1].hasPrefix("v"),
              parts[2].hasPrefix("n") else { return nil }
        return "/\(parts[0])/\(parts[1])/\(parts[2])"
    }
}
