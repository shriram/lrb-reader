import SwiftUI
import WebKit

/// State that the SwiftUI layer reads from and sends commands to.
@Observable
final class WebViewState {
    var currentURL: URL?
    var currentTitle: String = ""
    var canGoBack: Bool = false
    var canGoForward: Bool = false
    var isLoading: Bool = false

    // Commands the UI can send; the coordinator observes these.
    var pendingAction: Action?

    enum Action: Equatable {
        case goBack
        case goForward
        case reload
        case load(URL)
    }
}

struct WebView: UIViewRepresentable {
    let state: WebViewState
    let initialURL: URL
    let readUrls: Set<String>
    let onMarkRead: (URL) -> Void
    /// (pageURL, articleURLs scraped from that page)
    let onDiscoverArticles: (URL, [URL]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state, onMarkRead: onMarkRead, onDiscoverArticles: onDiscoverArticles)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Default WKWebsiteDataStore persists cookies across launches, so
        // logging in to LRB once should stick.
        config.websiteDataStore = .default()

        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "lrbArticles")
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        context.coordinator.webView = webView
        context.coordinator.readUrls = readUrls

        webView.load(URLRequest(url: initialURL))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Keep coordinator's read-URL set and callbacks in sync with the SwiftUI side.
        context.coordinator.readUrls = readUrls
        context.coordinator.onMarkRead = onMarkRead
        context.coordinator.onDiscoverArticles = onDiscoverArticles

        // Drain any pending action from the SwiftUI side.
        guard let action = state.pendingAction else { return }
        state.pendingAction = nil

        switch action {
        case .goBack:
            if webView.canGoBack { webView.goBack() }
        case .goForward:
            if webView.canGoForward { webView.goForward() }
        case .reload:
            webView.reload()
        case .load(let url):
            webView.load(URLRequest(url: url))
        }
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let state: WebViewState
        var readUrls: Set<String> = []
        var onMarkRead: (URL) -> Void
        var onDiscoverArticles: (URL, [URL]) -> Void
        weak var webView: WKWebView? {
            didSet { observeWebView() }
        }
        private var observations: [NSKeyValueObservation] = []
        private var markReadTask: Task<Void, Never>?

        init(state: WebViewState,
             onMarkRead: @escaping (URL) -> Void,
             onDiscoverArticles: @escaping (URL, [URL]) -> Void) {
            self.state = state
            self.onMarkRead = onMarkRead
            self.onDiscoverArticles = onDiscoverArticles
        }

        private func observeWebView() {
            observations.removeAll()
            guard let webView else { return }
            observations.append(webView.observe(\.url, options: [.initial, .new]) { [weak self] wv, _ in
                Task { @MainActor in self?.state.currentURL = wv.url }
            })
            observations.append(webView.observe(\.title, options: [.initial, .new]) { [weak self] wv, _ in
                Task { @MainActor in self?.state.currentTitle = wv.title ?? "" }
            })
            observations.append(webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] wv, _ in
                Task { @MainActor in self?.state.canGoBack = wv.canGoBack }
            })
            observations.append(webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] wv, _ in
                Task { @MainActor in self?.state.canGoForward = wv.canGoForward }
            })
            observations.append(webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] wv, _ in
                Task { @MainActor in self?.state.isLoading = wv.isLoading }
            })
        }

        // MARK: WKNavigationDelegate

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            // Any new navigation cancels the pending mark-as-read for the previous page.
            markReadTask?.cancel()
            markReadTask = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            injectReadIndicatorJS(into: webView)
            injectArticleScrapingJS(into: webView)

            // If this page is something readable (article or blog post),
            // schedule a delayed mark-as-read. We wait 5 seconds so
            // accidental clicks don't count.
            if let url = webView.url, url.isLRBReadable {
                let urlToMark = url
                markReadTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(5))
                    if Task.isCancelled { return }
                    await MainActor.run { self?.onMarkRead(urlToMark) }
                }
            }
        }

        private func injectReadIndicatorJS(into webView: WKWebView) {
            let jsonData = (try? JSONSerialization.data(withJSONObject: Array(readUrls))) ?? Data("[]".utf8)
            let urlsJson = String(data: jsonData, encoding: .utf8) ?? "[]"
            let js = """
            (function() {
              try {
                const readUrls = new Set(\(urlsJson));
                const links = document.querySelectorAll('a[href]');
                links.forEach(a => {
                  if (readUrls.has(a.href)) {
                    a.style.opacity = '0.45';
                    a.style.textDecoration = 'line-through';
                    a.setAttribute('data-lrb-read', 'true');
                  }
                });
              } catch (e) { /* swallow */ }
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        /// Find every link on the page that looks like an LRB article and ship the
        /// list back to Swift. Lets us learn an issue's contents the first time we open it.
        private func injectArticleScrapingJS(into webView: WKWebView) {
            let js = """
            (function() {
              try {
                const articleRegex = /^\\/the-paper\\/v\\d+\\/n\\d+\\/.+/;
                const seen = new Set();
                document.querySelectorAll('a[href]').forEach(a => {
                  try {
                    const u = new URL(a.href, location.origin);
                    if (u.host === location.host && articleRegex.test(u.pathname)) {
                      seen.add(u.origin + u.pathname);
                    }
                  } catch (e) { /* skip */ }
                });
                if (seen.size > 0) {
                  window.webkit.messageHandlers.lrbArticles.postMessage(Array.from(seen));
                }
              } catch (e) { /* swallow */ }
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        // MARK: WKScriptMessageHandler

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "lrbArticles",
                  let strings = message.body as? [String],
                  let pageURL = webView?.url else { return }
            let urls = strings.compactMap { URL(string: $0) }.filter { $0.isLRBArticle }
            // Even if `urls` is empty we still want to signal the page visit,
            // so the receiver can record "we've seen this TOC".
            onDiscoverArticles(pageURL, urls)
        }
    }
}
