//
//  PaywallView.swift
//  CaneKit
//
//  The OpenCane Premium paywall (Step 69.5): a custom SwiftUI sheet on the design system, not
//  RevenueCatUI, so every element's VoiceOver label, the price's spoken sentence and the Dynamic
//  Type behaviour are ours to guarantee.
//
//  Top to bottom: Close (top right, 44 pt), the navy header with the title "OpenCane Premium",
//  the two benefits as feature rows, the price block ("$49.99/year", then the per-month figure)
//  — or its loading / error / unavailable state — the Subscribe button, the renewal terms, the
//  "always free" reminder, the affordability note, then Restore Purchases, Terms of Use and
//  Privacy Policy.
//
//  Why it behaves like this:
//    · It only ever opens through `AppModel.requestPaywall(for:)`, which refuses during a walk,
//      and `RootView` closes it the moment a walk starts. Nothing here speaks through
//      `SpeechQueue`, plays a haptic pattern or touches the audio session; VoiceOver
//      announcements (`AccessibilityNotification.Announcement`) are VoiceOver's own channel.
//    · The price block is ONE VoiceOver element whose label is whole sentences
//      (`PaywallPricing.spokenOffer`: "OpenCane Premium costs $49.99 per year, about $4.16 a
//      month. It renews automatically every year until you cancel."), so "slash year" is never
//      read. The renewal terms are ordinary text right under Subscribe.
//    · Success (purchase or restore) unlocks at once — the purchase's own `CustomerInfo` sets
//      `access` — turns on the switch that opened the paywall, announces it, and closes.
//      Cancel is silent; a failure is an alert with the store's message.
//    · A build with no RevenueCat key says so instead of showing a price.
//
//  Owner / caller: `RootView` presents it as a sheet for `AppModel.paywallRequest`.
//  Tests: the words and rules are `PremiumGateTests` / `PaywallPricingTests` (CaneKitLogic).
//

import CaneKitLogic
import SwiftUI
import UIKit

/// The Premium sheet.
struct PaywallView: View {
    /// The presentation: which switch opened it (turned on after a purchase), if any.
    let request: PaywallRequest
    /// The app model: `store` for the offering and purchases, `premiumUnlocked` on success.
    @Environment(AppModel.self) private var model
    /// Closes the sheet.
    @Environment(\.dismiss) private var dismiss
    /// The alert to show: a failure or a restore result.
    @State private var alert: PaywallAlert?
    /// Set by the first `finish`: a purchase reports success both through its result and through
    /// the `access` change, and the switch must be turned on (and the sheet closed) once.
    @State private var finished = false

    /// Scrolling content on `background`, the Close button over the header.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CKSpacing.xl) {
                header
                VStack(alignment: .leading, spacing: CKSpacing.lg) {
                    ForEach(PremiumBenefit.allCases, id: \.self) { benefit in
                        CKFeatureRow(systemImage: benefit.systemImage, title: benefit.title,
                                     detail: benefit.detail)
                    }
                }
                .padding(.horizontal, CKSpacing.gutter)
                purchaseSection
                    .padding(.horizontal, CKSpacing.gutter)
                reassurance
                    .padding(.horizontal, CKSpacing.gutter)
                footer
                    .padding(.horizontal, CKSpacing.gutter)
                    .padding(.bottom, CKSpacing.xl)
            }
        }
        .background(CKColor.background.ignoresSafeArea())
        .overlay(alignment: .topTrailing) { closeButton }
        .task { await model.store.loadOffering() }
        // Unlocked by any path (this sheet, a restore, a renewal arriving): finish.
        .onChange(of: model.store.access) { _, access in
            if access == .premium { finish(via: "access_changed") }
        }
        .alert(alert?.title ?? "", isPresented: alertShown, presenting: alert) { _ in
            Button("OK", role: .cancel) {}
        } message: { item in
            Text(item.message)
        }
    }

    // MARK: Header

    /// Navy block: gold star, "OpenCane Premium" (a heading), one line of promise.
    private var header: some View {
        VStack(alignment: .leading, spacing: CKSpacing.sm) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(CKColor.brandHighlight)
                .accessibilityHidden(true)
            Text("OpenCane Premium")
                .font(CKFont.display)
                .foregroundStyle(CKColor.onBrand)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("More awareness on every walk, and your family in the loop.")
                .font(CKFont.body)
                .foregroundStyle(CKColor.onBrandSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, CKSpacing.gutter)
        // Room for the Close button above the title.
        .padding(.top, CKSpacing.xxl + CKSpacing.lg)
        .padding(.bottom, CKSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CKColor.brand)
    }

    /// Close (top right), ≥ 44 pt. It floats over the content as it scrolls, so it carries its own
    /// navy disc and ivory ring: visible on the navy header and on the light page alike.
    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .bold))   // fixed: the disc is a fixed 44 pt
                .foregroundStyle(CKColor.onBrand)
                .frame(width: CKMetrics.minimumTarget, height: CKMetrics.minimumTarget)
                .background(CKColor.brand, in: Circle())
                .overlay(Circle().strokeBorder(CKColor.onBrand.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(CKSpacing.md)
        // First in the swipe order: as an overlay it would otherwise come after the footer links.
        .accessibilitySortPriority(1)
        .accessibilityLabel("Close")
        .accessibilityHint("Closes OpenCane Premium without subscribing")
    }

    // MARK: Price and Subscribe

    /// The price block (or its state), Subscribe, and the renewal terms.
    @ViewBuilder
    private var purchaseSection: some View {
        switch model.store.offering {
        case .idle, .loading:
            CKStateMessage(kind: .loading, title: "Loading the price…")
        case .failed(let message):
            CKStateMessage(kind: .error, title: "Couldn't load the price",
                           message: message) {
                Task { await model.store.loadOffering() }
            }
        case .unavailable:
            CKStateMessage(kind: .empty, title: "Purchases aren't set up in this build",
                           message: "Every feature is unlocked while OpenCane is built without a store key.")
        case .loaded(let product):
            loadedOffer(product)
        }
    }

    /// Price, per month, Subscribe, and the terms for a loaded product.
    private func loadedOffer(_ product: PaywallProduct) -> some View {
        VStack(alignment: .leading, spacing: CKSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(PaywallPricing.priceLine(localizedPrice: product.localizedPrice))
                    .font(CKFont.title)
                    .foregroundStyle(CKColor.textPrimary)
                if let perMonth = product.localizedPerMonth {
                    Text(PaywallPricing.perMonthLine(localizedPerMonth: perMonth))
                        .font(CKFont.secondary)
                        .foregroundStyle(CKColor.textSecondary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(PaywallPricing.spokenOffer(localizedPrice: product.localizedPrice,
                                                           localizedPerMonth: product.localizedPerMonth,
                                                           freeTrialPeriod: product.freeTrialPeriod))
            CKBigButton(title: "Subscribe", systemImage: "star.fill",
                        hint: "Opens the App Store to subscribe for \(product.localizedPrice) a year",
                        value: model.store.isPurchasing ? "Purchasing" : nil) {
                Task { await subscribe() }
            }
            .disabled(model.store.isPurchasing || model.store.isRestoring)
            Text(PaywallPricing.renewalTerms(localizedPrice: product.localizedPrice,
                                             freeTrialPeriod: product.freeTrialPeriod))
                .font(CKFont.secondary)
                .foregroundStyle(CKColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Reassurance and footer

    /// "Always free" and the affordability note.
    private var reassurance: some View {
        VStack(alignment: .leading, spacing: CKSpacing.lg) {
            CKFeatureRow(systemImage: "checkmark.shield.fill",
                         title: "Navigation and obstacle detection are always free",
                         detail: "Obstacle warnings, haptics, spatial audio and route guidance never need a subscription.")
            CKCard {
                Text(PaywallPricing.affordabilityNote)
                    .font(CKFont.secondary)
                    .foregroundStyle(CKColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Restore Purchases, Terms of Use, Privacy Policy — each ≥ 44 pt, wrapping at large sizes.
    private var footer: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: CKSpacing.sm) { footerButtons }
            VStack(alignment: .leading, spacing: 0) { footerButtons }
        }
        .frame(maxWidth: .infinity)
    }

    /// The three footer controls (laid out by `footer`).
    @ViewBuilder
    private var footerButtons: some View {
        CKTextButton(title: model.store.isRestoring ? "Restoring…" : "Restore Purchases",
                     hint: "Restores OpenCane Premium bought with this Apple Account") {
            Task { await restore() }
        }
        .disabled(model.store.isRestoring || model.store.isPurchasing)
        CKTextButton(title: "Terms of Use", hint: "Opens in Safari", isLink: true) {
            open(AppInfo.termsOfUseURL)
        }
        CKTextButton(title: "Privacy Policy", hint: "Opens in Safari", isLink: true) {
            open(AppInfo.privacyPolicyURL)
        }
    }

    // MARK: Actions

    /// Subscribe: success finishes; cancel is silent; pending and failure explain themselves.
    private func subscribe() async {
        switch await model.store.purchase() {
        case .purchased:
            finish(via: "purchase")
        case .cancelled:
            break
        case .pending:
            alert = PaywallAlert(title: "Waiting for approval",
                                 message: "Your purchase needs approval. Premium turns on as soon as it goes through.")
        case .failed(let message):
            alert = PaywallAlert(title: "Couldn't subscribe", message: message)
        }
    }

    /// Restore Purchases.
    private func restore() async {
        switch await model.store.restore() {
        case .restored:
            finish(via: "restore")
        case .nothingToRestore:
            alert = PaywallAlert(title: "Nothing to restore",
                                 message: "This Apple Account has no OpenCane Premium subscription.")
        case .failed(let message):
            alert = PaywallAlert(title: "Couldn't restore", message: message)
        }
    }

    /// Drives the alert from `alert`.
    private var alertShown: Binding<Bool> {
        Binding(get: { alert != nil }, set: { if !$0 { alert = nil } })
    }

    /// Unlocked: turn on the switch that opened the sheet, tell VoiceOver, close. Runs once.
    private func finish(via: String) {
        guard !finished else { return }
        finished = true
        model.premiumUnlocked(from: request, via: via)
        dismiss()
        // After the sheet has gone: the dismissal's screen change would cut an announcement made
        // before it (review round 69.7). An unstructured task outlives this view.
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            AccessibilityNotification.Announcement("OpenCane Premium is on.").post()
        }
    }

    /// Opens a web page in Safari.
    private func open(_ url: String) {
        guard let destination = URL(string: url) else { return }
        UIApplication.shared.open(destination)
    }
}

/// One alert on the paywall.
struct PaywallAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
