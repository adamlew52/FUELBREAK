import SwiftUI
import WebKit

private let API_GATEWAY_URL = "https://y25m8puewi.execute-api.us-west-1.amazonaws.com/prod/fuelbreak-notify"

struct ForestryWebView: UIViewRepresentable {
    let url: URL
    let key: String
    let coordinator: AppCoordinator

    func makeCoordinator() -> AppCoordinator { coordinator }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // ── 1. Inline media, geolocation, no-zoom ────────────────
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        // Foreground location bridge (getCurrentPosition)
        config.userContentController.add(context.coordinator, name: "locationRequest")

        // Geofencing bridges — web layer can push fire zones natively
        config.userContentController.add(context.coordinator, name: "addFireZone")
        config.userContentController.add(context.coordinator, name: "removeFireZone")

        // Background-alert toggle bridge
        // e.g. window.webkit.messageHandlers.setBackgroundAlerts.postMessage(true)
        config.userContentController.add(context.coordinator, name: "setBackgroundAlerts")

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
        let savedToken = UserDefaults.standard.string(forKey: "apns_device_token") ?? ""
        let alertsEnabled = UserDefaults.standard.bool(forKey: "backgroundAlertsEnabled")
        let tokenBridgeJS = """
        (function () {
            window.__apns_device_token       = "\(savedToken)";
            window.__apns_api_url            = "\(API_GATEWAY_URL)";
            window.__background_alerts_enabled = \(alertsEnabled);

            window.fuelbreak = {
                registerToken: function (userId) {
                    console.log('[fuelbreak] registerToken for userId: ' + userId);
                    window.webkit.messageHandlers.setUserId.postMessage(String(userId));
                },

                // Web UI can call this to toggle background fire alerts:
                //   window.fuelbreak.setBackgroundAlerts(true)
                setBackgroundAlerts: function(enabled) {
                    window.webkit.messageHandlers.setBackgroundAlerts.postMessage(!!enabled);
                },

                // Register a fire danger zone for native geofencing:
                //   window.fuelbreak.addFireZone({ id, lat, lng, radius })
                addFireZone: function(zone) {
                    window.webkit.messageHandlers.addFireZone.postMessage(zone);
                },

                removeFireZone: function(id) {
                    window.webkit.messageHandlers.removeFireZone.postMessage(id);
                }
            };
        })();
        """
        config.userContentController.addUserScript(
            WKUserScript(source: tokenBridgeJS,
                         injectionTime: .atDocumentStart,
                         forMainFrameOnly: false)
        )

        // ── 3. JS console → Xcode console ────────────────────────
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

        // ── 4. setUserId handler ──────────────────────────────────
        config.userContentController.add(context.coordinator, name: "setUserId")

        // ── 5. openPaywall handler ────────────────────────────────
        config.userContentController.add(context.coordinator, name: "openPaywall")

        // ── Create and configure the WebView ─────────────────────
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque   = false
        webView.backgroundColor = UIColor(red: 0.0, green: 0.20, blue: 0.0, alpha: 1.0)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate         = context.coordinator
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

    /// Intercepts navigator.geolocation.getCurrentPosition and routes it
    /// through the native CLLocationManager so iOS permission dialogs fire.
    private let locationBridgeJS = """
    (function () {
        window.__geo_success = null;
        window.__geo_error   = null;

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
        if (!m) {
            m = document.createElement('meta');
            m.name = 'viewport';
            document.head.appendChild(m);
        }
        m.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
    })();
    """
}
