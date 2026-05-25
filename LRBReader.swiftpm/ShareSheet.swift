import SwiftUI
import UIKit

/// Tiny SwiftUI wrapper around UIKit's UIActivityViewController so we can
/// present the system share sheet via a SwiftUI .sheet modifier.
///
/// We use this instead of SwiftUI's `ShareLink` because ShareLink on iPad
/// presents as a popover anchored to the source view, and that popover
/// renders in the same window layer as our WKWebView. WKWebView's
/// out-of-process compositing on iPadOS clips the popover, leaving only
/// the top edge visible. Presenting through a SwiftUI .sheet uses a
/// separate modal layer that the WebView cannot interfere with.
///
/// The actual share UI inside (apps, Copy, Reading List, etc.) is identical
/// either way — both routes ultimately use UIActivityViewController.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
