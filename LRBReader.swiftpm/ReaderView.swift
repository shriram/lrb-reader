import SwiftUI
import SwiftData

struct ReaderView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bookmark.addedAt, order: .reverse) private var bookmarks: [Bookmark]
    @Query private var readArticles: [ReadArticle]

    let initialURL: URL
    let sessionId: UUID
    let originTab: ContentView.Tab?
    let onReturnToOrigin: (ContentView.Tab) -> Void

    @State private var webState = WebViewState()

    private var readUrlSet: Set<String> { Set(readArticles.map(\.urlString)) }

    var body: some View {
        NavigationStack {
            WebView(
                state: webState,
                initialURL: initialURL,
                readUrls: readUrlSet,
                onMarkRead: markRead
            )
            .ignoresSafeArea(edges: .bottom)
            .id(sessionId)
            .navigationTitle(webState.currentTitle.isEmpty ? "London Review of Books" : webState.currentTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button {
                        handleBack()
                    } label: {
                        Image(systemName: backIconName)
                    }
                    .disabled(!backEnabled)

                    Button {
                        webState.pendingAction = .goForward
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(!webState.canGoForward)
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        webState.pendingAction = .reload
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }

                    Button {
                        toggleBookmark()
                    } label: {
                        Image(systemName: isCurrentBookmarked ? "bookmark.fill" : "bookmark")
                    }
                    .disabled(webState.currentURL == nil)
                }
            }
        }
    }

    private var backEnabled: Bool {
        webState.canGoBack || originTab != nil
    }

    private var backIconName: String {
        // When at the bottom of WebView history and we came from another tab,
        // surface a different glyph so the action ("return to Issues") is clearer.
        if webState.canGoBack { return "chevron.left" }
        if originTab != nil { return "arrow.uturn.left" }
        return "chevron.left"
    }

    private func handleBack() {
        if webState.canGoBack {
            webState.pendingAction = .goBack
        } else if let tab = originTab {
            onReturnToOrigin(tab)
        }
    }

    private var isCurrentBookmarked: Bool {
        guard let url = webState.currentURL else { return false }
        return bookmarks.contains { $0.url == url }
    }

    private func toggleBookmark() {
        guard let url = webState.currentURL else { return }
        if let existing = bookmarks.first(where: { $0.url == url }) {
            modelContext.delete(existing)
        } else {
            let title = webState.currentTitle.isEmpty ? url.absoluteString : webState.currentTitle
            modelContext.insert(Bookmark(url: url, title: title))
        }
    }

    private func markRead(_ url: URL) {
        let key = url.absoluteString
        if readArticles.contains(where: { $0.urlString == key }) { return }
        modelContext.insert(ReadArticle(url: url))
    }
}
