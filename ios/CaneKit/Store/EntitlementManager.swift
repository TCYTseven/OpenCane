//
//  EntitlementManager.swift
//  CaneKit
//
//  OpenCane Premium through RevenueCat (Step 69.5). The single owner of the subscription state:
//  configures `Purchases` at launch, listens to `CustomerInfo` updates, and exposes `access`
//  (checking / free / premium / notConfigured) as observable state, plus the paywall's offering,
//  purchase and restore calls. This is the only file that imports RevenueCat, so the rest of the
//  app sees plain values (`PremiumAccess`, `PaywallProduct`, the outcomes below).
//
//  Why it looks like this:
//    · The key comes from the git-ignored `Secrets.plist` (`REVENUECAT_API_KEY`, the **public**
//      Apple API key from RevenueCat → Project → API keys, which is designed to ship in an app),
//      the same way every other key in this app does (AGENTS.md hard rule 4). No key → `access` is
//      `.notConfigured`, which unlocks everything: a fresh clone, the XCUITests and the e2e runs
//      keep every feature they had before the store existed (`PremiumGate`, tested).
//    · `access` changes arrive through `Purchases.shared.customerInfoStream`, which yields the
//      cached value at once and every update after (purchase, restore, renewal, expiry, a refund).
//      `onAccessChanged` tells `AppModel` so it can switch a lapsed feature off — never mid-walk.
//    · The paywall never talks to RevenueCat directly; it calls `loadOffering()`, `purchase()` and
//      `restore()` and renders the resulting state. Nothing here speaks or touches the audio
//      session, the haptics or the depth pipeline.
//    · `CANEKIT_PREMIUM=free|premium` (launch environment) forces a state without the store, for
//      UI tests and screenshots of the gated / unlocked screens. Without it, automation
//      (`RootView.isAutomationLaunch`) is always `.notConfigured`, key or not (review round 69.7).
//
//  Threading / isolation: main actor (project default). RevenueCat's async APIs are called from
//  the main actor; every value that crosses back (`CustomerInfo`, `Offerings`, `Package`,
//  `PurchaseResultData`) is `Sendable` in purchases-ios 5.
//
//  Owner: `AppModel.store` (one instance). Callers: `AppModel+Premium` (`configurePremium`,
//  gating), `PaywallView`, `PremiumSettingsCard`. Tests: the decisions are `PremiumGateTests`
//  (CaneKitLogic); the store calls need a device or the StoreKit configuration file
//  (`ios/StoreKit/OpenCane.storekit`, selected in the CaneKit scheme's Run action).
//

import CaneKitLogic
import Foundation
// `@Observable` / `@ObservationIgnored`: none of the other imports re-exports Observation
// (review round 69.7, the compile reviewer's one definite error).
import Observation
import RevenueCat

/// The paywall's product, as plain strings in the App Store's own locale formatting.
struct PaywallProduct: Equatable {
    /// "$49.99".
    let localizedPrice: String
    /// "$4.16" — RevenueCat's per-month figure for the annual price, when it has one.
    let localizedPerMonth: String?
    /// Spoken length of a free introductory offer ("month"), or nil when the product charges at once.
    let freeTrialPeriod: String?
}

/// Where the paywall's offering is.
enum OfferingState: Equatable {
    /// Not asked yet.
    case idle
    /// Asking RevenueCat.
    case loading
    /// Ready to buy.
    case loaded(PaywallProduct)
    /// RevenueCat or the App Store failed; the message is shown with a Try again button.
    case failed(String)
    /// This build has no RevenueCat key.
    case unavailable
}

/// How a Subscribe tap ended.
enum PurchaseOutcome: Equatable {
    /// The entitlement is active now.
    case purchased
    /// The walker closed the App Store sheet.
    case cancelled
    /// Paid for but not active yet (Ask to Buy, a deferred payment).
    case pending
    /// The purchase failed; the message is shown.
    case failed(String)
}

/// How a Restore Purchases tap ended.
enum RestoreOutcome: Equatable {
    /// The entitlement is active now.
    case restored
    /// The Apple Account has no active OpenCane Premium.
    case nothingToRestore
    /// Restoring failed; the message is shown.
    case failed(String)
}

/// The subscription state and the store calls. One instance, owned by `AppModel`.
@Observable
final class EntitlementManager {
    /// What the subscription allows right now. `.checking` until RevenueCat's first answer.
    private(set) var access: PremiumAccess = .checking
    /// The paywall's offering.
    private(set) var offering: OfferingState = .idle
    /// True while the App Store purchase sheet is up.
    private(set) var isPurchasing = false
    /// True while a restore is running.
    private(set) var isRestoring = false
    /// When the current Premium period ends (renewal or expiry), for the Settings card.
    private(set) var expirationDate: Date?
    /// Whether that date is a renewal (true) or the end (false: cancelled, still active until then).
    private(set) var willRenew = false

    /// True when the gated features may run (`premium` or a build without a store).
    var unlocksPremium: Bool { access.unlocks }
    /// True when RevenueCat is configured in this process (a key was found).
    var isStoreConfigured: Bool { Purchases.isConfigured }

    /// Called on the main actor after every change of `access`. Installed by
    /// `AppModel.configurePremium()`.
    @ObservationIgnored var onAccessChanged: (() -> Void)?
    /// The package the paywall buys, kept from the last `loadOffering()`.
    @ObservationIgnored private var package: RevenueCat.Package?
    /// The `customerInfoStream` listener; lives as long as the app.
    @ObservationIgnored private var listener: Task<Void, Never>?

    /// Configures RevenueCat once and starts listening, or settles `access` without a store.
    /// Idempotent. Caller: `AppModel.configurePremium()` from `RootView`'s launch task.
    func configure() {
        guard listener == nil, access == .checking else { return }
        // Screenshot tour only. Shows the $49.99 paywall without a RevenueCat key or a purchase.
        // A walker launch never sets this. Subscribe still needs the real store.
        if ProcessInfo.processInfo.environment["CANEKIT_PAYWALL_PREVIEW"] == "1" {
            applyScreenshotOffer()
            return
        }
        switch ProcessInfo.processInfo.environment["CANEKIT_PREMIUM"] {
        case "free": setAccess(.free); return
        case "premium": setAccess(.premium); return
        default: break
        }
        // Review round 69.7: XCUITests, the tour and e2e bundle the same git-ignored Secrets.plist
        // as a real build. With a key in it they would talk to RevenueCat, show badges and change
        // every Settings screenshot. Automation is "no store" unless CANEKIT_PREMIUM says otherwise.
        if RootView.isAutomationLaunch {
            setAccess(.notConfigured)
            return
        }
        guard let key = Secrets.string("REVENUECAT_API_KEY") else {
            setAccess(.notConfigured)
            return
        }
        if !Purchases.isConfigured {
            Purchases.logLevel = .warn
            Purchases.configure(withAPIKey: key)
        }
        listener = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                self?.apply(info)
            }
        }
    }

    /// Re-reads the subscription (the Settings card on appear). A failure keeps the last state.
    func refresh() async {
        guard Purchases.isConfigured else { return }
        if let info = try? await Purchases.shared.customerInfo() { apply(info) }
    }

    /// Loads the `default` offering's annual package for the paywall.
    func loadOffering() async {
        if ProcessInfo.processInfo.environment["CANEKIT_PAYWALL_PREVIEW"] == "1" {
            applyScreenshotOffer()
            return
        }
        guard Purchases.isConfigured else { offering = .unavailable; return }
        offering = .loading
        do {
            let offerings = try await Purchases.shared.offerings()
            let chosen = offerings.offering(identifier: PremiumGate.offeringID) ?? offerings.current
            let packages = chosen?.availablePackages ?? []
            guard let found = packages.first(where: { $0.storeProduct.productIdentifier == PremiumGate.productID })
                    ?? chosen?.annual ?? packages.first else {
                offering = .failed("OpenCane Premium isn't available right now.")
                return
            }
            package = found
            let trial = await Self.freeTrialPeriod(found.storeProduct)
            offering = .loaded(PaywallProduct(localizedPrice: found.storeProduct.localizedPriceString,
                                              localizedPerMonth: found.storeProduct.localizedPricePerMonth,
                                              freeTrialPeriod: trial))
        } catch {
            offering = .failed(error.localizedDescription)
        }
    }

    /// Buys the loaded package. The entitlement is read from the purchase's own `CustomerInfo`,
    /// so a success unlocks at once, before the stream's copy arrives.
    func purchase() async -> PurchaseOutcome {
        guard let package else { return .failed("The price hasn't loaded yet.") }
        guard !isPurchasing else { return .pending }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return .cancelled }
            apply(result.customerInfo)
            return access == .premium ? .purchased : .pending
        } catch {
            return Self.isCancellation(error) ? .cancelled : .failed(error.localizedDescription)
        }
    }

    /// Restores purchases made with this Apple Account.
    func restore() async -> RestoreOutcome {
        guard Purchases.isConfigured else { return .failed("Purchases aren't set up in this build.") }
        guard !isRestoring else { return .failed("A restore is already running.") }
        isRestoring = true
        defer { isRestoring = false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(info)
            return access == .premium ? .restored : .nothingToRestore
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Reads the `premium` entitlement out of a `CustomerInfo`.
    private func apply(_ info: CustomerInfo) {
        let entitlement = info.entitlements[PremiumGate.entitlementID]
        expirationDate = entitlement?.expirationDate
        willRenew = entitlement?.willRenew ?? false
        setAccess(entitlement?.isActive == true ? .premium : .free)
    }

    /// Spoken length of a free introductory offer this Apple Account can still redeem.
    /// The product's intro offer describes the product, not this account. `.unknown` and
    /// `.ineligible` keep the charge-at-subscribe wording so a returning customer is not told
    /// the first month is free.
    private static func freeTrialPeriod(_ product: StoreProduct) async -> String? {
        guard let offer = product.introductoryDiscount, offer.paymentMode == .freeTrial else { return nil }
        let status = await Purchases.shared.checkTrialOrIntroDiscountEligibility(product: product)
        guard status == .eligible else { return nil }
        let count = max(1, offer.subscriptionPeriod.value * offer.numberOfPeriods)
        let unit: String
        switch offer.subscriptionPeriod.unit {
        case .day: unit = count == 1 ? "day" : "days"
        case .week: unit = count == 1 ? "week" : "weeks"
        case .month: unit = count == 1 ? "month" : "months"
        case .year: unit = count == 1 ? "year" : "years"
        }
        return count == 1 ? unit : "\(count) \(unit)"
    }

    /// The paywall a screenshot tour shows. Price matches `OpenCane.storekit` ($49.99/year, first month free).
    private func applyScreenshotOffer() {
        setAccess(.free)
        offering = .loaded(PaywallProduct(localizedPrice: "$49.99", localizedPerMonth: "$4.16", freeTrialPeriod: "month"))
    }

    /// Sets `access` and tells `AppModel` when it actually changed.
    private func setAccess(_ new: PremiumAccess) {
        guard new != access else { return }
        access = new
        onAccessChanged?()
    }

    /// A purchase the walker cancelled comes back as `ErrorCode.purchaseCancelledError` on some
    /// StoreKit paths instead of `userCancelled`.
    private static func isCancellation(_ error: Error) -> Bool {
        if let code = error as? RevenueCat.ErrorCode { return code == .purchaseCancelledError }
        let ns = error as NSError
        return ns.domain == RevenueCat.ErrorCode.errorDomain
            && ns.code == RevenueCat.ErrorCode.purchaseCancelledError.rawValue
    }
}
