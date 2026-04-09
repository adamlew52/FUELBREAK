import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                guard granted else { return }
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }

        // ── Kill the white UIHostingController flash ──────────────
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.view.backgroundColor = UIColor(red: 0.96, green: 0.61, blue: 0.04, alpha: 1.0)
        }

        // ── Fix top safe area white flash ─────────────────────────
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let tabBarController = windowScene.windows.first?.rootViewController as? UITabBarController {
                tabBarController.view.backgroundColor = UIColor(red: 0.96, green: 0.61, blue: 0.04, alpha: 1.0)
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

        // Broadcast so AppCoordinator can push the token into live WebViews
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .deviceTokenReceived,
                object: nil,
                userInfo: ["token": token]
            )
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ APNs registration failed: \(error)")
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
