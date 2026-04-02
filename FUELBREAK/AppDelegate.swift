import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("APNs token: \(token)")
        // TODO: Send `token` to your server at sensaro.net
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("APNs registration failed: \(error)")
    }
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
