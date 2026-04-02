import SwiftUI
import UserNotifications

@main
struct SensaroApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        requestNotificationPermission()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                guard granted else { return }
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
    }
}
