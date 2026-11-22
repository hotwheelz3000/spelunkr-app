import SwiftUI
import UIKit
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(homeURL: url)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // Videos play in the page (not forced fullscreen), start without an extra tap,
        // and can go to AirPlay or Picture in Picture.
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.websiteDataStore = .default()
        // The page's own fullscreen button (the HTML Fullscreen API).
        configuration.preferences.isElementFullscreenEnabled = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        // Transparent until the page paints, so the purple shows instead of white.
        webView.isOpaque = false
        webView.backgroundColor = .spelunkrPurple
        webView.scrollView.backgroundColor = .spelunkrPurple
        webView.underPageBackgroundColor = .spelunkrPurple
        // No pull-to-refresh: a reload would cut the channel you're watching.
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.showsHorizontalScrollIndicator = false

        context.coordinator.webView = webView
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let homeURL: URL
        weak var webView: WKWebView?
        private var loadRetries = 0

        init(homeURL: URL) {
            self.homeURL = homeURL
            super.init()
        }

        /// spelunkr.tv and its subdomains stay in the app.
        private func isInternal(_ url: URL) -> Bool {
            guard let host = url.host?.lowercased() else { return true }
            return host == "spelunkr.tv" || host.hasSuffix(".spelunkr.tv")
        }

        private func isWebScheme(_ url: URL) -> Bool {
            let scheme = url.scheme?.lowercased() ?? ""
            return ["http", "https", "about", "blob", "data"].contains(scheme)
        }

        private func openExternally(_ url: URL) {
            UIApplication.shared.open(url)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else { return .allow }

            // mailto:, tel:, App Store links, etc.
            if !isWebScheme(url) {
                openExternally(url)
                return .cancel
            }

            // Embedded players and video from archive.org load normally.
            let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
            guard isMainFrame else { return .allow }

            // Links you tap that leave SPELUNKR (an Internet Archive page, say) open in Safari.
            if !isInternal(url)
                && (navigationAction.targetFrame == nil || navigationAction.navigationType == .linkActivated)
            {
                openExternally(url)
                return .cancel
            }
            return .allow
        }

        // window.open / target=_blank: SPELUNKR pages stay here, others go to Safari.
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let url = navigationAction.request.url {
                if isInternal(url) && isWebScheme(url) {
                    webView.load(navigationAction.request)
                } else {
                    openExternally(url)
                }
            }
            return nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loadRetries = 0
        }

        /// If the app opens with no connection, try again by itself a few times.
        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            guard webView.backForwardList.currentItem == nil, loadRetries < 6 else { return }
            loadRetries += 1
            let home = homeURL
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak webView] in
                MainActor.assumeIsolated {
                    guard let webView, webView.backForwardList.currentItem == nil else { return }
                    webView.load(URLRequest(url: home))
                }
            }
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            webView.reload()
        }
    }
}
