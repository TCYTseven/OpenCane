//
//  PremiumGateTests.swift
//  CaneKitLogicTests
//
//  Purpose: pins Premium.swift — what OpenCane Premium unlocks, when the paywall may appear, what
//  a refused request says, and the paywall's price words (Step 69.5).
//
//  Why these are the tests: the owner's rules for the RevenueCat build.
//    · "Only these two features are gated … everything else stays free, including all core safety
//      features" → `onlyTheTwoBenefitsAreGated`, `safetyOptionsAreNeverPremium`.
//    · "The paywall must never appear during an active walk or interrupt obstacle alerts, haptics,
//      or audio guidance" → `neverAPaywallDuringAWalk`, `aLapseMidWalkWaitsForTheWalkToEnd`.
//    · "When a free user taps a gated feature, show the paywall" → `aFreeTapOnScreenOpensThePaywall`;
//      a voice / Siri request cannot show a sheet, so it is told in words
//      (`voiceRequestsAreToldNotShown`, `aVoiceRequestWhileCheckingIsAskedToWait`).
//    · A build with no RevenueCat key (a fresh clone, the XCUITests, e2e) keeps every feature, so
//      nothing that worked before the store existed stops working → `unconfiguredStoreUnlocks`.
//    · "Price … displayed as $49.99/year, with a per-month equivalent underneath" and "the price and
//      renewal terms must be read aloud clearly" → the `PaywallPricing` tests.
//
//  Source pinned: `ios/Logic/Sources/CaneKitLogic/Premium.swift`. Callers: `EntitlementManager`,
//  `AppModel+Premium`, `PaywallView`, `PremiumSettingsCard`, `HazardsCard`, the Family alerts card.
//

import Foundation
import Testing
@testable import CaneKitLogic

@Suite("Premium gate")
struct PremiumGateTests {

    /// Review round 69.7: the paid promise must match what the switches deliver — the alert
    /// service decides whether to contact family, and people counting is experimental.
    @Test func benefitCopyDoesNotOverpromise() {
        #expect(PremiumBenefit.familyAlerts.detail.contains("can email or text your family"))
        #expect(PremiumBenefit.advancedDetection.detail.contains("experimental"))
    }

    /// The RevenueCat identifiers the dashboard and the StoreKit file must match.
    @Test func identifiersArePinned() {
        #expect(PremiumGate.entitlementID == "premium")
        #expect(PremiumGate.productID == "opencane_premium_annual")
        #expect(PremiumGate.offeringID == "default")
    }

    @Test func onlyTheTwoBenefitsAreGated() {
        #expect(PremiumBenefit.allCases == [.advancedDetection, .familyAlerts])
        #expect(Set(PremiumFeature.allCases) == [.hazardWatch, .namePeople, .familyAlerts])
        #expect(PremiumFeature.hazardWatch.benefit == .advancedDetection)
        #expect(PremiumFeature.namePeople.benefit == .advancedDetection)
        #expect(PremiumFeature.familyAlerts.benefit == .familyAlerts)
    }

    /// The hands-free options that are warnings or guidance must never map to a premium feature.
    @Test func safetyOptionsAreNeverPremium() {
        for option in ["dropOffs", "signs", "obstacleNames", "beacon", "sirens", "nodToTalk"] {
            #expect(PremiumFeature(handsFreeOption: option) == nil, "\(option) must stay free")
        }
        #expect(PremiumFeature(handsFreeOption: "hazardWatch") == .hazardWatch)
        #expect(PremiumFeature(handsFreeOption: "namePeople") == .namePeople)
    }

    @Test func unconfiguredStoreUnlocks() {
        #expect(PremiumAccess.notConfigured.unlocks)
        #expect(PremiumAccess.premium.unlocks)
        #expect(!PremiumAccess.free.unlocks)
        #expect(!PremiumAccess.checking.unlocks)
        for walk in [false, true] {
            for screen in [false, true] {
                #expect(PremiumGate.decideEnable(access: .notConfigured, walkActive: walk, fromScreen: screen) == .allow)
                #expect(PremiumGate.decideEnable(access: .premium, walkActive: walk, fromScreen: screen) == .allow)
            }
        }
    }

    @Test func aFreeTapOnScreenOpensThePaywall() {
        #expect(PremiumGate.decideEnable(access: .free, walkActive: false, fromScreen: true) == .showPaywall)
        // Still checking the subscription (the first second after launch): the paywall itself
        // resolves it, and closes at once if the walker is already subscribed.
        #expect(PremiumGate.decideEnable(access: .checking, walkActive: false, fromScreen: true) == .showPaywall)
    }

    @Test func neverAPaywallDuringAWalk() {
        for access in [PremiumAccess.free, .checking] {
            for screen in [false, true] {
                #expect(PremiumGate.decideEnable(access: access, walkActive: true, fromScreen: screen) == .refuseDuringWalk)
            }
        }
        #expect(!PremiumGate.mayPresentPaywall(walkActive: true))
        #expect(PremiumGate.mayPresentPaywall(walkActive: false))
    }

    @Test func voiceRequestsAreToldNotShown() {
        #expect(PremiumGate.decideEnable(access: .free, walkActive: false, fromScreen: false) == .refuseSpoken)
        let line = PremiumGate.premiumLine(for: .hazardWatch)
        #expect(line == "Hazard watch is part of OpenCane Premium. You can subscribe in OpenCane Settings.")
        #expect(PremiumGate.walkLine == "Premium features can be turned on after this walk.")
    }

    /// Review round 69.7: in the first moments after launch a paying walker must not be told they
    /// are on the free plan. A voice request while `.checking` says so instead.
    @Test func aVoiceRequestWhileCheckingIsAskedToWait() {
        #expect(PremiumGate.decideEnable(access: .checking, walkActive: false, fromScreen: false) == .refuseChecking)
        #expect(PremiumGate.checkingLine == "Still checking your subscription. Try again in a moment.")
    }

    /// Review round 69.7: an unlock that lands mid-walk (the StoreKit sheet outlived the paywall)
    /// waits for the walk to end; a lapse is said out loud and undone when Premium comes back.
    @Test func unlocksAndRestoresWaitForTheWalkToEnd() {
        #expect(PremiumGate.enablesNow(walkActive: false))
        #expect(!PremiumGate.enablesNow(walkActive: true))
        #expect(PremiumGate.restoresNow(access: .premium, walkActive: false))
        #expect(!PremiumGate.restoresNow(access: .premium, walkActive: true))
        #expect(!PremiumGate.restoresNow(access: .free, walkActive: false))
        #expect(PremiumGate.revokedLine(for: .familyAlerts) == "Family alerts turned off. OpenCane Premium has ended.")
    }

    /// Turning a feature OFF is never gated.
    @Test func turningOffIsAlwaysAllowed() {
        for access in [PremiumAccess.free, .checking, .premium, .notConfigured] {
            #expect(PremiumGate.decideDisable(access: access) == .allow)
        }
    }

    @Test func aLapseMidWalkWaitsForTheWalkToEnd() {
        #expect(PremiumGate.revokesNow(access: .free, walkActive: false))
        #expect(!PremiumGate.revokesNow(access: .free, walkActive: true))
        // Unknown is not a lapse: the cached answer has not arrived yet.
        #expect(!PremiumGate.revokesNow(access: .checking, walkActive: false))
        #expect(!PremiumGate.revokesNow(access: .premium, walkActive: false))
        #expect(!PremiumGate.revokesNow(access: .notConfigured, walkActive: false))
    }
}

@Suite("Paywall pricing")
struct PaywallPricingTests {

    /// Review round 69.7: the visible and spoken per-month words match ("about"), and the figure is
    /// the store's own (`localizedPricePerMonth`), so no second rounding rule lives here.
    @Test func priceLineMatchesTheBrief() {
        #expect(PaywallPricing.priceLine(localizedPrice: "$49.99") == "$49.99/year")
        #expect(PaywallPricing.perMonthLine(localizedPerMonth: "$4.16") == "About $4.16 a month, billed yearly")
    }

    /// VoiceOver reads the whole offer and the renewal terms as sentences, with no slash.
    @Test func spokenOfferIsSentences() {
        let spoken = PaywallPricing.spokenOffer(localizedPrice: "$49.99", localizedPerMonth: "$4.16")
        #expect(spoken == "OpenCane Premium costs $49.99 per year, about $4.16 a month. It renews automatically every year until you cancel.")
        #expect(!spoken.contains("/"))
        let noMonth = PaywallPricing.spokenOffer(localizedPrice: "$49.99", localizedPerMonth: nil)
        #expect(noMonth == "OpenCane Premium costs $49.99 per year. It renews automatically every year until you cancel.")
    }

    /// App Store Review Guideline 3.1.2: length, price and auto-renewal next to the Subscribe button.
    @Test func renewalTermsSayLengthPriceAndHowToCancel() {
        let terms = PaywallPricing.renewalTerms(localizedPrice: "$49.99")
        #expect(terms.contains("$49.99"))
        #expect(terms.contains("every year"))
        #expect(terms.contains("24 hours"))
        #expect(terms.contains("subscription year"))
        #expect(terms.contains("Apple Account"))
    }

    @Test func affordabilityNoteIsTheOwnersWords() {
        #expect(PaywallPricing.affordabilityNote == "OpenCane is a social good project and we want it to be affordable for everyone. Premium may be eligible for reimbursement through your insurance, HSA/FSA, or vision rehabilitation program. Check with your plan.")
    }
}
