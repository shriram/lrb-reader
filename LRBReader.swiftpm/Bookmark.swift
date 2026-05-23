import Foundation
import SwiftData

@Model
final class Bookmark {
    var url: URL
    var title: String
    var addedAt: Date

    init(url: URL, title: String, addedAt: Date = .now) {
        self.url = url
        self.title = title
        self.addedAt = addedAt
    }
}
