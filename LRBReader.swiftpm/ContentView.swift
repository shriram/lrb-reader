import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .web

    enum Tab: Hashable {
        case web, issues, blog, bookmarks
    }

    private let lrbHomepage = URL(string: "https://www.lrb.co.uk")!
    private let blogURL = URL(string: "https://www.lrb.co.uk/blog/")!

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ReaderView(initialURL: lrbHomepage)
            }
            .tabItem { Label("Web", systemImage: "globe") }
            .tag(Tab.web)

            IssuesView()
                .tabItem { Label("Issues", systemImage: "calendar") }
                .tag(Tab.issues)

            NavigationStack {
                ReaderView(initialURL: blogURL)
            }
            .tabItem { Label("Blog", systemImage: "newspaper") }
            .tag(Tab.blog)

            BookmarksView()
                .tabItem { Label("Bookmarks", systemImage: "bookmark") }
                .tag(Tab.bookmarks)
        }
    }
}
