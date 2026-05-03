import SwiftUI
import StoreKit

// MARK: - PaywallView
struct PaywallView: View {

    @StateObject private var store = StoreKitManager()

    let idToken: String
    var onPurchaseComplete: ((Int) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var showSuccessAlert = false
    @State private var showErrorAlert   = false
    @State private var alertMessage     = ""
    @State private var successMessage   = ""

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.12, blue: 0.04).ignoresSafeArea()
            RadialGradient(
                colors: [Color(red: 0.19, green: 0.44, blue: 0.19).opacity(0.35), Color.clear],
                center: .top, startRadius: 0, endRadius: 400
            ).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    planCardsSection
                    paygSection
                    enterpriseSection
                    footerButtons
                }
                .padding(.bottom, 40)
            }
        }
        .overlay(purchaseOverlay)
        .alert("Purchase Complete", isPresented: $showSuccessAlert) {
            Button("Done") { dismiss() }
        } message: { Text(successMessage) }
        .alert("Something Went Wrong", isPresented: $showErrorAlert) {
            Button("OK") { }
        } message: { Text(alertMessage) }
        .onChange(of: store.purchaseState) { state in handlePurchaseState(state) }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2).foregroundColor(.white.opacity(0.5))
                }
                .padding(.trailing, 20).padding(.top, 16)
            }
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.96, green: 0.61, blue: 0.04), Color(red: 0.85, green: 0.40, blue: 0.02)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 72, height: 72)
                Image(systemName: "flame.fill").font(.system(size: 34)).foregroundColor(.white)
            }
            .shadow(color: Color(red: 0.96, green: 0.61, blue: 0.04).opacity(0.5), radius: 20)
            Text("Sensaro Credits")
                .font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(.white)
            Text("Run wildfire risk assessments.\nPay once or subscribe for savings.")
                .font(.system(size: 15)).foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center).padding(.horizontal, 40)
        }
        .padding(.bottom, 28)
    }

    private var planCardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {

            // ── Visible diagnostic banner when StoreKit returns nothing ──
            if !store.isLoadingProducts && store.products.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Color(red: 0.96, green: 0.61, blue: 0.04))

                    Text("Products Not Loading")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)

                    Text("StoreKit returned 0 products. Check:")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))

                    VStack(alignment: .leading, spacing: 8) {
                        DiagRow(text: "Scheme → Run → Options → StoreKit Config = Sensaro.storekit")
                        DiagRow(text: "Sensaro.storekit is checked under File Inspector → Target Membership")
                        DiagRow(text: "Product IDs in .storekit match SensaroProduct enum exactly")
                        DiagRow(text: "Clean build folder (⇧⌘K) then re-run")
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))

                    Button(action: { Task { await store.loadProducts() } }) {
                        Text("Retry Loading Products")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color(red: 0.96, green: 0.61, blue: 0.04)))
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(red: 0.96, green: 0.61, blue: 0.04).opacity(0.5), lineWidth: 1.5))
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }

            SectionLabel(text: "SUBSCRIBE FOR RECURRING CREDITS")
            HStack(spacing: 12) {
                SubscriptionCard(
                    title: "Monthly", price: store.formattedPrice(for: .monthly),
                    period: "/ month", credits: "100 credits / month",
                    accent: Color(red: 0.19, green: 0.55, blue: 0.35), isBest: false,
                    isActive: store.activeSubscription?.id == SensaroProduct.monthly.rawValue,
                    isLoading: store.isLoadingProducts
                ) { Task { await purchase(.monthly) } }

                SubscriptionCard(
                    title: "Yearly", price: store.formattedPrice(for: .yearly),
                    period: "/ year", credits: "1,500 credits / year",
                    accent: Color(red: 0.96, green: 0.61, blue: 0.04), isBest: true,
                    isActive: store.activeSubscription?.id == SensaroProduct.yearly.rawValue,
                    isLoading: store.isLoadingProducts
                ) { Task { await purchase(.yearly) } }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 16)
    }

    private var paygSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "PAY-AS-YOU-GO")
            PAYGCard(price: store.formattedPrice(for: .payg50), isLoading: store.isLoadingProducts) {
                Task { await purchase(.payg50) }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 16)
    }

    private var enterpriseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "ENTERPRISE")
            Button(action: openEnterprise) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Custom / Unlimited")
                            .font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                        Text("Fire Departments, Foresters, Private Companies")
                            .font(.system(size: 13)).foregroundColor(.white.opacity(0.55))
                    }
                    Spacer()
                    Image(systemName: "envelope.fill")
                        .foregroundColor(Color(red: 0.96, green: 0.61, blue: 0.04))
                }
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1)))
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 28)
    }

    private var footerButtons: some View {
        VStack(spacing: 14) {
            Button(action: { Task { await store.restorePurchases(idToken: idToken) } }) {
                Text("Restore Purchases")
                    .font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.5))
            }
            Text("Subscriptions auto-renew. Cancel anytime in Settings → Apple ID → Subscriptions.")
                .font(.system(size: 11)).foregroundColor(.white.opacity(0.3))
                .multilineTextAlignment(.center).padding(.horizontal, 30)
        }
    }

    @ViewBuilder
    private var purchaseOverlay: some View {
        if store.purchaseState == .purchasing {
            ZStack {
                Color.black.opacity(0.6).ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView().scaleEffect(1.4).tint(.white)
                    Text("Processing…").font(.system(size: 15, weight: .medium)).foregroundColor(.white)
                }
                .padding(32)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color(red: 0.1, green: 0.1, blue: 0.1)))
            }
        }
    }

    private func purchase(_ sensaroProduct: SensaroProduct) async {
        await store.purchase(sensaroProduct, idToken: idToken)
    }

    private func openEnterprise() {
        if let url = URL(string: "mailto:contact@sensaro.net?subject=Enterprise%20Inquiry") {
            UIApplication.shared.open(url)
        }
    }

    private func handlePurchaseState(_ state: PurchaseState) {
        switch state {
        case .success(let productID, let credits):
            onPurchaseComplete?(credits)   // ← notifies ContentView → refreshes WebViews
            let name = SensaroProduct(rawValue: productID)?.displayName ?? "plan"
            successMessage = "You now have \(credits) additional credits from \(name)."
            showSuccessAlert = true
        case .failed(let msg):
            alertMessage = msg
            showErrorAlert = true
        default:
            break
        }
    }
}

private struct SubscriptionCard: View {
    let title: String; let price: String; let period: String; let credits: String
    let accent: Color; let isBest: Bool; let isActive: Bool; let isLoading: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                if isBest {
                    Text("BEST VALUE").font(.system(size: 10, weight: .bold)).foregroundColor(.black)
                        .padding(.horizontal, 10).padding(.vertical, 4).background(accent)
                        .clipShape(Capsule()).padding(.top, 12)
                } else {
                    Color.clear.frame(height: 26).padding(.top, 12)
                }
                Spacer(minLength: 12)
                Text(title).font(.system(size: 17, weight: .semibold, design: .rounded)).foregroundColor(.white)
                Spacer(minLength: 8)
                if isLoading {
                    ProgressView().tint(.white).padding(.vertical, 8)
                } else {
                    Text(price).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(accent)
                    Text(period).font(.system(size: 12)).foregroundColor(.white.opacity(0.5))
                }
                Spacer(minLength: 12)
                Text(credits).font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                Spacer(minLength: 16)
                Text(isActive ? "Current Plan" : "Subscribe")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isActive ? .white.opacity(0.6) : .black)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10)
                        .fill(isActive ? Color.white.opacity(0.15) : accent))
                    .padding(.horizontal, 14).padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(isBest ? accent.opacity(0.6) : Color.white.opacity(0.1),
                            lineWidth: isBest ? 1.5 : 1)))
        }
        .buttonStyle(.plain)
        .disabled(isActive || isLoading)
    }
}

private struct PAYGCard: View {
    let price: String; let isLoading: Bool; let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.96, green: 0.61, blue: 0.04).opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: "bolt.fill").font(.system(size: 22))
                        .foregroundColor(Color(red: 0.96, green: 0.61, blue: 0.04))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("NOW INTRODUCING").font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(red: 0.96, green: 0.61, blue: 0.04))
                    Text("Pay-As-You-Go").font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("50 calls · one-time purchase · reusable")
                        .font(.system(size: 12)).foregroundColor(.white.opacity(0.55))
                }
                Spacer()
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    VStack(spacing: 2) {
                        Text(price).font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Buy").font(.system(size: 12, weight: .semibold)).foregroundColor(.black)
                            .padding(.horizontal, 14).padding(.vertical, 5)
                            .background(Capsule().fill(Color(red: 0.96, green: 0.61, blue: 0.04)))
                    }
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(red: 0.96, green: 0.61, blue: 0.04).opacity(0.4), lineWidth: 1.5)))
        }
        .buttonStyle(.plain).disabled(isLoading)
    }
}

private struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 11, weight: .bold)).foregroundColor(.white.opacity(0.35))
            .tracking(1.5).padding(.horizontal, 20)
    }
}

private struct DiagRow: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.96, green: 0.61, blue: 0.04))
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview { PaywallView(idToken: "preview-token") }
