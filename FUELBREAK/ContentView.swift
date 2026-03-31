import SwiftUI
private let BASE_URL = "https://www.sensaro.net/Mobile/Forestry_Dashboard"
private let TTTS_BASE_URL = "https://www.sensaro.net/Mobile/TTTS"

struct ContentView: View {
    // Keep one coordinator alive for the whole app lifetime
    @StateObject private var coordinator = AppCoordinator()

    var body: some View {
        TabView {
            // ── Tab 1: Report a Concern ──────────────────────────
            ForestryWebView(
                url: URL(string: "\(BASE_URL)/dashboard.html")!,
                coordinator: coordinator
            )
            .ignoresSafeArea()
            .tabItem {
                Label("Report", systemImage: "camera.fill")
            }

            // ── Tab 2: Forestry-only Map ─────────────────────────
            ForestryWebView(
                url: URL(string: "\(BASE_URL)/Display_Maps/Forestry/index.html")!,
                coordinator: coordinator
            )
            .ignoresSafeArea()
            .tabItem {
                Label("Forestry Map", systemImage: "leaf.fill")
            }

            // ── Tab 3: Wildfire + Forestry Map ───────────────────
            ForestryWebView(
                url: URL(string: "\(BASE_URL)/Display_Maps/index.html")!,
                coordinator: coordinator
            )
            .ignoresSafeArea()
            .tabItem {
                Label("Wildfire Map", systemImage: "flame.fill")
            }
            
            // ── Tab 4: TTTS Management Tool Testing ───────────────────
            //ForestryWebView(
            //    url: URL(string: "\(TTTS_BASE_URL)/index.html")!,
            //    coordinator: coordinator
            //)
            //.ignoresSafeArea()
            //.tabItem {
            //    Label("Twin Timbers Trees", systemImage: "person.fill")
            //}

        }
        // Forest green accent to match your existing dark-green theme
        .tint(Color(red: 0.19, green: 0.44, blue: 0.31))
    }
}
