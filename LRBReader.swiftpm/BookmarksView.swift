import SwiftUI
import SwiftData

struct BookmarksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bookmark.addedAt, order: .reverse) private var bookmarks: [Bookmark]

    var body: some View {
        NavigationStack {
            Group {
                if bookmarks.isEmpty {
                    ContentUnavailableView(
                        "No bookmarks yet",
                        systemImage: "bookmark",
                        description: Text("Tap the bookmark icon while reading to save a page.")
                    )
                } else {
                    List {
                        ForEach(bookmarks) { bookmark in
                            NavigationLink(value: bookmark.url) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(bookmark.title)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                    Text(bookmark.url.absoluteString)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Bookmarks")
            .navigationDestination(for: URL.self) { url in
                ReaderView(initialURL: url, canDismiss: true)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(bookmarks[index])
        }
    }
}
