import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error = error {
                    print("❌ Notification permission error: \(error.localizedDescription)")
                }
                print(granted ? "✅ Notification permission granted" : "⚠️ Notification permission denied")
                guard granted else { return }
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        return true
    }

    // ── Receive APNs device token ─────────────────────────────────
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("✅ APNs token received: \(token)")

        // Persist for use when WebViews load or when userId arrives
        UserDefaults.standard.set(token, forKey: "apns_device_token")

        // Broadcast so AppCoordinator can update any live WebViews
        NotificationCenter.default.post(
            name: .deviceTokenReceived,
            object: nil,
            userInfo: ["token": token]
        )

        // If a userId is already known (returning user), register immediately
        if let userId = UserDefaults.standard.string(forKey: "current_user_id"),
           !userId.isEmpty {
            print("🔄 Token refreshed – re-registering existing user: \(userId)")
            APNSRegistration.send(token: token, userId: userId)
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ APNs registration failed: \(error.localizedDescription)")
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
    static let navigateToTarget    = Notification.Name("navigateToTarget")
    static let deviceTokenReceived = Notification.Name("deviceTokenReceived")
}
