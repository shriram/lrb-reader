import Foundation
import SwiftData

@Model
final class BlogPost {
    @Attribute(.unique) var urlString: String
    var title: String
    var author: String
    var publishedAt: Date?
    /// Position in the most recent feed fetch (0 = newest).
    var orderIndex: Int
    var discoveredAt: Date

    init(urlString: String,
         title: String,
         author: String,
         publishedAt: Date?,
         orderIndex: Int,
         discoveredAt: Date = .now) {
        self.urlString = urlString
        self.title = title
        self.author = author
        self.publishedAt = publishedAt
        self.orderIndex = orderIndex
        self.discoveredAt = discoveredAt
    }
}
