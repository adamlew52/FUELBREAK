import SwiftUI
import UserNotifications

@main
struct SensaroApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        requestNotificationPermission()
        configureTabBar()
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
    private func configureTabBar() {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            
            // Background colour (your green)
            appearance.backgroundColor = UIColor(red: 0.15, green: 1.00, blue: 0.42, alpha: 1.0)
            
            // Selected item colour (your dark green)
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor(red: 0.19, green: 0.44, blue: 0.31, alpha: 1.0)
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .foregroundColor: UIColor(red: 0.19, green: 0.44, blue: 0.31, alpha: 1.0)
            ]
            
            // Unselected item colour (dark grey)
            appearance.stackedLayoutAppearance.normal.iconColor = .darkGray
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .foregroundColor: UIColor.darkGray
            ]
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
}
