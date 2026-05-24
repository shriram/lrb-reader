import SwiftUI
import SwiftData

/// The WebView pane with its toolbar. Used as:
///   - the entire content of the Blog and Web tabs (canDismiss: false)
///   - the destination pushed when opening an issue or bookmark
///     (canDismiss: true)
/// Always expects a NavigationStack to be provided by its parent.
struct ReaderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Bookmark.addedAt, order: .reverse) private var bookmarks: [Bookmark]
    @Query private var readArticles: [ReadArticle]
    @Query private var articles: [Article]
    @Query private var issues: [Issue]

    let initialURL: URL
    /// True when this view was pushed onto a NavigationStack (so back can pop).
    /// False when it's the root of a tab's stack (so back is WebView-only).
    var canDismiss: Bool = false

    @State private var webState = WebViewState()
    @State private var pendingIssueArchive: Issue?

    /// Union of actual ReadArticle URLs and every Article whose issuePath is
    /// archived. See README / design discussion for why this is the right model.
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
        WebView(
            state: webState,
            initialURL: initialURL,
            readUrls: readUrlSet,
            onMarkRead: markRead,
            onDiscoverArticles: discoverArticles
        )
        .ignoresSafeArea(edges: .bottom)
        .onChange(of: readUrlSet) { _, newSet in
            // Direct-restyle path. The WebView's updateUIView already has a
            // change-detection re-inject for visible tabs; this .onChange
            // path is what catches off-screen tabs where updateUIView may
            // not fire reliably.
            webState.restyleTrigger?(newSet)
        }
        .navigationTitle(webState.currentTitle.isEmpty ? "London Review of Books" : webState.currentTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarLeading) {
                Button {
                    handleBack()
                } label: {
                    Label("Back", systemImage: "chevron.left")
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
    }

    // MARK: Back / forward

    private var backEnabled: Bool {
        webState.canGoBack || canDismiss
    }

    private func handleBack() {
        if webState.canGoBack {
            webState.pendingAction = .goBack
        } else if canDismiss {
            dismiss()
        }
    }

    // MARK: Archive button (contextual)

    private var currentIsArticle: Bool {
        webState.currentURL?.isLRBReadable == true
    }

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
        issue.archivedAt = .now
    }

    private func unarchiveAndResetReads(_ issue: Issue) {
        issue.archivedAt = nil
        let issueURLs = Set(articles.filter { $0.issuePath == issue.path }.map(\.urlString))
        for read in readArticles where issueURLs.contains(read.urlString) {
            modelContext.delete(read)
        }
    }

    // MARK: Bookmarks

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

    // MARK: Read tracking

    private var isCurrentRead: Bool {
        guard let url = webState.currentURL else { return false }
        return readUrlSet.contains(url.canonicalArticleString)
    }

    private func toggleReadStatus() {
        guard let url = webState.currentURL else { return }
        let key = url.canonicalArticleString
        if let existing = readArticles.first(where: { $0.urlString == key }) {
            modelContext.delete(existing)
        } else {
            markRead(url)
        }
    }

    private func markRead(_ url: URL) {
        let key = url.canonicalArticleString
        if !readArticles.contains(where: { $0.urlString == key }) {
            modelContext.insert(ReadArticle(url: url))
        }
        // Ensure an Article record exists so this read counts toward issue
        // completeness even if we never opened the TOC.
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
        }
        if let tocPath = pageURL.issueTOCPath,
           let issue = issues.first(where: { $0.path == tocPath }),
           issue.articlesFetchedAt == nil {
            issue.articlesFetchedAt = .now
        }
    }
}
