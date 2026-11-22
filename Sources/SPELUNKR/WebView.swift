import SwiftUI
import UIKit
import WebKit

struct WebView: UIViewRepresentable {
    let state: PageState

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state)
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

        let controller = configuration.userContentController
        controller.addUserScript(
            WKUserScript(source: AppScripts.page, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        )
        controller.addUserScript(
            WKUserScript(source: AppScripts.noZoom, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        )
        controller.add(context.coordinator, name: AppScripts.mediaHandler)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        // No peek-and-pop link previews: feels like an app, not a browser.
        webView.allowsLinkPreview = false
        // Transparent until the page paints, so the purple shows instead of white.
        webView.isOpaque = false
        webView.backgroundColor = .spelunkrPurple
        webView.scrollView.backgroundColor = .spelunkrPurple
        webView.underPageBackgroundColor = .spelunkrPurple
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false

        context.coordinator.webView = webView
        state.webView = webView
        webView.load(URLRequest(url: state.homeURL))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: AppScripts.mediaHandler)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let state: PageState
        weak var webView: WKWebView?
        /// The page or embedded player whose video is playing, for Picture in Picture.
        private var playingFrame: WKFrameInfo?
        private var inPiP = false
        private var observers: [NSObjectProtocol] = []

        init(state: PageState) {
            self.state = state
            super.init()
            let center = NotificationCenter.default
            // Leaving the app with a video playing: keep it going in Picture in Picture.
            observers.append(center.addObserver(
                forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.enterPiP() }
            })
            // Back in the app: put the video back in the page.
            observers.append(center.addObserver(
                forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.exitPiP() }
            })
        }

        // MARK: Playback

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard let body = message.body as? [String: Any], let playing = body["playing"] as? Bool else { return }
            if playing {
                playingFrame = message.frameInfo
            } else if playingFrame?.securityOrigin.host == message.frameInfo.securityOrigin.host {
                playingFrame = nil
            }
            // The screen stays on while a channel plays, and sleeps normally once it stops.
            UIApplication.shared.isIdleTimerDisabled = playingFrame != nil
        }

        private func enterPiP() {
            guard let webView, let frame = playingFrame else { return }
            webView.evaluateJavaScript(
                "window.__spkPiP ? window.__spkPiP(true) : false", in: frame, in: .page
            ) { [weak self] result in
                if case .success(let value) = result, (value as? Bool) == true { self?.inPiP = true }
            }
        }

        private func exitPiP() {
            guard inPiP, let webView, let frame = playingFrame else { inPiP = false; return }
            inPiP = false
            webView.evaluateJavaScript("window.__spkPiP && window.__spkPiP(false)", in: frame, in: .page)
        }

        // MARK: Navigation

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
            webView.scrollView.pinchGestureRecognizer?.isEnabled = false
            state.offline = false
            // Give the page a moment to draw the channel before the loading screen fades.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                MainActor.assumeIsolated { self?.state.loaded = true }
            }
        }

        /// Nothing loaded at all (no connection when the app opened): show the offline screen.
        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            if (error as NSError).code == NSURLErrorCancelled { return }
            guard !state.loaded, webView.backForwardList.currentItem == nil else { return }
            state.offline = true
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            playingFrame = nil
            UIApplication.shared.isIdleTimerDisabled = false
            webView.reload()
        }
    }
}
