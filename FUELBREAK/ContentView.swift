import SwiftUI

private let BASE_URL = "https://www.sensaro.net/Mobile/Forestry_Dashboard"

private enum Tab {
    static let dashboard = 0
    static let forestry  = 1
    static let wildfire  = 2
    static let account   = 3
}

struct ContentView: View {

    @StateObject private var coordinator = AppCoordinator()
    @State private var selectedTab = Tab.dashboard

    private let keyMap = [
        Tab.dashboard : "dashboard",
        Tab.forestry  : "forestry",
        Tab.wildfire  : "wildfire",
        Tab.account   : "account"
    ]

    var body: some View {
        TabView(selection: $selectedTab) {

            ForestryWebView(
                url: URL(string: "\(BASE_URL)/dashboard.html")!,
                key: "dashboard",
                coordinator: coordinator
            )
            .tag(Tab.dashboard)
            .tabItem { Label("Dashboard", systemImage: "camera.fill") }

            ForestryWebView(
                url: URL(string: "\(BASE_URL)/Display_Maps/Forestry/index.html")!,
                key: "forestry",
                coordinator: coordinator
            )
            .tag(Tab.forestry)
            .tabItem { Label("Forestry Map", systemImage: "leaf.fill") }

            ForestryWebView(
                url: URL(string: "\(BASE_URL)/Display_Maps/index.html")!,
                key: "wildfire",
                coordinator: coordinator
            )
            .tag(Tab.wildfire)
            .tabItem { Label("Wildfire Map", systemImage: "flame.fill") }

            ForestryWebView(
                url: URL(string: "\(BASE_URL)/user.html")!,
                key: "account",
                coordinator: coordinator
            )
            .tag(Tab.account)
            .tabItem { Label("Account", systemImage: "person.fill") }
        }
        // ── Applied to the TabView, not to children ──────────────
        .ignoresSafeArea()
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

            let tabMap = [
                "dashboard" : Tab.dashboard,
                "forestry"  : Tab.forestry,
                "wildfire"  : Tab.wildfire,
                "account"   : Tab.account
            ]
            if let index = tabMap[tab] { selectedTab = index }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                coordinator.navigateTo(tab: tab, elementId: target)
            }
        }
    }
}
