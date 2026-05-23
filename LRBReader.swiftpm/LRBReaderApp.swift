import SwiftUI
import SwiftData

@main
struct LRBReaderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Bookmark.self, Issue.self, ReadArticle.self, Article.self])
    }
}
