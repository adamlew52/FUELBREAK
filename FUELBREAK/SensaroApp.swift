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
        // 1. Tab Bar Appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.19, green: 0.39, blue: 0.19, alpha: 1.0)
        
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(red: 0.19, green: 0.44, blue: 0.31, alpha: 1.0)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0.19, green: 0.44, blue: 0.31, alpha: 1.0)
        ]
        appearance.stackedLayoutAppearance.normal.iconColor = .darkGray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.darkGray
        ]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        
        // 2. Top Margin (Window Background) Colour
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                for window in windowScene.windows {
                    window.backgroundColor = UIColor(red: 0.84, green: 0.8, blue: 0.0, alpha: 1.0)
                }
            }
        }
    }
}
