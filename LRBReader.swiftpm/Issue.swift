import Foundation
import SwiftData

@Model
final class Issue {
    @Attribute(.unique) var path: String
    var volume: Int
    var number: Int
    var fetchedAt: Date
    /// Set once we've fetched and parsed this issue's TOC. Until then, we don't
    /// know the article list, so progress counts are meaningless.
    var articlesFetchedAt: Date?

    init(volume: Int, number: Int, fetchedAt: Date = .now) {
        self.volume = volume
        self.number = number
        self.fetchedAt = fetchedAt
        self.path = Self.makePath(volume: volume, number: number)
    }

    static func makePath(volume: Int, number: Int) -> String {
        "/the-paper/v\(String(format: "%02d", volume))/n\(String(format: "%02d", number))"
    }

    var url: URL { URL(string: "https://www.lrb.co.uk\(path)")! }
    var year: Int { Self.year(forVolume: volume) }
    var label: String { "Vol. \(volume) No. \(number)" }

    static func year(forVolume volume: Int) -> Int { 1978 + volume }
    static func volume(forYear year: Int) -> Int { year - 1978 }
}
