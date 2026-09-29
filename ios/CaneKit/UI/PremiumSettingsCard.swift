//
//  PremiumSettingsCard.swift
//  CaneKit
//
//  The first card on Settings (Step 69.5): subscription status, and the three things App Review
//  and a subscriber expect to find — Restore Purchases, Manage Subscription and the way to the
//  paywall. The privacy policy, terms and version live on the About card at the bottom of the page.
//
//  States (all words, never colour alone):
//    · checking — a spinner row, "Checking your subscription…";
//    · free — "You're on the free plan", the two benefits as feature rows, "See OpenCane Premium"
//      (which, like every paywall entry, is refused in words during a walk);
//    · premium — "OpenCane Premium is on", with the renewal or end date;
//    · notConfigured — "Every feature is unlocked in this build" (no RevenueCat key; a developer
//      build), with no store buttons.
//  Restore Purchases and Manage Subscription (the system's own StoreKit sheet,
//  `manageSubscriptionsSheet`) show whenever the store exists.
//
//  Owner / caller: `SettingsPage` (ContentView.swift), first card. Reads `AppModel.store`.
//  Tests: the words are `PremiumGateTests`; no XCUITest queries this card.
//

import CaneKitLogic
import StoreKit
import SwiftUI

/// Settings → OpenCane Premium.
struct PremiumSettingsCard: View {
    /// `store` for the state and restore; `requestPaywall(for:)` for the paywall.
    @Environment(AppModel.self) private var model
    /// Shows the App Store's Manage Subscriptions sheet.
    @State private var managing = false
    /// The last restore's result, shown under the buttons.
    @State private var restoreMessage: String?

    /// Status, then the plan-specific rows, then the store buttons.
    var body: some View {
        CKCard(title: "OpenCane Premium", systemImage: "star.fill") {
            status
            if model.store.access == .free {
                ForEach(PremiumBenefit.allCases, id: \.self) { benefit in
                    CKFeatureRow(systemImage: benefit.systemImage, title: benefit.title,
                                 detail: benefit.detail)
                }
                CKBigButton(title: "See OpenCane Premium", systemImage: "star.fill",
                            hint: "Shows what Premium adds and its price") {
                    model.requestPaywall(for: nil)
                }
                if let notice = model.premiumNotice {
                    Text(notice).font(CKFont.secondary).foregroundStyle(CKColor.textPrimary)
                }
            }
            if model.store.isStoreConfigured {
                CKRowDivider()
                storeButtons
                if let restoreMessage {
                    Text(restoreMessage)
                        .font(CKFont.secondary)
                        .foregroundStyle(CKColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .manageSubscriptionsSheet(isPresented: $managing)
        .task { await model.store.refresh() }
    }

    /// One status line per access state.
    @ViewBuilder
    private var status: some View {
        switch model.store.access {
        case .checking:
            CKStateMessage(kind: .loading, title: "Checking your subscription…")
        case .free:
            statusLine("You're on the free plan",
                       detail: "Navigation and obstacle detection are always free.")
        case .premium:
            statusLine("OpenCane Premium is on", detail: renewalLine)
        case .notConfigured:
            statusLine("Every feature is unlocked in this build",
                       detail: "This copy of OpenCane was built without a store key, so nothing is locked.")
        }
    }

    /// "Renews on 29 September 2027" / "Ends on …" / nothing known.
    private var renewalLine: String {
        guard let date = model.store.expirationDate else { return "Thank you for supporting OpenCane." }
        let day = date.formatted(date: .long, time: .omitted)
        return model.store.willRenew ? "Renews on \(day)." : "Ends on \(day). It will not renew."
    }

    /// Bold line + one sentence, one VoiceOver element.
    private func statusLine(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(CKFont.label).foregroundStyle(CKColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(detail).font(CKFont.secondary).foregroundStyle(CKColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(detail)")
    }

    /// Restore Purchases and Manage Subscription, side by side or stacked at large sizes.
    private var storeButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: CKSpacing.md) { storeButtonRow }
            VStack(alignment: .leading, spacing: 0) { storeButtonRow }
        }
    }

    /// The two store buttons (laid out by `storeButtons`).
    @ViewBuilder
    private var storeButtonRow: some View {
        CKTextButton(title: model.store.isRestoring ? "Restoring…" : "Restore Purchases",
                     systemImage: "arrow.clockwise",
                     hint: "Restores OpenCane Premium bought with this Apple Account") {
            Task { await restore() }
        }
        .disabled(model.store.isRestoring)
        CKTextButton(title: "Manage Subscription", systemImage: "creditcard",
                     hint: "Opens your App Store subscriptions, where you can change or cancel") {
            managing = true
        }
    }

    /// Restore, and say what happened in words (and to VoiceOver).
    private func restore() async {
        let message: String
        switch await model.store.restore() {
        case .restored:
            message = "OpenCane Premium is restored."
            model.premiumUnlocked(from: nil, via: "settings_restore")
        case .nothingToRestore:
            message = "This Apple Account has no OpenCane Premium subscription."
        case .failed(let error):
            message = "Couldn't restore: \(error)"
        }
        restoreMessage = message
        AccessibilityNotification.Announcement(message).post()
    }
}
