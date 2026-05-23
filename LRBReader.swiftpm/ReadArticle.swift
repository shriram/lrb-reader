import Foundation
import SwiftData

@Model
final class ReadArticle {
    @Attribute(.unique) var urlString: String
    var readAt: Date

    init(url: URL, readAt: Date = .now) {
        self.urlString = url.absoluteString
        self.readAt = readAt
    }
}

extension URL {
    /// True if this looks like an LRB article URL (not an issue TOC, not a contributor page).
    /// Issue TOC: /the-paper/v{NN}/n{NN} (3 parts).
    /// Article:   /the-paper/v{NN}/n{NN}/{author}/{title} (5 parts) or
    ///            /the-paper/v{NN}/n{NN}/{section} like "letters" (4 parts).
    /// So: anything deeper than the issue TOC counts.
    var isLRBArticle: Bool {
        guard host?.contains("lrb.co.uk") == true else { return false }
        let parts = path.split(separator: "/").map(String.init)
        guard parts.count >= 4 else { return false }
        return parts[0] == "the-paper"
            && parts[1].hasPrefix("v")
            && parts[2].hasPrefix("n")
    }
}
