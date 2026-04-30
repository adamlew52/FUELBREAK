import SwiftUI
import WebKit

private let API_GATEWAY_URL = "https://y25m8puewi.execute-api.us-west-1.amazonaws.com/prod/fuelbreak-notify"

struct ForestryWebView: UIViewRepresentable {
    let url: URL
    let key: String          // Unique tab identifier
    let coordinator: AppCoordinator

    func makeCoordinator() -> AppCoordinator { coordinator }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // ── 1. Inline media, geolocation, no-zoom ────────────────
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        // Geolocation bridge
        config.userContentController.add(context.coordinator, name: "locationRequest")
        config.userContentController.addUserScript(
            WKUserScript(source: locationBridgeJS,
                         injectionTime: .atDocumentStart,
                         forMainFrameOnly: false)
        )
        config.userContentController.addUserScript(
            WKUserScript(source: noZoomJS,
                         injectionTime: .atDocumentEnd,
                         forMainFrameOnly: true)
        )

        // ── 2. APNs token bridge ──────────────────────────────────
        // window.__apns_device_token is kept current by AppCoordinator.injectToken().
        // Registration to Lambda is done natively in Swift (AppCoordinator.setUserId handler)
        // so there is no JS fetch() call here — that was the source of the production failure.
        let savedToken = UserDefaults.standard.string(forKey: "apns_device_token") ?? ""
        let tokenBridgeJS = """
        (function () {
            // Expose the current token so web JS can read it if needed (read-only use).
            window.__apns_device_token = "\(savedToken)";
            window.__apns_api_url      = "\(API_GATEWAY_URL)";

            // fuelbreak.registerToken(userId) — signals native Swift to perform registration.
            // Call this from your web JS after login exactly as before.
            window.fuelbreak = {
                registerToken: function (userId) {
                    console.log('[fuelbreak] registerToken called for userId: ' + userId);
                    window.webkit.messageHandlers.setUserId.postMessage(String(userId));
                }
            };
        })();
        """
        config.userContentController.addUserScript(
            WKUserScript(source: tokenBridgeJS,
                         injectionTime: .atDocumentStart,
                         forMainFrameOnly: false)
        )

        // ── 3. JS console → Xcode console (debugging) ────────────
        config.userContentController.add(context.coordinator, name: "xcodelogdebug")
        config.userContentController.addUserScript(
            WKUserScript(source: """
            (function () {
                var _log = console.log.bind(console);
                console.log = function () {
                    var msg = Array.from(arguments).join(' ');
                    window.webkit.messageHandlers.xcodelogdebug.postMessage(msg);
                    _log.apply(console, arguments);
                };
            })();
            """, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        )

        // setUserId message handler – used by fuelbreak.registerToken above
        config.userContentController.add(context.coordinator, name: "setUserId")

        // ── Create and configure the WebView ─────────────────────
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.0, green: 0.20, blue: 0.0, alpha: 1.0)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .scrollableAxes
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false
        webView.scrollView.isScrollEnabled = true

        if #available(iOS 16.4, *) { webView.isInspectable = true }

        context.coordinator.register(webView: webView, url: url, key: key)
        webView.load(URLRequest(url: url))

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // ── JS bridges ───────────────────────────────────────────────
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

    private let noZoomJS = """
    (function() {
        var m = document.querySelector('meta[name=viewport]');
        if (!m) { m = document.createElement('meta'); m.name='viewport'; document.head.appendChild(m); }
        m.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
    })();
    """
}
