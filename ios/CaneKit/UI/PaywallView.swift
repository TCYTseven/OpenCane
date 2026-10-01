//
//  PaywallView.swift
//  CaneKit
//
//  The OpenCane Premium paywall (Step 69.5): a custom SwiftUI sheet on the design system, not
//  RevenueCatUI, so every element's VoiceOver label, the price's spoken sentence and the Dynamic
//  Type behaviour are ours to guarantee.
//
//  Top to bottom (conversion pass, Shipaton): Close (top right, 44 pt); a centred navy hero with
//  the app logo in a slow gold glow (still under Reduce Motion), "See what your cane can't." and
//  two gold laurels (1st of 250 at 54FoundersHack; beta-tested by blind walkers — facts, never
//  ratings); a Free vs Premium table with an icon per row (warnings, routes and emergency calls
//  free on both plans); a
//  trial timeline (Today → in 1 month), only when this account can redeem the intro; "Ways to
//  pay less" (the affordability note) and the full renewal terms; Restore Purchases, then Terms
//  and Privacy. Pinned to the bottom (`safeAreaInset`): the offer line ("1 month free, then
//  $49.99/year (about $4.16/mo)"), the gold "Start my free month" button ("Subscribe for $49.99 a
//  year" when not eligible; identifier "Subscribe") and "Cancel anytime. Renews yearly." — or the
//  loading / error / unavailable state.
//
//  Why it behaves like this:
//    · It only ever opens through `AppModel.requestPaywall(for:)`, which refuses during a walk,
//      and `RootView` closes it the moment a walk starts. Nothing here speaks through
//      `SpeechQueue`, plays a haptic pattern or touches the audio session; VoiceOver
//      announcements (`AccessibilityNotification.Announcement`) are VoiceOver's own channel.
//    · The price block is ONE VoiceOver element whose label is whole sentences
//      (`PaywallPricing.spokenOffer`: "OpenCane Premium costs $49.99 per year, about $4.16 a
//      month. It renews automatically every year until you cancel."), so "slash year" is never
//      read. When this account can still redeem the intro, that label and the terms both say
//      the first month is free. The renewal terms are ordinary text right under Subscribe.
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
    /// Reduce Motion stops the star's glow from breathing.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The alert to show: a failure or a restore result.
    @State private var alert: PaywallAlert?
    /// Set by the first `finish`: a purchase reports success both through its result and through
    /// the `access` change, and the switch must be turned on (and the sheet closed) once.
    @State private var finished = false
    /// Drives the star's slow glow (off under Reduce Motion).
    @State private var glow = false

    /// Hero, proof, Free-vs-Premium table, trial timeline and the fine print scroll; the call to
    /// action is pinned to the bottom so it is always one tap away.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CKSpacing.xl) {
                hero
                comparison
                    .padding(.horizontal, CKSpacing.gutter)
                if case .loaded(let product) = model.store.offering, let trial = product.freeTrialPeriod {
                    timeline(trial: trial, price: product.localizedPrice)
                        .padding(.horizontal, CKSpacing.gutter)
                }
                finePrint
                    .padding(.horizontal, CKSpacing.gutter)
                footer
                    .padding(.horizontal, CKSpacing.gutter)
                    .padding(.bottom, CKSpacing.lg)
            }
        }
        .background(CKColor.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { stickyBar }
        .overlay(alignment: .topTrailing) { closeButton }
        .task { await model.store.loadOffering() }
        .onAppear { if !reduceMotion { glow = true } }
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

    // MARK: Hero

    /// Centred on the navy: the app's own logo in a slow gold glow, a short promise, and the two
    /// facts as award laurels.
    private var hero: some View {
        VStack(spacing: CKSpacing.lg) {
            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(CKColor.brandHighlight.opacity(glow ? 0.45 : 0.18))
                    .frame(width: 112, height: 112)
                    .blur(radius: glow ? 26 : 14)
                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 104, height: 104)
                    .shadow(color: .black.opacity(0.35), radius: 10, y: 6)
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 2.2).repeatForever(autoreverses: true),
                       value: glow)
            .accessibilityHidden(true)
            VStack(spacing: CKSpacing.sm) {
                Text("OPENCANE PREMIUM")
                    .font(CKFont.pill)
                    .tracking(2)
                    .foregroundStyle(CKColor.brandHighlight)
                Text("See what your cane can't.")
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                    .foregroundStyle(CKColor.onBrand)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("A second set of AI eyes on your route.")
                    .font(CKFont.body)
                    .foregroundStyle(CKColor.onBrandSecondary)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: CKSpacing.lg) { laurels }
                VStack(spacing: CKSpacing.md) { laurels }
            }
        }
        .padding(.horizontal, CKSpacing.gutter)
        // Room for the Close button above the logo.
        .padding(.top, CKSpacing.xxl + CKSpacing.sm)
        .padding(.bottom, CKSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [CKColor.brand, Color(red: 0.12, green: 0.15, blue: 0.36)],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    /// The two proof laurels: facts only (README; the team's UIUC beta), never ratings.
    @ViewBuilder
    private var laurels: some View {
        laurel(top: "1st of 250", bottom: "54FoundersHack")
        laurel(top: "Beta-tested", bottom: "by blind walkers")
    }

    /// Gold laurel branches around two short lines, read as one sentence.
    private func laurel(top: String, bottom: String) -> some View {
        HStack(spacing: CKSpacing.xs) {
            Image(systemName: "laurel.leading").font(.system(size: 30)).accessibilityHidden(true)
            VStack(spacing: 0) {
                Text(top).font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(CKColor.onBrand)
                Text(bottom).font(.caption.weight(.semibold))
                    .foregroundStyle(CKColor.onBrandSecondary)
            }
            .fixedSize()
            Image(systemName: "laurel.trailing").font(.system(size: 30)).accessibilityHidden(true)
        }
        .foregroundStyle(CKColor.brandHighlight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(top) \(bottom)")
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

    // MARK: Free vs Premium

    /// One row of the table: what it is, and whether the free plan has it.
    private struct PlanRow: Identifiable {
        let id: String
        let symbol: String
        let free: Bool
    }

    /// Safety rows first (free on both plans), then the three Premium-only features.
    private let planRows: [PlanRow] = [
        PlanRow(id: "Obstacle alerts", symbol: "sensor.tag.radiowaves.forward.fill", free: true),
        PlanRow(id: "Walking routes", symbol: "figure.walk", free: true),
        PlanRow(id: "Emergency call", symbol: "phone.fill", free: true),
        PlanRow(id: "AI hazard watch", symbol: "sparkles", free: false),
        PlanRow(id: "Name people ahead", symbol: "person.2.fill", free: false),
        PlanRow(id: "Family alerts", symbol: "bell.badge.fill", free: false),
    ]

    /// The Free vs Premium check table on a card. Each row is one VoiceOver element that says the
    /// answer in words ("Obstacle warnings: free and Premium").
    private var comparison: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Compare plans")
                    .font(CKFont.label)
                    .foregroundStyle(CKColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                Text("Free").frame(width: 52)
                Text("Premium").frame(width: 78)
            }
            .font(CKFont.secondary.weight(.semibold))
            .foregroundStyle(CKColor.textSecondary)
            .padding(.bottom, CKSpacing.sm)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Compare plans, free and Premium")
            .accessibilityAddTraits(.isHeader)
            ForEach(planRows) { row in
                Divider().overlay(CKColor.border)
                HStack(spacing: CKSpacing.md) {
                    Image(systemName: row.symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(row.free ? CKColor.textPrimary : CKColor.onHighlight)
                        .frame(width: 32, height: 32)
                        .background(row.free ? CKColor.surfaceRaised : CKColor.highlight,
                                    in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .accessibilityHidden(true)
                    Text(row.id)
                        .font(CKFont.body.weight(row.free ? .regular : .semibold))
                        .foregroundStyle(CKColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    mark(row.free).frame(width: 52)
                    mark(true, premium: true).frame(width: 78)
                }
                .padding(.vertical, CKSpacing.md)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(row.id): \(row.free ? "free and Premium" : "Premium only")")
            }
            Label("Warnings, routes and emergency calls stay free", systemImage: "checkmark.shield.fill")
                .font(CKFont.secondary.weight(.semibold))
                .foregroundStyle(CKColor.textSecondary)
                .padding(.top, CKSpacing.md)
        }
        .padding(CKSpacing.lg)
        .background(CKColor.surface, in: RoundedRectangle(cornerRadius: CKRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CKRadius.card, style: .continuous)
            .strokeBorder(CKColor.border, lineWidth: 1))
    }

    /// A check (included) or a dash (not included); the Premium column's checks are gold.
    private func mark(_ included: Bool, premium: Bool = false) -> some View {
        Image(systemName: included ? "checkmark.circle.fill" : "minus")
            .font(.system(.title3).weight(.semibold))
            .foregroundStyle(included ? (premium ? CKColor.highlight : CKColor.textPrimary)
                                      : CKColor.textSecondary)
            .accessibilityHidden(true)
    }

    // MARK: Trial timeline

    /// Today → end of the free period, only when this account can redeem the intro. It promises
    /// nothing the app does not do (there is no reminder notification).
    private func timeline(trial: String, price: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Your free \(trial)")
                .font(CKFont.label)
                .foregroundStyle(CKColor.textPrimary)
                .padding(.bottom, CKSpacing.md)
                .accessibilityAddTraits(.isHeader)
            timelineStep(symbol: "lock.open.fill", title: "Today",
                         detail: "Every Premium feature unlocks. $0 today.",
                         last: false)
            timelineStep(symbol: "creditcard.fill", title: "In 1 \(trial)",
                         detail: "\(price) for the year. Cancel before, pay nothing.",
                         last: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CKSpacing.lg)
        .background(CKColor.surface, in: RoundedRectangle(cornerRadius: CKRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CKRadius.card, style: .continuous)
            .strokeBorder(CKColor.border, lineWidth: 1))
    }

    /// One dot on the timeline, with the line down to the next one.
    private func timelineStep(symbol: String, title: String, detail: String, last: Bool) -> some View {
        HStack(alignment: .top, spacing: CKSpacing.md) {
            VStack(spacing: 0) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(CKColor.onHighlight)
                    .frame(width: 34, height: 34)
                    .background(CKColor.highlight, in: Circle())
                if !last {
                    Rectangle().fill(CKColor.highlight.opacity(0.4)).frame(width: 3).frame(minHeight: 28)
                }
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(CKFont.label).foregroundStyle(CKColor.textPrimary)
                Text(detail)
                    .font(CKFont.secondary)
                    .foregroundStyle(CKColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, last ? 0 : CKSpacing.md)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Sticky call to action

    /// Pinned to the bottom: the price state, the big gold button and one line of terms.
    private var stickyBar: some View {
        VStack(spacing: CKSpacing.sm) {
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
        .padding(.horizontal, CKSpacing.gutter)
        .padding(.top, CKSpacing.md)
        .padding(.bottom, CKSpacing.sm)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider().overlay(CKColor.border) }
    }

    /// The price as one spoken sentence, the call to action, and one reassurance line. The full
    /// renewal terms sit in the scroll body, right under the plans (`terms`).
    private func loadedOffer(_ product: PaywallProduct) -> some View {
        VStack(spacing: CKSpacing.sm) {
            // VoiceOver reads the whole offer as sentences, never "slash year".
            VStack(spacing: 0) {
                Text(offerLine(product))
                    .font(CKFont.label)
                    .foregroundStyle(CKColor.textPrimary)
                // Apple: a price breakdown is smaller than, and below, the billed price.
                if let perMonth = product.localizedPerMonth {
                    Text("About \(perMonth) a month, billed yearly")
                        .font(.footnote)
                        .foregroundStyle(CKColor.textSecondary)
                }
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(PaywallPricing.spokenOffer(localizedPrice: product.localizedPrice,
                                                               localizedPerMonth: product.localizedPerMonth,
                                                               freeTrialPeriod: product.freeTrialPeriod))
            ctaButton(product)
            Label("Cancel anytime. Renews yearly.", systemImage: "checkmark.circle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(CKColor.textSecondary)
        }
    }

    /// "1 month free, then $49.99/year" — or "$49.99/year" without a trial.
    private func offerLine(_ product: PaywallProduct) -> String {
        let price = PaywallPricing.priceLine(localizedPrice: product.localizedPrice)
        guard let trial = product.freeTrialPeriod else { return price }
        return "1 \(trial) free, then \(price)"
    }

    /// The gold slab: "Start my free month" when this account can redeem the intro, otherwise
    /// "Subscribe for $49.99 a year". ⚠ test contract: identifier "Subscribe" (XCUITests).
    private func ctaButton(_ product: PaywallProduct) -> some View {
        let title = product.freeTrialPeriod.map { "Start my free \($0)" }
            ?? "Subscribe for \(product.localizedPrice) a year"
        return Button {
            Task { await subscribe() }
        } label: {
            HStack(spacing: CKSpacing.sm) {
                if model.store.isPurchasing {
                    ProgressView().tint(CKColor.brand)
                }
                Text(title)
                    .font(CKFont.button.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                Image(systemName: "arrow.right")
                    .font(.system(.body).weight(.bold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(CKColor.brand)
            .frame(maxWidth: .infinity, minHeight: CKMetrics.touchTarget)
            .padding(.horizontal, CKSpacing.lg)
            .background(
                LinearGradient(colors: [Color(red: 0.96, green: 0.80, blue: 0.45), CKColor.brandHighlight],
                               startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: CKRadius.button, style: .continuous))
            .shadow(color: CKColor.brandHighlight.opacity(0.45), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(model.store.isPurchasing || model.store.isRestoring)
        .opacity(model.store.isPurchasing || model.store.isRestoring ? 0.6 : 1)
        .accessibilityIdentifier("Subscribe")
        .accessibilityLabel(title)
        .accessibilityValue(model.store.isPurchasing ? "Purchasing" : "")
        .accessibilityHint(product.freeTrialPeriod.map {
            "Starts with a free \($0), then \(product.localizedPrice) a year"
        } ?? "Opens the App Store to subscribe for \(product.localizedPrice) a year")
    }

    // MARK: Fine print and footer

    /// The affordability note as an icon row, then the full renewal terms (Guideline 3.1.2).
    private var finePrint: some View {
        VStack(alignment: .leading, spacing: CKSpacing.lg) {
            CKFeatureRow(systemImage: "cross.case.fill", title: "Ways to pay less",
                         detail: PaywallPricing.affordabilityNote)
            if case .loaded(let product) = model.store.offering {
                Text(PaywallPricing.renewalTerms(localizedPrice: product.localizedPrice,
                                                 freeTrialPeriod: product.freeTrialPeriod))
                    .font(.footnote)
                    .foregroundStyle(CKColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Restore Purchases, then Terms of Use and Privacy Policy side by side (stacked at large
    /// text sizes) — the same icon + word buttons as Settings, each ≥ 44 pt.
    private var footer: some View {
        VStack(spacing: 0) {
            CKTextButton(title: model.store.isRestoring ? "Restoring…" : "Restore Purchases",
                         systemImage: "arrow.clockwise",
                         hint: "Restores OpenCane Premium bought with this Apple Account") {
                Task { await restore() }
            }
            .disabled(model.store.isRestoring || model.store.isPurchasing)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: CKSpacing.lg) { legalLinks }
                VStack(spacing: 0) { legalLinks }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Terms of Use and Privacy Policy (laid out by `footer`).
    @ViewBuilder
    private var legalLinks: some View {
        CKTextButton(title: "Terms of Use", systemImage: "doc.text", hint: "Opens in Safari", isLink: true) {
            open(AppInfo.termsOfUseURL)
        }
        CKTextButton(title: "Privacy Policy", systemImage: "hand.raised", hint: "Opens in Safari", isLink: true) {
            open(AppInfo.privacyPolicyURL)
        }
    }

    // MARK: Actions

    /// Subscribe: success finishes; cancel is silent; pending and failure explain themselves.
    private func subscribe() async {
        switch await model.store.purchase() {
        case .purchased:
            finish(via: "purchase")
        case .cancelled, .alreadyPurchasing:
            break
        case .pending:
            model.premiumAwaitingApproval(from: request)
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
