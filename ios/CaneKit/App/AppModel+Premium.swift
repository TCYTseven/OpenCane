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
//  The walk rule: `isWalkActive` (a route guiding, starting or being built, an indoor route or
//  indoor recording, a simulated walk) means no paywall, ever. A tap on a gated switch mid-walk is
//  refused with `PremiumGate.walkLine` shown under the switch and spoken at `.scene` — the lowest
//  band, so it never cuts a warning, a sign or a direction. Every Premium line (refusals, the
//  voice path, a lapse) is `.scene` for the same reason (review round 69.7). `RootView` closes an
//  open paywall the moment a walk starts and calls `reconcilePremium()` when one ends; an unlock
//  that lands mid-walk waits for that call too (`pendingPremiumFeature`).
//
//  A lapse is never silent and never permanent (review round 69.7): the switches it turns off are
//  spoken (`PremiumGate.revokedLine`) and remembered (`revokedFeaturesKey`), and switched back on
//  when Premium returns. Family alerts is only ever switched on when the alert service is set up
//  on this phone (`family.isConfigured`): a paid switch that cannot deliver must not claim to.
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
    /// Review round 69.7 added indoor recording (a helper walks the building with the phone).
    var isWalkActive: Bool {
        nav.isNavigating || routeStartWaiting || isBuildingRoute || indoor.isActive
            || indoor.isRecording || indoor.isFinishingExit || isSimulatingWalk
    }

    /// `UserDefaults` key of the features a lapse switched off, to switch back on with Premium.
    static let revokedFeaturesKey = "premiumRevokedFeatures"

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
        // The Family alerts switch is disabled without the alert service; this is its backstop.
        guard canDeliver(feature) else { return }
        switch PremiumGate.decideEnable(access: store.access, walkActive: isWalkActive, fromScreen: true) {
        case .allow:
            setGatedValue(feature, true)
        case .showPaywall:
            requestPaywall(for: feature)
        case .refuseDuringWalk, .refuseSpoken, .refuseChecking:
            refuseDuringWalk(feature)
        }
    }

    /// Whether this phone can run the feature at all (Family alerts needs the alert service key).
    func canDeliver(_ feature: PremiumFeature) -> Bool {
        feature != .familyAlerts || family.isConfigured
    }

    /// Opens the paywall unless a walk is running (then says `walkLine` instead). Callers: the
    /// gated switches (through `setPremiumFeature`), the Settings Premium card.
    func requestPaywall(for feature: PremiumFeature?) {
        guard PremiumGate.mayPresentPaywall(walkActive: isWalkActive) else {
            refuseDuringWalk(feature)
            return
        }
        premiumNotice = nil
        premiumNoticeFeature = nil
        paywallRequest = PaywallRequest(feature: feature)
        logger.event("paywall", ["action": "shown", "feature": feature?.rawValue ?? "settings",
                                 "access": store.access.rawValue])
    }

    /// The paywall unlocked Premium (purchase or restore): turn on the switch that opened it — at
    /// once, or when the walk ends if one started meanwhile. Logs `paywall {action: unlocked, via}`.
    func premiumUnlocked(from request: PaywallRequest?, via: String) {
        logger.event("paywall", ["action": "unlocked", "via": via,
                                 "feature": request?.feature?.rawValue ?? "settings"])
        guard let feature = request?.feature, store.unlocksPremium, canDeliver(feature) else { return }
        if PremiumGate.enablesNow(walkActive: isWalkActive) {
            setGatedValue(feature, true)
        } else {
            pendingPremiumFeature = feature
        }
    }

    /// Called when a walk ends (`RootView`) and after every access change. Never acts during a
    /// walk. Clears the walk notice; applies an unlock that landed mid-walk; after a confirmed
    /// lapse switches gated features off, says so and remembers them; when Premium is back,
    /// switches the remembered ones on again.
    func reconcilePremium() {
        guard !isWalkActive else { return }
        premiumNotice = nil
        premiumNoticeFeature = nil
        if let pending = pendingPremiumFeature {
            pendingPremiumFeature = nil
            if store.unlocksPremium, canDeliver(pending) { setGatedValue(pending, true) }
        }
        if PremiumGate.revokesNow(access: store.access, walkActive: false) {
            var revoked = revokedFeatures
            for feature in PremiumFeature.allCases where gatedValue(feature) {
                setGatedValue(feature, false)
                revoked.insert(feature)
                speech.say(PremiumGate.revokedLine(for: feature), .scene, ttl: 30)
                logger.event("premium_revoked", ["feature": feature.rawValue])
            }
            revokedFeatures = revoked
        } else if PremiumGate.restoresNow(access: store.access, walkActive: false), !revokedFeatures.isEmpty {
            for feature in revokedFeatures where canDeliver(feature) {
                setGatedValue(feature, true)
                logger.event("premium_restored", ["feature": feature.rawValue])
            }
            revokedFeatures = []
        }
    }

    /// The features a lapse switched off (persisted, so a relaunch still restores them).
    private var revokedFeatures: Set<PremiumFeature> {
        get {
            let raw = UserDefaults.standard.stringArray(forKey: Self.revokedFeaturesKey) ?? []
            return Set(raw.compactMap(PremiumFeature.init(rawValue:)))
        }
        set {
            UserDefaults.standard.set(newValue.map(\.rawValue).sorted(), forKey: Self.revokedFeaturesKey)
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
        premiumNoticeFeature = feature
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
