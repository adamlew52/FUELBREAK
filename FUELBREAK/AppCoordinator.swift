import SwiftUI
import WebKit
import CoreLocation
import PhotosUI

/// ObservableObject so ContentView can hold it with @StateObject.
/// Implements all the WKWebView delegate protocols and bridges
/// camera, photo library, geolocation, JS dialogs, and APNs token
/// injection to native iOS.

final class AppCoordinator: NSObject, ObservableObject {
    @Published var pendingTarget: (tab: String, elementId: String)? = nil

    // ── Paywall ──────────────────────────────────────────────────
    /// Set to true to present the native StoreKit paywall.
    /// The idToken is extracted from WebKit localStorage so StoreKitManager
    /// can authenticate purchases against your Lambda.
    @Published var showPaywall: Bool = false
    @Published var paywallIdToken: String = ""

    // ── Active WebViews ──────────────────────────────────────────
    private var webViews: [String: (view: WKWebView, url: URL)] = [:]

    // ── Location ─────────────────────────────────────────────────
    private let locationManager = CLLocationManager()
    private weak var locationRequester: WKWebView?

    // ── File upload completion handler ───────────────────────────
    private var fileUploadCompletion: (([URL]?) -> Void)?

    override init() {
        super.init()
        locationManager.delegate        = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeviceTokenReceived(_:)),
            name: .deviceTokenReceived,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // ── APNs token injection ─────────────────────────────────────
    @objc private func handleDeviceTokenReceived(_ notification: Notification) {
        guard let token = notification.userInfo?["token"] as? String else { return }
        injectToken(token)
    }

    private func injectToken(_ token: String) {
        for (key, entry) in webViews {
            let js = "window.__apns_device_token = '\(token)';"
            entry.view.evaluateJavaScript(js) { _, error in
                if let error = error {
                    print("❌ [\(key)] token injection JS error: \(error.localizedDescription)")
                } else {
                    print("✅ [\(key)] APNs token updated in WebView")
                }
            }
        }
    }

    // ── WebView registration ─────────────────────────────────────
    func register(webView: WKWebView, url: URL, key: String) {
        webViews[key] = (view: webView, url: url)
    }

    func reloadTab(_ key: String) {
        guard let entry = webViews[key] else { return }
        entry.view.load(URLRequest(url: entry.url))
    }

    func navigateTo(tab: String, elementId: String) {
        pendingTarget = (tab, elementId)
        let js = """
            document.getElementById('\(elementId)')?.scrollIntoView({behavior:'smooth'});
            document.getElementById('\(elementId)')?.click();
        """
        webViews[tab]?.view.evaluateJavaScript(js, completionHandler: nil)
    }

    // ── Paywall: extract idToken then present ────────────────────
    /// Called when the WebView tries to navigate to any market/purchase URL.
    /// Reads the Cognito id_token out of WebKit localStorage so that
    /// StoreKitManager can send it to your Lambda for credit attribution.
    private func presentPaywallFromWebView(_ webView: WKWebView) {
        let extractTokenJS = """
        (function() {
            try {
                var t = localStorage.getItem('id_token');
                return t || '';
            } catch(e) { return ''; }
        })();
        """
        webView.evaluateJavaScript(extractTokenJS) { [weak self] result, _ in
            DispatchQueue.main.async {
                self?.paywallIdToken = (result as? String) ?? ""
                self?.showPaywall = true
            }
        }
    }

    /// Call this from your view hierarchy after a successful purchase so the
    /// WebView's credit display refreshes without a full page reload.
    func notifyWebViewOfPurchase(creditsAdded: Int) {
        let js = """
        (function() {
            // Dispatch a custom event that user_script.js or dashboard.js can listen to
            window.dispatchEvent(new CustomEvent('sensaro:creditsUpdated', {
                detail: { creditsAdded: \(creditsAdded) }
            }));
            // Also directly re-fetch user data if the page exposes uInit()
            if (typeof uInit === 'function') { uInit(); }
        })();
        """
        for (_, entry) in webViews {
            entry.view.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}


// ─────────────────────────────────────────────────────────────────
// MARK: – WKNavigationDelegate
// ─────────────────────────────────────────────────────────────────
extension AppCoordinator: WKNavigationDelegate {

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        if let url = navigationAction.request.url {
            let urlString = url.absoluteString

            // ── Intercept ALL market/purchase navigation ─────────
            // Previously this opened Safari. Now it shows the native paywall.
            // Catches:
            //   sensaro.net/Mobile/market/purchase/...
            //   sensaro.net/Mobile/market/index.html
            //   sensaro.net/Mobile/market/ (any market path)
            let isMarketURL = urlString.contains("sensaro.net/Mobile/market")
                           || urlString.contains("/market/purchase")
                           || urlString.contains("/market/index")

            if isMarketURL {
                // Extract the idToken from the webView that's navigating,
                // then present the paywall natively.
                presentPaywallFromWebView(webView)
                decisionHandler(.cancel)    // block the web navigation
                return
            }
        }

        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let apnsToken = UserDefaults.standard.string(forKey: "apns_device_token") ?? ""

        if !apnsToken.isEmpty {
            let injectJS = "window.__apns_device_token = '\(apnsToken)';"
            webView.evaluateJavaScript(injectJS) { _, error in
                if let error = error {
                    print("❌ [didFinish] token injection error: \(error.localizedDescription)")
                } else {
                    print("✅ [didFinish] APNs token injected after page load")
                }
            }
        }

        guard !apnsToken.isEmpty else { return }

        let extractUserIdJS = """
        (function() {
            try {
                var idToken = localStorage.getItem('id_token');
                if (!idToken) return '';
                var payload = JSON.parse(atob(idToken.split('.')[1]
                    .replace(/-/g, '+').replace(/_/g, '/')));
                return payload.email || payload.sub || '';
            } catch(e) {
                return '';
            }
        })();
        """

        webView.evaluateJavaScript(extractUserIdJS) { result, error in
            guard
                let userId = result as? String,
                !userId.isEmpty
            else {
                print("⚠️ [didFinish] No logged-in session found in WebKit localStorage")
                return
            }

            print("✅ [didFinish] Found session for \(userId) — registering token natively")
            UserDefaults.standard.set(userId, forKey: "current_user_id")
            APNSRegistration.send(token: apnsToken, userId: userId)
        }
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation _: WKNavigation!,
                 withError error: Error) {
        let html = """
        <html><body style='background:#0f1a14;color:#cfe6da;
            font-family:system-ui;padding:2rem;text-align:center;'>
            <h2>Could not load page</h2>
            <p>\(error.localizedDescription)</p>
            <p style='font-size:.85rem;opacity:.6;'>
                Make sure your device is online. This tool provides live data
                and requires a connection for accurate results.</p>
        </body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}


// ─────────────────────────────────────────────────────────────────
// MARK: – WKUIDelegate  (file picking + JS dialogs)
// ─────────────────────────────────────────────────────────────────
extension AppCoordinator: WKUIDelegate {

    func webView(_ webView: WKWebView,
                 runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame _: WKFrameInfo,
                 completionHandler: @escaping ([URL]?) -> Void) {

        self.fileUploadCompletion = completionHandler

        let sheet = UIAlertController(title: "Add Photo",
                                      message: nil,
                                      preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Take Photo with Camera",
                                      style: .default) { [weak self] _ in
            self?.presentCamera()
        })
        sheet.addAction(UIAlertAction(title: "Choose from Library",
                                      style: .default) { [weak self] _ in
            self?.presentPhotoLibrary()
        })
        sheet.addAction(UIAlertAction(title: "Cancel",
                                      style: .cancel) { [weak self] _ in
            self?.fileUploadCompletion?(nil)
            self?.fileUploadCompletion = nil
        })

        if let popover = sheet.popoverPresentationController {
            popover.sourceView = webView
            popover.sourceRect = CGRect(x: webView.bounds.midX,
                                        y: webView.bounds.midY,
                                        width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        topVC()?.present(sheet, animated: true)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame _: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        topVC()?.present(alert, animated: true)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame _: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK",     style: .default) { _ in completionHandler(true) })
        topVC()?.present(alert, animated: true)
    }
}


// ─────────────────────────────────────────────────────────────────
// MARK: – WKScriptMessageHandler
// ─────────────────────────────────────────────────────────────────
extension AppCoordinator: WKScriptMessageHandler {

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {

        if message.name == "xcodelogdebug" {
            print("🌐 [JS] \(message.body)")
            return
        }

        // ── openPaywall: web JS can trigger the paywall directly ─
        // Add this call to any web button as a fallback:
        //   window.webkit.messageHandlers.openPaywall.postMessage({})
        if message.name == "openPaywall" {
            if let webView = message.webView {
                presentPaywallFromWebView(webView)
            }
            return
        }

        if message.name == "setUserId", let userId = message.body as? String {
            print("✅ [Native] userId received from WebView: \(userId)")
            UserDefaults.standard.set(userId, forKey: "current_user_id")

            let token = UserDefaults.standard.string(forKey: "apns_device_token") ?? ""
            if token.isEmpty {
                print("⚠️ [Native] No APNs token yet — registration deferred until token arrives")
            } else {
                print("🔄 [Native] Registering token for userId: \(userId)")
                APNSRegistration.send(token: token, userId: userId)
            }
            return
        }

        guard message.name == "locationRequest" else { return }
        locationRequester = message.webView

        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            respondWithLocationError(code: 1,
                message: "Location access denied. Enable it in Settings → Privacy → Location.")
        @unknown default:
            break
        }
    }

    private func respondWithLocationError(code: Int, message: String) {
        let safeMsg = message.replacingOccurrences(of: "'", with: "\\'")
        locationRequester?.evaluateJavaScript("window.__geo_fail(\(code), '\(safeMsg)');",
                                              completionHandler: nil)
    }
}


// ─────────────────────────────────────────────────────────────────
// MARK: – CLLocationManagerDelegate
// ─────────────────────────────────────────────────────────────────
extension AppCoordinator: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if locationRequester != nil { manager.requestLocation() }
        case .denied, .restricted:
            respondWithLocationError(code: 1, message: "Location permission denied.")
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let js = "window.__geo_respond(\(loc.coordinate.latitude), \(loc.coordinate.longitude), \(loc.horizontalAccuracy));"
        locationRequester?.evaluateJavaScript(js, completionHandler: nil)
    }

    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: Error) {
        respondWithLocationError(code: 2, message: error.localizedDescription)
    }
}


// ─────────────────────────────────────────────────────────────────
// MARK: – Camera
// ─────────────────────────────────────────────────────────────────
extension AppCoordinator {

    func presentCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            presentPhotoLibrary()
            return
        }
        let picker = UIImagePickerController()
        picker.sourceType        = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing     = false
        picker.delegate          = self
        topVC()?.present(picker, animated: true)
    }
}

extension AppCoordinator: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage,
              let data  = image.jpegData(compressionQuality: 0.85) else {
            fileUploadCompletion?(nil); fileUploadCompletion = nil; return
        }
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sensaro_\(UUID().uuidString).jpg")
        try? data.write(to: tempURL)
        fileUploadCompletion?([tempURL])
        fileUploadCompletion = nil
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        fileUploadCompletion?(nil)
        fileUploadCompletion = nil
    }
}


// ─────────────────────────────────────────────────────────────────
// MARK: – Photo Library
// ─────────────────────────────────────────────────────────────────
extension AppCoordinator: PHPickerViewControllerDelegate {

    func presentPhotoLibrary() {
        var config            = PHPickerConfiguration(photoLibrary: .shared())
        config.filter         = .images
        config.selectionLimit = 1
        let picker            = PHPickerViewController(configuration: config)
        picker.delegate       = self
        topVC()?.present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController,
                didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let result = results.first else {
            fileUploadCompletion?(nil); fileUploadCompletion = nil; return
        }
        result.itemProvider.loadFileRepresentation(forTypeIdentifier: "public.image") {
            [weak self] url, _ in
            guard let url else {
                DispatchQueue.main.async { self?.fileUploadCompletion?(nil); self?.fileUploadCompletion = nil }
                return
            }
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("sensaro_\(UUID().uuidString).\(url.pathExtension)")
            try? FileManager.default.copyItem(at: url, to: dest)
            DispatchQueue.main.async {
                self?.fileUploadCompletion?([dest])
                self?.fileUploadCompletion = nil
            }
        }
    }
}


// ─────────────────────────────────────────────────────────────────
// MARK: – Helpers
// ─────────────────────────────────────────────────────────────────
private extension AppCoordinator {

    func topVC() -> UIViewController? {
        guard let scene  = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first,
              let window = scene.windows.first(where: { $0.isKeyWindow })
        else { return nil }
        var vc = window.rootViewController
        while let presented = vc?.presentedViewController { vc = presented }
        return vc
    }
}
