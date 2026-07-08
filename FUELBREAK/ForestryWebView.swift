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

        // ── Inline media ─────────────────────────────────────────
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        // ── JS → Swift bridges ───────────────────────────────────
        let uc = config.userContentController
        uc.add(context.coordinator, name: "locationRequest")
        uc.add(context.coordinator, name: "addFireZone")
        uc.add(context.coordinator, name: "removeFireZone")
        uc.add(context.coordinator, name: "setBackgroundAlerts")
        uc.add(context.coordinator, name: "setUserId")
        uc.add(context.coordinator, name: "openPaywall")
        uc.add(context.coordinator, name: "xcodelogdebug")

        // ── Injected scripts (atDocumentStart) ───────────────────
        uc.addUserScript(WKUserScript(source: Self.locationBridgeJS,
                                      injectionTime: .atDocumentStart,
                                      forMainFrameOnly: false))

        let savedToken = UserDefaults.standard.string(forKey: "apns_device_token") ?? ""
        let alertsEnabled = UserDefaults.standard.bool(forKey: "backgroundAlertsEnabled")
        uc.addUserScript(WKUserScript(source: Self.tokenBridgeJS(token: savedToken,
                                                                  apiURL: API_GATEWAY_URL,
                                                                  alertsEnabled: alertsEnabled),
                                      injectionTime: .atDocumentStart,
                                      forMainFrameOnly: false))

        uc.addUserScript(WKUserScript(source: Self.consoleBridgeJS,
                                      injectionTime: .atDocumentStart,
                                      forMainFrameOnly: false))

        // ── Create WebView ───────────────────────────────────────
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.03, green: 0.06, blue: 0.03, alpha: 1.0)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate         = context.coordinator

        // Let the web page handle safe areas via CSS env(safe-area-inset-*)
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        // DO NOT disable pinchGestureRecognizer — it breaks the entire
        // tap/gesture recognizer chain on iOS and causes "taps don't work".
        // The web page already sets user-scalable=no in its viewport meta.

        webView.scrollView.isScrollEnabled = true

        if #available(iOS 16.4, *) { webView.isInspectable = true }

        context.coordinator.register(webView: webView, url: url, key: key)
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // ═══════════════════════════════════════════════════════════════
    // MARK: – Injected JavaScript
    // ═══════════════════════════════════════════════════════════════

    /// Intercepts navigator.geolocation.getCurrentPosition → native CLLocationManager
    private static let locationBridgeJS = """
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
                coords: { latitude: lat, longitude: lng, accuracy: accuracy,
                          altitude: null, altitudeAccuracy: null, heading: null, speed: null },
                timestamp: Date.now()
            });
        };
        window.__geo_fail = function (code, msg) {
            if (window.__geo_error) window.__geo_error({ code: code, message: msg });
        };
    })();
    """

    // ── App version — update this with every App Store release ──────────────
    static let APP_VERSION = "1.0.8"

    /// Exposes APNs token + fuelbreak bridge object to the web layer
    private static func tokenBridgeJS(token: String, apiURL: String, alertsEnabled: Bool) -> String {
        return """
        (function () {
            window.__apns_device_token         = "\(token)";
            window.__apns_api_url              = "\(apiURL)";
            window.__background_alerts_enabled = \(alertsEnabled);
            window.__app_version               = "\(APP_VERSION)";
            window.fuelbreak = {
                registerToken: function (userId) {
                    window.webkit.messageHandlers.setUserId.postMessage(String(userId));
                },
                setBackgroundAlerts: function(enabled) {
                    window.webkit.messageHandlers.setBackgroundAlerts.postMessage(!!enabled);
                },
                addFireZone: function(zone) {
                    window.webkit.messageHandlers.addFireZone.postMessage(zone);
                },
                removeFireZone: function(id) {
                    window.webkit.messageHandlers.removeFireZone.postMessage(id);
                }
            };
        })();
        """
    }

    /// Pipes console.log → Xcode console via xcodelogdebug bridge
    private static let consoleBridgeJS = """
    (function () {
        var _log = console.log.bind(console);
        console.log = function () {
            var msg = Array.from(arguments).join(' ');
            try { window.webkit.messageHandlers.xcodelogdebug.postMessage(msg); } catch(e) {}
            _log.apply(console, arguments);
        };
    })();
    """
}
