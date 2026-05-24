import Foundation
import SwiftData

@Model
final class ReadArticle {
    @Attribute(.unique) var urlString: String
    var readAt: Date

    init(url: URL, readAt: Date = .now) {
        self.urlString = url.canonicalArticleString
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

    /// True if this URL is exactly an issue's table-of-contents page (3 parts).
    var isLRBIssueTOC: Bool {
        guard host?.contains("lrb.co.uk") == true else { return false }
        let parts = path.split(separator: "/").map(String.init)
        return parts.count == 3
            && parts[0] == "the-paper"
            && parts[1].hasPrefix("v")
            && parts[2].hasPrefix("n")
    }

    /// If this URL is an issue TOC, returns its canonical issue path; else nil.
    var issueTOCPath: String? {
        guard isLRBIssueTOC else { return nil }
        let parts = path.split(separator: "/").map(String.init)
        return "/\(parts[0])/\(parts[1])/\(parts[2])"
    }

    /// True for LRB blog post URLs: /blog/YYYY/{month}/{slug}.
    /// Excludes /blog/ index, /blog/author/..., /blog/archive, /blog/contributors.
    var isLRBBlogPost: Bool {
        guard host?.contains("lrb.co.uk") == true else { return false }
        let parts = path.split(separator: "/").map(String.init)
        guard parts.count >= 4, parts[0] == "blog" else { return false }
        return Int(parts[1]) != nil // year component must be numeric
    }

    /// Anything we treat as "a piece you can read" — for the 5-second dwell
    /// timer and the mark-as-read toolbar button. Read URLs themselves can
    /// be anything (the JS indicator styles whatever's in the set); this is
    /// the gate for *triggering* a read mark.
    var isLRBReadable: Bool { isLRBArticle || isLRBBlogPost }
}
