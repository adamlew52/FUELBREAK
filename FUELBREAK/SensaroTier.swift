import Foundation
import SwiftUI

// ═══════════════════════════════════════════════════════════════════════════
//  SensaroTier.swift
//
//  SINGLE SOURCE OF TRUTH for subscription tiers and feature gating on iOS.
//  This file is mirrored, deliberately, by `entitlements.js` on the web side.
//  If you change a tier rank, a product ID, or a feature's minimum tier HERE,
//  make the identical change THERE — otherwise the app and the web dashboard
//  will disagree about what a paying user is allowed to open.
//
//  Nothing in this file is authoritative for billing. The server (Cognito
//  `custom:tier`, written by the Apple IAP verify Lambda and the Stripe
//  webhook) is authoritative. Everything here is (a) UI gating and (b) an
//  offline fallback derived from StoreKit's own signed entitlements.
// ═══════════════════════════════════════════════════════════════════════════


// MARK: - Tier

enum SensaroTier: String, CaseIterable, Codable, Comparable {
    case free
    case bronze
    case silver
    case gold

    /// Ordering rank. Higher wins. Used for `>=` comparisons in gating.
    var rank: Int {
        switch self {
        case .free:   return 0
        case .bronze: return 1
        case .silver: return 2
        case .gold:   return 3
        }
    }

    static func < (lhs: SensaroTier, rhs: SensaroTier) -> Bool { lhs.rank < rhs.rank }

    var displayName: String {
        switch self {
        case .free:   return "Free"
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold:   return "Gold"
        }
    }

    /// One line, written from the user's side of the screen — what you get,
    /// not what the system does.
    var blurb: String {
        switch self {
        case .free:   return "Live map, alerts, and wildfire reporting."
        case .bronze: return "Risk scoring and fuel data for your own property."
        case .silver: return "Prediction models, area analysis, and structure mapping."
        case .gold:   return "Perimeter modelling, evidence archive, and priority support."
        }
    }

    var accent: Color {
        switch self {
        case .free:   return Color(red: 0.42, green: 0.55, blue: 0.45)  // #6c8b74 sage
        case .bronze: return Color(red: 0.79, green: 0.47, blue: 0.25)  // #c9793f copper
        case .silver: return Color(red: 0.62, green: 0.70, blue: 0.78)  // #9fb3c8 pewter
        case .gold:   return Color(red: 0.90, green: 0.66, blue: 0.17)  // #e6a92b ember gold
        }
    }

    /// Tolerant parser for whatever the backend hands back. Accepts the tier
    /// name in any case, and falls back to the legacy `custom:paid` model so
    /// existing subscribers are not locked out mid-migration.
    static func parse(_ raw: Any?, legacyPaid: Any? = nil) -> SensaroTier {
        if let s = raw as? String,
           let t = SensaroTier(rawValue: s.trimmingCharacters(in: .whitespaces).lowercased()) {
            return t
        }
        // Legacy: anyone who was `custom:paid == 1` before the tier migration
        // is grandfathered to Bronze until their next renewal reconciles.
        if let p = legacyPaid, "\(p)" == "1" { return .bronze }
        return .free
    }
}


// MARK: - Features

/// Every gateable surface in the app. The raw value MUST match the `data-panel`
/// id used by dashboard.html, so a single map covers native and web.
enum SensaroFeature: String, CaseIterable {

    // Overview
    case home             = "home"
    case alerts           = "alerts"

    // Prediction
    case wildfireRisk     = "wildfire-risk"
    case locationRisk     = "location-risk"
    case wildfirePredict  = "wildfire-predict"
    case areaRisk         = "area-risk"
    case mpbPredict       = "mpb-predict"
    case perimeterPredict = "perimeter-predict"

    // Maps
    case fuelMap          = "fuel-map"
    case structureMap     = "structure-map"
    case forestryMap      = "forestry-map"
    case wildfireMap      = "wildfire-map"

    // Field tools
    case reportWildfire   = "report-wildfire"
    case report           = "report"
    case resources        = "resources"
    case morningBriefing  = "morning-briefing"
    case subscribe        = "subscribe"

    // Research
    case evidence         = "evidence"
    case partners         = "partners"

    /// The lowest tier that may open this feature.
    ///
    /// Note on `reportWildfire`: this stays FREE permanently and is not a
    /// pricing decision to revisit. Putting wildfire reporting behind a
    /// paywall would mean a person who sees smoke cannot tell anyone.
    var minimumTier: SensaroTier {
        switch self {
        case .home, .alerts, .forestryMap, .reportWildfire,
             .report, .resources, .subscribe, .partners:
            return .free

        case .wildfireRisk, .locationRisk, .fuelMap, .morningBriefing:
            return .bronze

        case .wildfirePredict, .areaRisk, .mpbPredict, .structureMap:
            return .silver

        case .perimeterPredict, .evidence, .wildfireMap:
            return .gold
        }
    }

    var title: String {
        switch self {
        case .home:             return "Dashboard"
        case .alerts:           return "Alert Center"
        case .wildfireRisk:     return "Wildfire Risk Calculation"
        case .locationRisk:     return "Location Risk Report"
        case .wildfirePredict:  return "Ignition Point Prediction"
        case .areaRisk:         return "Area Risk Assessment"
        case .mpbPredict:       return "Pine Beetle Spread"
        case .perimeterPredict: return "Predict from Perimeter"
        case .fuelMap:          return "Fuel Map"
        case .structureMap:     return "Structure Map"
        case .forestryMap:      return "Forestry Map"
        case .wildfireMap:      return "Wildfire Monitor"
        case .reportWildfire:   return "Report a Wildfire"
        case .report:           return "Report a Concern"
        case .resources:        return "Field Resources"
        case .morningBriefing:  return "Morning Briefing"
        case .subscribe:        return "Notification Settings"
        case .evidence:         return "Evidence Viewer"
        case .partners:         return "Preferred Partners"
        }
    }

    /// Features unlocked *at* a given tier (not inherited ones) — used to build
    /// the paywall's "what's new at this level" lists.
    static func unlocked(at tier: SensaroTier) -> [SensaroFeature] {
        allCases.filter { $0.minimumTier == tier }
    }
}


// MARK: - Products

enum BillingPeriod: String {
    case monthly
    case yearly
    case lifetime

    var suffix: String {
        switch self {
        case .monthly:  return "/ month"
        case .yearly:   return "/ year"
        case .lifetime: return "once"
        }
    }
}

enum SensaroProduct: String, CaseIterable {

    case bronzeMonthly = "net.sensaro.v2.bronze.monthly"
    case bronzeYearly  = "net.sensaro.v2.bronze.yearly"
    case silverMonthly = "net.sensaro.v2.silver.monthly"
    case silverYearly  = "net.sensaro.v2.silver.yearly"
    case goldMonthly   = "net.sensaro.v2.gold.monthly"
    case goldYearly    = "net.sensaro.v2.gold.yearly"

    /// Non-consumable. Grants Gold forever, never expires, restores across
    /// devices via `AppStore.sync()`. Lives OUTSIDE the subscription group.
    case goldLifetime  = "net.sensaro.lifetime.gold"

    var tier: SensaroTier {
        switch self {
        case .bronzeMonthly, .bronzeYearly: return .bronze
        case .silverMonthly, .silverYearly: return .silver
        case .goldMonthly, .goldYearly, .goldLifetime: return .gold
        }
    }

    var period: BillingPeriod {
        switch self {
        case .bronzeMonthly, .silverMonthly, .goldMonthly: return .monthly
        case .bronzeYearly, .silverYearly, .goldYearly:    return .yearly
        case .goldLifetime:                                return .lifetime
        }
    }

    var isSubscription: Bool { period != .lifetime }

    /// Shown only while StoreKit is still loading or if the product request
    /// fails outright. Real prices always come from `Product.displayPrice`,
    /// which is already localized and currency-correct.
    var fallbackPrice: String {
        switch self {
        case .bronzeMonthly: return "$4.99"
        case .bronzeYearly:  return "$49.99"
        case .silverMonthly: return "$9.99"
        case .silverYearly:  return "$99.99"
        case .goldMonthly:   return "$19.99"
        case .goldYearly:    return "$199.99"
        case .goldLifetime:  return "$499.99"
        }
    }

    static func forTier(_ tier: SensaroTier, period: BillingPeriod) -> SensaroProduct? {
        allCases.first { $0.tier == tier && $0.period == period }
    }

    /// LEGACY — the pre-migration credit products. Kept ONLY so that
    /// `currentEntitlements` doesn't log them as unknown, and so a user who
    /// still holds an unexpired legacy subscription gets grandfathered rather
    /// than silently downgraded. Do not sell these; remove them from App Store
    /// Connect once the last legacy term has lapsed.
    static let legacyGrandfathered: [String: SensaroTier] = [
        "net.sensaro.sub.monthly": .bronze,
        "net.sensaro.sub.yearly":  .bronze,
    ]
}


// MARK: - Credits (dormant)

/// Credit accounting is switched OFF in the tier model — access is decided by
/// `SensaroTier`, not by a balance. The hooks below stay in place so metering
/// can be re-enabled per tier later (e.g. capping expensive model runs) without
/// re-plumbing the purchase flow.
///
/// To re-enable: set `creditsEnabled = true`, give each tier a non-zero
/// `monthlyCredits`, and have the verify Lambda return `creditsRemaining` in
/// its response. `StoreKitManager.creditsRemaining` is already wired to read it.
enum SensaroCredits {
    static let enabled = false

    static func monthlyAllowance(for tier: SensaroTier) -> Int? {
        guard enabled else { return nil }
        switch tier {
        case .free:   return 5
        case .bronze: return 50
        case .silver: return 250
        case .gold:   return nil   // nil == unmetered
        }
    }
}
