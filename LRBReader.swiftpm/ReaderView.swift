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
    @State private var pendingIssueArchive: Issue?

    /// The set of URLs that should appear as "read" in the UI. This is the
    /// union of:
    ///   - URLs the user actually marked read (auto-dwell, manual toggle, etc.)
    ///   - all articles known to belong to an archived issue
    ///
    /// Archive flips a single flag on Issue; we never insert ReadArticles for
    /// the bulk action. That way unarchive is a clean reverse and any reads
    /// the user did individually survive an archive/unarchive cycle.
    private var readUrlSet: Set<String> {
        var set = Set(readArticles.map(\.urlString))
        let archivedPaths = Set(issues.filter { $0.archivedAt != nil }.map(\.path))
        if !archivedPaths.isEmpty {
            for article in articles where archivedPaths.contains(article.issuePath) {
                set.insert(article.urlString)
            }
        }
        return set
    }

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
            .confirmationDialog(
                dialogTitle,
                isPresented: Binding(
                    get: { pendingIssueArchive != nil },
                    set: { if !$0 { pendingIssueArchive = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingIssueArchive
            ) { issue in
                if issue.archivedAt != nil {
                    Button("Unarchive (keep my reads)") {
                        issue.archivedAt = nil
                    }
                    Button("Unarchive (clear all reads)", role: .destructive) {
                        unarchiveAndResetReads(issue)
                    }
                } else {
                    Button("Archive", role: .destructive) {
                        archiveIssueFromReader(issue)
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
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
                        handleArchiveTap()
                    } label: {
                        Label(archiveLabel, systemImage: archiveIcon)
                    }
                    .disabled(!archiveEnabled)

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

    /// The Issue record matching the current page, IF the page is exactly an
    /// issue TOC and we already know about that issue.
    private var currentTOCIssue: Issue? {
        guard let url = webState.currentURL,
              let path = url.issueTOCPath else { return nil }
        return issues.first { $0.path == path }
    }

    private var archiveEnabled: Bool {
        currentIsArticle || currentTOCIssue != nil
    }

    private var archiveIcon: String {
        if let issue = currentTOCIssue {
            return issue.archivedAt != nil ? "archivebox.fill" : "archivebox"
        }
        return isCurrentRead ? "archivebox.fill" : "archivebox"
    }

    private var archiveLabel: String {
        if let issue = currentTOCIssue {
            return issue.archivedAt != nil ? "Unarchive Issue" : "Archive Issue"
        }
        return isCurrentRead ? "Mark Unread" : "Mark Read"
    }

    private func handleArchiveTap() {
        if let issue = currentTOCIssue {
            pendingIssueArchive = issue
        } else if currentIsArticle {
            toggleReadStatus()
        }
    }

    private var dialogTitle: String {
        guard let issue = pendingIssueArchive else { return "" }
        return issue.archivedAt != nil ? "Unarchive \(issue.label)?" : "Archive \(issue.label)?"
    }

    private func archiveIssueFromReader(_ issue: Issue) {
        // Just flip the flag — the effective-read computation will show every
        // article in the issue as read.
        issue.archivedAt = .now
    }

    private func unarchiveAndResetReads(_ issue: Issue) {
        issue.archivedAt = nil
        let issueURLs = Set(articles.filter { $0.issuePath == issue.path }.map(\.urlString))
        for read in readArticles where issueURLs.contains(read.urlString) {
            modelContext.delete(read)
        }
    }

    private var isCurrentRead: Bool {
        guard let url = webState.currentURL else { return false }
        return readUrlSet.contains(url.canonicalArticleString)
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
        let existingArticles = Set(articles.map(\.urlString))
        for url in urls {
            let key = url.canonicalArticleString
            guard !existingArticles.contains(key),
                  let issuePath = url.lrbIssuePath else { continue }
            modelContext.insert(Article(urlString: key, issuePath: issuePath))
            // No need to also mark these as read when the issue is archived —
            // the effective-read set (readUrlSet above) computes that union
            // every render.
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
