import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                
                // TEMPORARY: Show what happened with permission
                DispatchQueue.main.async {
                    let alert = UIAlertController(
                        title: granted ? "✅ Permission Granted" : "❌ Permission Denied",
                        message: error != nil ? "Error: \(error!.localizedDescription)" : "Calling registerForRemoteNotifications: \(granted)",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let vc = scene.windows.first?.rootViewController {
                        vc.present(alert, animated: true)
                    }
                }
                
                guard granted else { return }
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }

        return true
    }

    // ── Receive APNs device token and broadcast it ────────────────
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("✅ APNs token received: \(token)")

        // Persist for use when WebViews load
        UserDefaults.standard.set(token, forKey: "apns_device_token")
        
        // TEMPORARY: Send token directly to Lambda without going through WebView
        let tokenString = token
        let url = URL(string: "https://y25m8puewi.execute-api.us-west-1.amazonaws.com/prod/fuelbreak-notify")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "action": "register",
            "user_id": "test_native_device",
            "device_token": tokenString
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data, let str = String(data: data, encoding: .utf8) {
                print("📱 Direct registration result: \(str)")
            }
        }.resume()
        

        // TEMPORARY: Show token visually to confirm this is firing
        let alert = UIAlertController(
            title: "✅ APNs Token Received",
            message: "First 20 chars:\n\(String(token.prefix(20)))",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let vc = scene.windows.first?.rootViewController {
            vc.present(alert, animated: true)
        }

        // Broadcast so AppCoordinator can push the token into live WebViews
        NotificationCenter.default.post(
            name: .deviceTokenReceived,
            object: nil,
            userInfo: ["token": token]
        )
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "❌ APNs Registration Failed",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let vc = scene.windows.first?.rootViewController {
                vc.present(alert, animated: true)
            }
        }
    }

    // ── Fires when the user TAPS a notification ───────────────────
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let info   = response.notification.request.content.userInfo
        let tab    = info["tab"]    as? String ?? "wildfire"
        let target = info["target"] as? String ?? "panel-alerts"

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            NotificationCenter.default.post(
                name: .navigateToTarget,
                object: nil,
                userInfo: ["tab": tab, "target": target]
            )
        }
        completionHandler()
    }
}

// ── Notification names ────────────────────────────────────────────
extension Notification.Name {
    static let navigateToTarget  = Notification.Name("navigateToTarget")
    static let deviceTokenReceived = Notification.Name("deviceTokenReceived")
}
