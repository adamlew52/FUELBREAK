import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error = error {
                    self.showAlert("Permission Error", error.localizedDescription)
                }
                guard granted else {
                    self.showAlert("Permission Denied", "User declined notifications.")
                    return
                }
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        let savedUserId = UserDefaults.standard.string(forKey: "current_user_id") ?? ""

        UserDefaults.standard.set(token, forKey: "apns_device_token")

        NotificationCenter.default.post(
            name: .deviceTokenReceived,
            object: nil,
            userInfo: ["token": token]
        )

        let willAutoRegister = !savedUserId.isEmpty
        if willAutoRegister {
            APNSRegistration.send(token: token, userId: savedUserId)
        }

        // DIAGNOSTIC — remove before final release
        let msg = "Token prefix: \(String(token.prefix(16)))\n\nSaved userId:\n\(savedUserId.isEmpty ? "(none — fresh install)" : savedUserId)\n\nAuto-register fired: \(willAutoRegister ? "YES" : "NO — user must log in")"
        showAlert("APNs Token Received", msg)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        showAlert("APNs Registration Failed", error.localizedDescription)
    }

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

    private func showAlert(_ title: String, _ message: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let root  = scene.windows.first?.rootViewController else { return }
            var top = root
            while let presented = top.presentedViewController { top = presented }
            top.present(alert, animated: true)
        }
    }
}

extension Notification.Name {
    static let navigateToTarget    = Notification.Name("navigateToTarget")
    static let deviceTokenReceived = Notification.Name("deviceTokenReceived")
}
