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

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state, onMarkRead: onMarkRead)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Default WKWebsiteDataStore persists cookies across launches, so
        // logging in to LRB once should stick.
        config.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        context.coordinator.webView = webView
        context.coordinator.readUrls = readUrls

        webView.load(URLRequest(url: initialURL))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Keep coordinator's read-URL set in sync with SwiftData.
        context.coordinator.readUrls = readUrls
        context.coordinator.onMarkRead = onMarkRead

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
    final class Coordinator: NSObject, WKNavigationDelegate {
        let state: WebViewState
        var readUrls: Set<String> = []
        var onMarkRead: (URL) -> Void
        weak var webView: WKWebView? {
            didSet { observeWebView() }
        }
        private var observations: [NSKeyValueObservation] = []
        private var markReadTask: Task<Void, Never>?

        init(state: WebViewState, onMarkRead: @escaping (URL) -> Void) {
            self.state = state
            self.onMarkRead = onMarkRead
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

            // If this page is an article, schedule a delayed mark-as-read.
            // We wait 5 seconds so accidental clicks don't count.
            if let url = webView.url, url.isLRBArticle {
                let urlToMark = url
                markReadTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(5))
                    if Task.isCancelled { return }
                    await MainActor.run { self?.onMarkRead(urlToMark) }
                }
            }
        }

        private func injectReadIndicatorJS(into webView: WKWebView) {
            // Encode the read URL set as JSON so we don't have to worry about escaping.
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
    }
}
