//
//  AppModel+Premium.swift
//  CaneKit
//
//  The AppModel side of OpenCane Premium (Step 69.5): configuring the store at launch, turning a
//  gated switch on (or opening the paywall for it), refusing mid-walk, and switching a lapsed
//  feature off once no walk is running. The decisions are `PremiumGate` (CaneKitLogic, tested);
//  this is the glue. Kept in an extension so AppModel.swift carries only its stored properties
//  (`store`, `paywallRequest`, `premiumNotice`) and one backstop line per gated property.
//
//  What is gated (owner decision): Hazard watch and Name people ahead (advanced AI object
//  detection), and Family alerts (Grok Bot). Nothing else — never obstacle detection, haptics,
//  spatial audio, speech, drop-off / sign / siren warnings, navigation or emergency calling.
//
//  The walk rule: `isWalkActive` (a route guiding, starting or being built, an indoor route, a
//  simulated walk) means no paywall, ever. A tap on a gated switch mid-walk is refused with
//  `PremiumGate.walkLine` spoken at `.scene` — the lowest band, so it never cuts a warning or a
//  direction (hard rule 8) — and shown under the switch. `RootView` closes an open paywall the
//  moment a walk starts and calls `reconcilePremium()` when one ends.
//
//  Hook lines elsewhere:
//    · AppModel.swift: `let store`, `var paywallRequest`, `var premiumNotice`; the
//      `hazardWatchEnabled` / `namePeopleEnabled` / `familyAlertsEnabled` `didSet` backstop
//      (`refusePremiumEnable`).
//    · HandsFreeIntents.swift `setOption`: voice / Siri requests for a gated option.
//    · RootView: `configurePremium()` at launch, the paywall sheet, the walk-start / walk-end hooks.
//  Tests: `PremiumGateTests` (the decisions). This glue has none (app target).
//

import CaneKitLogic
import Foundation

/// One paywall presentation. `feature` is the switch that opened it (turned on after a purchase),
/// or nil when opened from Settings.
struct PaywallRequest: Identifiable, Equatable {
    let id = UUID()
    let feature: PremiumFeature?
}

extension AppModel {

    /// True while the walker is on a walk of any kind. The paywall never appears while this is true.
    var isWalkActive: Bool {
        nav.isNavigating || routeStartWaiting || isBuildingRoute || indoor.isActive || isSimulatingWalk
    }

    /// Wires `store.onAccessChanged` and configures RevenueCat. Idempotent. Caller: `RootView`'s
    /// launch task (before onboarding ends, so the cached subscription is known early).
    func configurePremium() {
        store.onAccessChanged = { [weak self] in self?.premiumAccessChanged() }
        store.configure()
    }

    /// The `didSet` backstop for the three gated properties: true (refuse) when the store does not
    /// unlock Premium. Logs `premium_refused {feature, access}`. Does not speak — the caller that
    /// knows who asked (screen or voice) says why.
    func refusePremiumEnable(_ feature: PremiumFeature) -> Bool {
        guard !store.unlocksPremium else { return false }
        logger.event("premium_refused", ["feature": feature.rawValue, "access": store.access.rawValue])
        return true
    }

    /// A tap on a gated switch (Hazards card, Family alerts card). Off is always allowed; on is
    /// `PremiumGate.decideEnable(... fromScreen: true)`: turn it on, open the paywall for it, or —
    /// mid-walk — refuse in words.
    func setPremiumFeature(_ feature: PremiumFeature, on: Bool) {
        guard on else { setGatedValue(feature, false); return }
        switch PremiumGate.decideEnable(access: store.access, walkActive: isWalkActive, fromScreen: true) {
        case .allow:
            setGatedValue(feature, true)
        case .showPaywall:
            requestPaywall(for: feature)
        case .refuseDuringWalk, .refuseSpoken:
            refuseDuringWalk(feature)
        }
    }

    /// Opens the paywall unless a walk is running (then says `walkLine` instead). Callers: the
    /// gated switches (through `setPremiumFeature`), the Settings Premium card.
    func requestPaywall(for feature: PremiumFeature?) {
        guard PremiumGate.mayPresentPaywall(walkActive: isWalkActive) else {
            refuseDuringWalk(feature)
            return
        }
        premiumNotice = nil
        paywallRequest = PaywallRequest(feature: feature)
        logger.event("paywall", ["action": "shown", "feature": feature?.rawValue ?? "settings",
                                 "access": store.access.rawValue])
    }

    /// The paywall unlocked Premium (purchase or restore): turn on the switch that opened it.
    /// Logs `paywall {action: unlocked, via}`.
    func premiumUnlocked(from request: PaywallRequest?, via: String) {
        logger.event("paywall", ["action": "unlocked", "via": via,
                                 "feature": request?.feature?.rawValue ?? "settings"])
        if let feature = request?.feature, store.unlocksPremium {
            setGatedValue(feature, true)
        }
    }

    /// Called when a walk ends (`RootView`) and after every access change: clears the walk notice
    /// and switches gated features off after a confirmed lapse — never during a walk.
    func reconcilePremium() {
        if !isWalkActive { premiumNotice = nil }
        guard PremiumGate.revokesNow(access: store.access, walkActive: isWalkActive) else { return }
        for feature in PremiumFeature.allCases where gatedValue(feature) {
            setGatedValue(feature, false)
            logger.event("premium_revoked", ["feature": feature.rawValue])
        }
    }

    /// `store.onAccessChanged`: log the new state, then reconcile.
    private func premiumAccessChanged() {
        logger.event("premium_access", ["access": store.access.rawValue])
        reconcilePremium()
    }

    /// Mid-walk refusal: shown under the switch and spoken at `.scene` (never cuts guidance).
    private func refuseDuringWalk(_ feature: PremiumFeature?) {
        premiumNotice = PremiumGate.walkLine
        speech.say(PremiumGate.walkLine, .scene, ttl: 10)
        logger.event("paywall", ["action": "refused_walk", "feature": feature?.rawValue ?? "settings"])
    }

    /// The live value of a gated switch.
    func gatedValue(_ feature: PremiumFeature) -> Bool {
        switch feature {
        case .hazardWatch: hazardWatchEnabled
        case .namePeople: namePeopleEnabled
        case .familyAlerts: familyAlertsEnabled
        }
    }

    /// Writes a gated switch (the property's own `didSet` persists it and applies it).
    private func setGatedValue(_ feature: PremiumFeature, _ on: Bool) {
        switch feature {
        case .hazardWatch: hazardWatchEnabled = on
        case .namePeople: namePeopleEnabled = on
        case .familyAlerts: familyAlertsEnabled = on
        }
    }
}
