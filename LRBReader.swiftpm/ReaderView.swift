import SwiftUI
import SwiftData

struct ReaderView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bookmark.addedAt, order: .reverse) private var bookmarks: [Bookmark]
    @Query private var readArticles: [ReadArticle]
    @Query private var articles: [Article]
    @Query private var issues: [Issue]

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
                onMarkRead: markRead,
                onDiscoverArticles: discoverArticles
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
                        Label("Back", systemImage: backIconName)
                    }
                    .disabled(!backEnabled)

                    Button {
                        webState.pendingAction = .goForward
                    } label: {
                        Label("Forward", systemImage: "chevron.right")
                    }
                    .disabled(!webState.canGoForward)
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        webState.pendingAction = .reload
                    } label: {
                        Label("Reload", systemImage: "arrow.clockwise")
                    }

                    Button {
                        toggleReadStatus()
                    } label: {
                        Label(isCurrentRead ? "Mark Unread" : "Mark Read",
                              systemImage: isCurrentRead ? "archivebox.fill" : "archivebox")
                    }
                    .disabled(!currentIsArticle)

                    Button {
                        toggleBookmark()
                    } label: {
                        Label(isCurrentBookmarked ? "Remove Bookmark" : "Bookmark",
                              systemImage: isCurrentBookmarked ? "bookmark.fill" : "bookmark")
                    }
                    .disabled(webState.currentURL == nil)

                    ShareLink(
                        item: webState.currentURL ?? URL(string: "https://www.lrb.co.uk")!,
                        subject: Text(webState.currentTitle),
                        preview: SharePreview(webState.currentTitle.isEmpty
                                              ? "London Review of Books"
                                              : webState.currentTitle)
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
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

    private var currentIsArticle: Bool {
        webState.currentURL?.isLRBReadable == true
    }

    private var isCurrentRead: Bool {
        guard let url = webState.currentURL else { return false }
        let key = url.canonicalArticleString
        return readArticles.contains { $0.urlString == key }
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

    private func toggleReadStatus() {
        guard let url = webState.currentURL else { return }
        let key = url.canonicalArticleString
        if let existing = readArticles.first(where: { $0.urlString == key }) {
            modelContext.delete(existing)
        } else {
            // Reuse markRead so we go through the same insert + ensure-Article path.
            markRead(url)
        }
    }

    private func markRead(_ url: URL) {
        let key = url.canonicalArticleString
        if !readArticles.contains(where: { $0.urlString == key }) {
            modelContext.insert(ReadArticle(url: url))
        }
        // Also ensure an Article record exists, so this single read counts toward
        // its issue's completeness even if we never opened the TOC.
        if let issuePath = url.lrbIssuePath,
           !articles.contains(where: { $0.urlString == key }) {
            modelContext.insert(Article(urlString: key, issuePath: issuePath))
        }
    }

    private func discoverArticles(from pageURL: URL, urls: [URL]) {
        let existing = Set(articles.map(\.urlString))
        for url in urls {
            let key = url.canonicalArticleString
            guard !existing.contains(key), let issuePath = url.lrbIssuePath else { continue }
            modelContext.insert(Article(urlString: key, issuePath: issuePath))
        }
        // If we're on an issue's TOC, this visit gives us the full article list
        // for that issue. Mark it loaded so counts appear immediately, regardless
        // of whether the background year-fetch ran or succeeded.
        if let tocPath = pageURL.issueTOCPath,
           let issue = issues.first(where: { $0.path == tocPath }),
           issue.articlesFetchedAt == nil {
            issue.articlesFetchedAt = .now
        }
    }
}
