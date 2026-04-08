import SwiftUI
import WebKit

// Use the endpoint from your Lambda
private let API_GATEWAY_URL = "https://y25m8puewi.execute-api.us-west-1.amazonaws.com/prod/fuelbreak-notify"

struct ForestryWebView: UIViewRepresentable {
    let url: URL
    let key: String          // Unique tab identifier
    let coordinator: AppCoordinator

    func makeCoordinator() -> AppCoordinator { coordinator }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // ── 1. Existing: inline media, geolocation, no‑zoom ──────────────
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

        // ── 2. APNs token bridge with automatic registration ──────────────
        let savedToken = UserDefaults.standard.string(forKey: "apns_device_token") ?? ""
        let savedUserId = UserDefaults.standard.string(forKey: "current_user_id") ?? ""  // Store this after login

        let tokenBridgeJS = """
        (function () {
            window.__apns_device_token = "\(savedToken)";
            window.__apns_api_url      = "\(API_GATEWAY_URL)";
            window.__current_user_id   = "\(savedUserId)";

            window.CrewBoss = {
                // Call this manually if needed: CrewBoss.registerToken(userId)
                registerToken: function (userId) {
                    var token = window.__apns_device_token;
                    if (!token || token.length === 0) return;
                    fetch(window.__apns_api_url, {
                        method:  'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({
                            action:       'register',
                            user_id:      String(userId),
                            device_token: token
                        })
                    }).then(function(r) {
                        console.log('[CrewBoss] token registered, status:', r.status);
                    }).catch(function(err) {
                        console.warn('[CrewBoss] registerToken failed:', err);
                    });
                }
            };

            // Automatically register on every page load if we have a user ID
            if (window.__current_user_id && window.__apns_device_token) {
                window.CrewBoss.registerToken(window.__current_user_id);
            }
        })();
        """
        config.userContentController.addUserScript(
            WKUserScript(source: tokenBridgeJS,
                         injectionTime: .atDocumentStart,
                         forMainFrameOnly: false)
        )

        // ── 3. JS console → Xcode console (debugging) ───────────────
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
        config.userContentController.add(context.coordinator, name: "setUserId")

        // ── Create and configure the WebView ─────────────────────────────
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

    // ── Existing JS bridges (unchanged) ─────────────────────────────────
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
