import SwiftUI

private let BASE_URL      = "https://www.sensaro.net/Mobile/Forestry_Dashboard"
private let TTTS_BASE_URL = "https://www.sensaro.net/Mobile/TTTS" // reserved for testing

// Tab index constants — keep these in sync with the TabView order below
private enum Tab {
    static let dashboard = 0
    static let forestry  = 1
    static let wildfire  = 2
    static let account   = 3
    static let test      = 4
}

struct ContentView: View {

    // One coordinator shared across all tabs (single CLLocationManager, single image picker)
    @StateObject private var coordinator = AppCoordinator()

    // Drives programmatic tab switching from notification taps
    @State private var selectedTab = Tab.dashboard
    let keyMap = [0: "dashboard", 1: "forestry", 2: "wildfire", 3: "account"]

    var body: some View {
        TabView(selection: $selectedTab) {

            ForestryWebView(url: URL(string: "\(BASE_URL)/dashboard.html")!, key: "dashboard", coordinator: coordinator)
                .ignoresSafeArea()
                .tag(Tab.dashboard)
                .tabItem { Label("Dashboard", systemImage: "camera.fill") }

            ForestryWebView(url: URL(string: "\(BASE_URL)/Display_Maps/Forestry/index.html")!, key: "forestry", coordinator: coordinator)
                .ignoresSafeArea()
                .tag(Tab.forestry)
                .tabItem { Label("Forestry Map", systemImage: "leaf.fill") }

            ForestryWebView(url: URL(string: "\(BASE_URL)/Display_Maps/index.html")!, key: "wildfire", coordinator: coordinator)
                .ignoresSafeArea()
                .tag(Tab.wildfire)
                .tabItem { Label("Wildfire Map", systemImage: "flame.fill") }

            ForestryWebView(url: URL(string: "\(BASE_URL)/user.html")!, key: "account", coordinator: coordinator)
                .ignoresSafeArea()
                .tag(Tab.account)
                .tabItem { Label("Account", systemImage: "person.fill") }

            // ── TEMPORARY — delete before shipping ──────────────────
            Button("Fire Test Notification") {
                scheduleTestNotification()
            }
            .padding()
            .tag(Tab.test)
            .tabItem { Label("Test", systemImage: "bell.fill") }
        }
        .tint(Color(red: 0.19, green: 0.44, blue: 0.31))
        .onChange(of: selectedTab) {
            if let key = keyMap[selectedTab] {
                coordinator.reloadTab(key)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToTarget)) { notif in
            guard
                let tab    = notif.userInfo?["tab"]    as? String,
                let target = notif.userInfo?["target"] as? String
            else { return }

            let tabMap = ["dashboard": Tab.dashboard, "forestry": Tab.forestry,
                          "wildfire": Tab.wildfire, "account": Tab.account]
            if let index = tabMap[tab] { selectedTab = index }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                coordinator.navigateTo(tab: tab, elementId: target)
            }
        }
    }
}
