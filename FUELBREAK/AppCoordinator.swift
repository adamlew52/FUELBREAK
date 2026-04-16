import WebKit
import CoreLocation
import PhotosUI

/// ObservableObject so ContentView can hold it with @StateObject.
/// Implements all the WKWebView delegate protocols and bridges
/// camera, photo library, geolocation, JS dialogs, and APNs token
/// injection to native iOS.

final class AppCoordinator: NSObject, ObservableObject {
    @Published var pendingTarget: (tab: String, elementId: String)? = nil

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

        // Listen for APNs token so we can inject it into live WebViews
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
    /// Called when AppDelegate receives a fresh token from Apple.
    /// Pushes the token into every currently-loaded WebView so that
    /// window.fuelbreak.registerToken(userId) will have it ready.
    @objc private func handleDeviceTokenReceived(_ notification: Notification) {
        guard let token = notification.userInfo?["token"] as? String else { return }
        injectToken(token)
    }

    private func injectToken(_ token: String) {
        for (key, entry) in webViews {
            let js = "if(window.fuelbreak && window.fuelbreak.setToken) { window.fuelbreak.setToken('\(token)'); }"
            entry.view.evaluateJavaScript(js) { _, error in
                if let error = error {
                    print("❌ [\(key)] setToken JS error: \(error.localizedDescription)")
                } else {
                    print("✅ [\(key)] APNs token injected into WebView")
                }
            }
        }
    }

    // ── WebView registration ─────────────────────────────────────
    func register(webView: WKWebView, url: URL, key: String) {
        webViews[key] = (view: webView, url: url)

        // If we already have a token saved, inject it immediately
        // (handles the case where the token arrived before the WebView loaded)
        if let savedToken = UserDefaults.standard.string(forKey: "apns_device_token"),
           !savedToken.isEmpty {
            let js = "if(window.fuelbreak && window.fuelbreak.setToken) { window.fuelbreak.setToken('\(savedToken)'); }"
            // Small delay to let the page's own JS finish executing first
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                webView.evaluateJavaScript(js) { _, error in
                    if let error = error {
                        print("❌ [\(key)] deferred setToken error: \(error.localizedDescription)")
                    } else {
                        print("✅ [\(key)] deferred token injected on register")
                    }
                }
            }
        }
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
}


// ─────────────────────────────────────────────────────────────────
// MARK: – WKNavigationDelegate
// ─────────────────────────────────────────────────────────────────
extension AppCoordinator: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url,
           url.absoluteString.contains("sensaro.net/Mobile/market/purchase") {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
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

        // ── setUserId: web page tells us who just logged in ──────
        if message.name == "setUserId", let userId = message.body as? String {
            UserDefaults.standard.set(userId, forKey: "current_user_id")
            print("✅ [Native] User ID saved: \(userId)")

            // Trigger token registration on the web side now that we have a userId
            let js = "if(window.fuelbreak && window.fuelbreak.registerToken) { window.fuelbreak.registerToken('\(userId)'); }"
            message.webView?.evaluateJavaScript(js) { _, error in
                if let error = error {
                    print("❌ registerToken JS error: \(error.localizedDescription)")
                } else {
                    print("✅ registerToken called for userId: \(userId)")
                }
            }
            return
        }

        // ── locationRequest: web page needs device GPS ───────────
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
