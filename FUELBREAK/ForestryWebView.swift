import SwiftUI
import WebKit

/// Wraps WKWebView so it can be used in SwiftUI.
/// Each tab gets its own WebView instance but shares one AppCoordinator
/// (so there's only one CLLocationManager and one image picker active at a time).
struct ForestryWebView: UIViewRepresentable {
    let url: URL
    let key: String          // Unique name for this tab e.g. "dashboard", "account"
    let coordinator: AppCoordinator

    func makeCoordinator() -> AppCoordinator { coordinator }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // ── Allow inline camera preview / video ──────────────────
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        // ── Geolocation bridge ───────────────────────────────────
        config.userContentController.add(context.coordinator,
                                         name: "locationRequest")
        config.userContentController.addUserScript(
            WKUserScript(source: locationBridgeJS,
                         injectionTime: .atDocumentStart,
                         forMainFrameOnly: false)
        )
        config.userContentController.addUserScript(
            WKUserScript(source: noZoomJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        )


        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate          = context.coordinator

        webView.scrollView.contentInsetAdjustmentBehavior = .scrollableAxes
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false
        webView.scrollView.isScrollEnabled = true // keep scrolling, just no zoom

        if #available(iOS 16.4, *) { webView.isInspectable = true }

        // Register with both the key and the original URL so the
        // coordinator can reload it by name later
        context.coordinator.register(webView: webView, url: url, key: key)

        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // ── JS injected before page load ─────────────────────────────
    private let locationBridgeJS = """
    (function () {
        window.__geo_success = null;
        window.__geo_error   = null;

        const _orig = navigator.geolocation.getCurrentPosition
            .bind(navigator.geolocation);

        navigator.geolocation.getCurrentPosition = function (success, error, opts) {
            window.__geo_success = success;
            window.__geo_error   = error || null;
            window.webkit.messageHandlers.locationRequest.postMessage({});
        };

        window.__geo_respond = function (lat, lng, accuracy) {
            if (!window.__geo_success) return;
            window.__geo_success({
                coords: {
                    latitude:         lat,
                    longitude:        lng,
                    accuracy:         accuracy,
                    altitude:         null,
                    altitudeAccuracy: null,
                    heading:          null,
                    speed:            null
                },
                timestamp: Date.now()
            });
        };
        window.__geo_fail = function (code, msg) {
            if (!window.__geo_error) return;
            window.__geo_error({ code: code, message: msg });
        };
    })();
    """
    
    let noZoomJS = """
    (function() {
        var m = document.querySelector('meta[name=viewport]');
        if (!m) { m = document.createElement('meta'); m.name='viewport'; document.head.appendChild(m); }
        m.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
    })();
    """
}
