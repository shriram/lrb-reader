import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .issues

    // Browse-tab session state. Bumping `browseSessionId` recreates the WebView
    // so back history starts fresh when opening from Issues/Bookmarks.
    @State private var browseInitialURL: URL = URL(string: "https://www.lrb.co.uk")!
    @State private var browseSessionId: UUID = UUID()
    @State private var browseOriginTab: Tab? = nil

    // Blog tab is just another WebView pinned to /blog/. Its session id never
    // changes, so the WebView persists across tab switches and remembers where
    // you were within the blog.
    private let blogSessionId: UUID = UUID()
    private let blogInitialURL: URL = URL(string: "https://www.lrb.co.uk/blog/")!

    enum Tab: Hashable {
        case issues, blog, browse, bookmarks
    }

    private func openExternal(_ url: URL, from tab: Tab) {
        browseInitialURL = url
        browseSessionId = UUID()
        browseOriginTab = tab
        selectedTab = .browse
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            IssuesView(onOpen: { url in openExternal(url, from: .issues) })
                .tabItem { Label("Issues", systemImage: "calendar") }
                .tag(Tab.issues)

            ReaderView(
                initialURL: blogInitialURL,
                sessionId: blogSessionId,
                originTab: nil,
                onReturnToOrigin: { _ in }
            )
            .tabItem { Label("Blog", systemImage: "newspaper") }
            .tag(Tab.blog)

            ReaderView(
                initialURL: browseInitialURL,
                sessionId: browseSessionId,
                originTab: browseOriginTab,
                onReturnToOrigin: { tab in
                    selectedTab = tab
                    browseOriginTab = nil
                }
            )
            .tabItem { Label("Browse", systemImage: "globe") }
            .tag(Tab.browse)

            BookmarksView(onOpen: { url in openExternal(url, from: .bookmarks) })
                .tabItem { Label("Bookmarks", systemImage: "bookmark") }
                .tag(Tab.bookmarks)
        }
    }
}
