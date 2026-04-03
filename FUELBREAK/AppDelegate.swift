import UIKit
import UserNotifications

// Add UNUserNotificationCenterDelegate conformance
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    // Add this to your existing didFinishLaunchingWithOptions or applicationDidBecomeActive:
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("APNs token: \(token)")
    }

    // This fires when the user TAPS a notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse,
                                 withCompletionHandler completionHandler: @escaping () -> Void) {
        let info   = response.notification.request.content.userInfo
        let tab    = info["tab"]    as? String ?? "wildfire"
        let target = info["target"] as? String ?? "panel-alerts"

        // Small delay so the app has time to foreground and the webview loads
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            // Post through NotificationCenter so ContentView picks it up
            NotificationCenter.default.post(
                name: .navigateToTarget,
                object: nil,
                userInfo: ["tab": tab, "target": target]
            )
        }
        completionHandler()
    }
}

// Add this extension anywhere
extension Notification.Name {
    static let navigateToTarget = Notification.Name("navigateToTarget")
}

// Call this from anywhere to fire a test notification in 5 seconds
func scheduleTestNotification() {
    let content = UNMutableNotificationContent()
    content.title = "Wildfire Alert"
    content.body  = "New activity near your area."
    content.sound = .default
    content.badge = 1

    // Fires 5 seconds from now
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
    let request = UNNotificationRequest(identifier: UUID().uuidString,
                                        content: content,
                                        trigger: trigger)

    UNUserNotificationCenter.current().add(request)
}
