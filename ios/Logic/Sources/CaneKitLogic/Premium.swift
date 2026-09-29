//
//  Premium.swift
//  CaneKitLogic
//
//  OpenCane Premium (Step 69.5, RevenueCat Shipaton): what it unlocks, when the paywall may
//  appear, what a refused request says, and the paywall's price words. Pure decisions and strings;
//  the store itself (RevenueCat) is `EntitlementManager` in the app.
//
//  The owner's rules, each pinned in PremiumGateTests.swift:
//    · Exactly two benefits are gated: **advanced AI object detection** — the vision-model Hazard
//      watch (cones, barriers, scooters) and Name people ahead — and **Grok Bot + Family Alerts**.
//      Everything else is free, including every safety feature: LiDAR obstacle detection, haptics,
//      spatial audio, speech, drop-off / sign / siren warnings, navigation, emergency calling.
//    · The paywall never appears during a walk (a route guiding, starting or being built, an indoor
//      route, a simulated walk). A tap on a gated switch mid-walk is refused in words instead.
//    · A lapse detected mid-walk never switches a feature off under the walker; it waits for the
//      walk to end.
//    · A build without a RevenueCat key (a fresh clone, XCUITests, e2e) unlocks everything, so no
//      behaviour that existed before the store changes for the people and tests that relied on it.
//
//  Callers: `EntitlementManager` (identifiers), `AppModel+Premium` (every decision), `PaywallView`
//  and `PremiumSettingsCard` (benefit and price words), `HazardsCard` / the Family alerts card
//  (which switches carry the Premium badge).
//  Tests: PremiumGateTests.swift.
//

import Foundation

/// What the walker's subscription allows right now.
public enum PremiumAccess: String, Sendable, Equatable {
    /// RevenueCat has not answered yet (the first moments after launch).
    case checking
    /// No active `premium` entitlement.
    case free
    /// The `premium` entitlement is active.
    case premium
    /// This build has no RevenueCat key: the store does not exist, and nothing is locked.
    case notConfigured

    /// True when the gated features may run.
    public var unlocks: Bool { self == .premium || self == .notConfigured }
}

/// The two things OpenCane Premium adds, as the paywall lists them.
public enum PremiumBenefit: String, CaseIterable, Sendable {
    case advancedDetection
    case familyAlerts

    /// Feature-row title.
    public var title: String {
        switch self {
        case .advancedDetection: "Advanced AI object detection"
        case .familyAlerts: "Grok Bot and Family Alerts"
        }
    }

    /// One line under the title.
    public var detail: String {
        switch self {
        case .advancedDetection: "Hazard watch spots cones, barriers and scooters on your route, and OpenCane can count the people ahead."
        case .familyAlerts: "Your family hears about a fall, a close call or a low battery, with a one-line summary."
        }
    }

    /// SF Symbol for the row.
    public var systemImage: String {
        switch self {
        case .advancedDetection: "sparkles"
        case .familyAlerts: "person.2.fill"
        }
    }
}

/// A switch that needs Premium to turn on.
public enum PremiumFeature: String, CaseIterable, Sendable, Identifiable {
    /// "Hazard watch" (Details → Hazards): the vision model checks the path every 8 s on a route.
    case hazardWatch
    /// "Name people ahead" (Details → Hazards): people counting in "Where am I".
    case namePeople
    /// "Alert my family" (Settings → Family alerts): cane events to the Grok Bot routine.
    case familyAlerts

    public var id: String { rawValue }

    /// Which paywall benefit this switch belongs to.
    public var benefit: PremiumBenefit {
        switch self {
        case .hazardWatch, .namePeople: .advancedDetection
        case .familyAlerts: .familyAlerts
        }
    }

    /// The switch's name as the walker knows it (spoken in refusals).
    public var spokenName: String {
        switch self {
        case .hazardWatch: "Hazard watch"
        case .namePeople: "Name people ahead"
        case .familyAlerts: "Family alerts"
        }
    }

    /// The premium feature behind a hands-free option (`HandsFreeOption.rawValue` in the app), or
    /// nil for every option that stays free — which includes every warning channel.
    public init?(handsFreeOption raw: String) {
        switch raw {
        case "hazardWatch": self = .hazardWatch
        case "namePeople": self = .namePeople
        default: return nil
        }
    }
}

/// The gate's decisions.
public enum PremiumGate {
    /// RevenueCat entitlement identifier (dashboard → Entitlements).
    public static let entitlementID = "premium"
    /// The one product: an annual auto-renewing subscription, $49.99 (App Store Connect + the
    /// StoreKit configuration file `ios/StoreKit/OpenCane.storekit`).
    public static let productID = "opencane_premium_annual"
    /// RevenueCat offering identifier; `Offerings.current` is the fallback.
    public static let offeringID = "default"

    /// What happens when the walker asks to turn a gated switch on.
    public enum Decision: Sendable, Equatable {
        /// Turn it on.
        case allow
        /// Open the paywall (a screen tap, not walking).
        case showPaywall
        /// Mid-walk: never a paywall. Say `walkLine` instead.
        case refuseDuringWalk
        /// A voice / Siri request cannot show a sheet: say `premiumLine(for:)`.
        case refuseSpoken
    }

    /// Turning a gated switch ON.
    /// - Parameters:
    ///   - access: the subscription state now.
    ///   - walkActive: a route guiding, starting or being built, an indoor route, a simulated walk.
    ///   - fromScreen: a tap on the switch (true) or a voice / Siri command (false).
    public static func decideEnable(access: PremiumAccess, walkActive: Bool, fromScreen: Bool) -> Decision {
        if access.unlocks { return .allow }
        if walkActive { return .refuseDuringWalk }
        return fromScreen ? .showPaywall : .refuseSpoken
    }

    /// Turning a gated switch OFF: always allowed.
    public static func decideDisable(access: PremiumAccess) -> Decision { .allow }

    /// Whether a paywall may be presented at all right now.
    public static func mayPresentPaywall(walkActive: Bool) -> Bool { !walkActive }

    /// Whether gated switches that are on should be switched off now: only after a confirmed
    /// lapse (`.free`, never `.checking`) and never during a walk — the walk's end re-checks.
    public static func revokesNow(access: PremiumAccess, walkActive: Bool) -> Bool {
        access == .free && !walkActive
    }

    /// Spoken when a voice / Siri request asks for a gated feature on the free plan.
    public static func premiumLine(for feature: PremiumFeature) -> String {
        "\(feature.spokenName) is part of OpenCane Premium. You can subscribe in Settings."
    }

    /// Spoken (and shown under the switch) when a gated switch is tapped mid-walk.
    public static let walkLine = "Premium features can be turned on after this walk."
}

/// The paywall's price words.
public enum PaywallPricing {
    /// The owner's affordability note, verbatim.
    public static let affordabilityNote = "OpenCane is a social good project and we want it to be affordable for everyone. Premium may be eligible for reimbursement through your insurance, HSA/FSA, or vision rehabilitation program. Check with your plan."

    /// Annual price ÷ 12, rounded **down** to the cent, so the per-month figure never overstates
    /// the saving. Fallback only: the paywall prefers the store's own `localizedPricePerMonth`.
    public static func perMonth(annual: Decimal) -> Decimal {
        var monthly = annual / 12
        var rounded = Decimal()
        NSDecimalRound(&rounded, &monthly, 2, .down)
        return rounded
    }

    /// "$49.99/year" — the headline price, as the brief writes it.
    public static func priceLine(localizedPrice: String) -> String { "\(localizedPrice)/year" }

    /// "Just $4.16 a month, billed yearly" — under the headline.
    public static func perMonthLine(localizedPerMonth: String) -> String {
        "Just \(localizedPerMonth) a month, billed yearly"
    }

    /// The price block's VoiceOver label: whole sentences, no slash.
    public static func spokenOffer(localizedPrice: String, localizedPerMonth: String?) -> String {
        let month = localizedPerMonth.map { ", about \($0) a month" } ?? ""
        return "OpenCane Premium costs \(localizedPrice) per year\(month). It renews automatically every year until you cancel."
    }

    /// The auto-renewal disclosure under the Subscribe button (App Store Review Guideline 3.1.2).
    public static func renewalTerms(localizedPrice: String) -> String {
        "\(localizedPrice) is charged to your Apple Account when you subscribe, and again every year. The subscription renews automatically unless you cancel at least 24 hours before the end of the current year. Manage or cancel it any time in Settings."
    }
}
