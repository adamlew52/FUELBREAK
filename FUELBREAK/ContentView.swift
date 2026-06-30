import SwiftUI

private let DASHBOARD_URL = "https://www.sensaro.net/Desktop/Forestry_Dashboard/dashboard.html"
private let DASHBOARD_KEY = "dashboard"

struct ContentView: View {

    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var storeKitManager = StoreKitManager()

    var body: some View {
        ForestryWebView(
            url: URL(string: DASHBOARD_URL)!,
            key: DASHBOARD_KEY,
            coordinator: coordinator
        )
        .ignoresSafeArea()
        .background(
            Color(red: 0.96, green: 0.61, blue: 0.04)
                .ignoresSafeArea()
        )

        .onAppear {
            coordinator.storeKitManager = storeKitManager
        }

        // ── Native paywall sheet — unchanged, web page calls openPaywall ──
        .sheet(isPresented: $coordinator.showPaywall) {
            PaywallView(
                idToken: coordinator.paywallIdToken,
                onPurchaseComplete: { creditsAdded in
                    coordinator.notifyWebViewOfPurchase(creditsAdded: creditsAdded)
                }
            )
            .environmentObject(storeKitManager)
        }

        // ── Push notification tap → scroll/click target element ───────────
        // dashboard.html's own sidebar now handles all panel navigation,
        // so this just needs to target the single webview and the element.
        .onReceive(NotificationCenter.default.publisher(for: .navigateToTarget)) { notif in
            guard let target = notif.userInfo?["target"] as? String else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                coordinator.navigateTo(tab: DASHBOARD_KEY, elementId: target)
            }
        }
    }
}
