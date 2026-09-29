//
//  OnboardingView.swift
//  CaneKit
//
//  First-launch onboarding (Step 69.3): four swipeable pages — the product, what LiDAR adds, how
//  guidance feels, and the permissions it needs, requested in context on the last page.
//
//  Why it looks like this: the owner's brief, written for blind and low-vision users first.
//    · Paged `TabView` with page dots, so a sighted user can swipe — and a visible, VoiceOver-
//      reachable **Next** button on every page (the last one says **Get Started**), because a
//      VoiceOver user should never need the three-finger scroll to move on.
//    · **Skip** in the top corner of every page but the last (≥ 44 pt, `CKTextButton`).
//    · When the page changes, VoiceOver focus moves to the new page's title (a heading), so the
//      walker hears where they are. The Next button's value says "Page 2 of 4".
//    · Each page is in a `ScrollView`, so the largest accessibility text sizes scroll instead of
//      clipping. Reduce Motion: Next changes the page without the slide animation.
//    · No paywall here, ever (owner rule). Nothing in onboarding mentions Premium.
//  Copy and rules are `OnboardingContent` (CaneKitLogic, tested).
//
//  Engines: `RootView` shows this *instead of* `ContentView` on a first launch, so `AppModel.start()`
//  (ARKit, the launch line, the launch microphone) runs only after Get Started / Skip. The
//  location prompt that `start()` used to raise at launch is raised here, on its row, instead; the
//  call in `start()` is then a no-op because the walker has already answered.
//
//  Owner / caller: `RootView`. Tests: `OnboardingContentTests` (copy, buttons, permission states).
//  No XCUITest yet drives these pages: `LaunchFlow` keeps them out of every automated run unless
//  `CANEKIT_SHOW_ONBOARDING=1` is set.
//

import AVFoundation
import CaneKitLogic
import Speech
import SwiftUI
import UIKit

/// The four onboarding pages with Skip above and Next / Get Started pinned below.
struct OnboardingView: View {
    /// Called once, on Get Started or Skip. `RootView` stores completion and shows the app.
    let onFinish: () -> Void
    /// Live permission states for the last page.
    @State private var permissions: PermissionCenter
    /// The visible page (`OnboardingPage.id`).
    @State private var page = 0
    /// Which page title VoiceOver should sit on; set when the page changes.
    @AccessibilityFocusState private var focusedTitle: Int?
    /// Reduce Motion: Next changes the page without animating the slide.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Hero well size; scales with Dynamic Type, capped so text keeps most of the screen.
    @ScaledMetric(relativeTo: .largeTitle) private var heroWell: CGFloat = 132

    private let pages = OnboardingContent.pages

    /// - Parameters:
    ///   - location: the app's `LocationService`, so the location row asks through the same
    ///     manager `AppModel.start()` would have used.
    ///   - onFinish: see `onFinish`.
    init(location: LocationService, onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        _permissions = State(initialValue: PermissionCenter(location: location))
    }

    /// Top bar, the paged pages, the pinned primary button.
    var body: some View {
        VStack(spacing: 0) {
            topBar
            TabView(selection: $page) {
                ForEach(pages) { p in
                    pageView(p).tag(p.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            primaryButton
                .padding(.horizontal, CKSpacing.gutter)
                .padding(.top, CKSpacing.md)
                .padding(.bottom, CKSpacing.lg)
        }
        .background(CKColor.background.ignoresSafeArea())
        // A swipe or a Next tap: VoiceOver lands on the new page's title.
        .onChange(of: page) { _, newPage in focusedTitle = newPage }
        // On first appearance VoiceOver would start on Skip; put it on the first title instead.
        // The short wait lets the page exist in the accessibility tree before focus moves.
        .task {
            try? await Task.sleep(for: .milliseconds(400))
            focusedTitle = page
        }
    }

    /// "OpenCane" on the left for orientation, Skip on the right (every page but the last). The
    /// bar keeps its height on the last page so the pages do not jump.
    private var topBar: some View {
        HStack {
            Text("OpenCane")
                .font(CKFont.label)
                .foregroundStyle(CKColor.textSecondary)
                .accessibilityHidden(true)
            Spacer()
            if OnboardingContent.showsSkip(page: page, count: pages.count) {
                CKTextButton(title: "Skip",
                             hint: "Skips the introduction and opens OpenCane. You can allow permissions when a feature needs them.") {
                    onFinish()
                }
            }
        }
        .frame(minHeight: CKMetrics.minimumTarget)
        .padding(.horizontal, CKSpacing.gutter)
        .padding(.top, CKSpacing.sm)
    }

    /// One page: hero symbol, title (a heading, and the focus target), body, and on the last page
    /// the permission rows. Scrolls at large text sizes; bottom padding clears the page dots.
    private func pageView(_ p: OnboardingPage) -> some View {
        ScrollView {
            VStack(spacing: CKSpacing.xl) {
                hero(p.systemImage)
                VStack(spacing: CKSpacing.md) {
                    Text(p.title)
                        .font(CKFont.display)
                        .foregroundStyle(CKColor.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($focusedTitle, equals: p.id)
                    Text(p.body)
                        .font(CKFont.body)
                        .foregroundStyle(CKColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if p.isPermissions {
                    PermissionsPanel(center: permissions)
                }
            }
            .padding(.horizontal, CKSpacing.gutter)
            .padding(.top, CKSpacing.xl)
            .padding(.bottom, CKSpacing.xxl + CKSpacing.xl)
            .frame(maxWidth: .infinity)
        }
    }

    /// The page's symbol in gold on a navy circle (the brand pairing, 9.4:1). Decoration only.
    private func hero(_ systemImage: String) -> some View {
        let well = min(heroWell, 180)
        return Image(systemName: systemImage)
            .font(.system(size: well * 0.42, weight: .semibold))
            .foregroundStyle(CKColor.brandHighlight)
            .frame(width: well, height: well)
            .background(CKColor.brand, in: Circle())
            .accessibilityHidden(true)
    }

    /// Next (earlier pages) or Get Started (last page), pinned under the pages. Its VoiceOver value
    /// is the position ("Page 2 of 4").
    private var primaryButton: some View {
        let isLast = page >= pages.count - 1
        return CKBigButton(title: OnboardingContent.primaryButtonTitle(page: page, count: pages.count),
                           systemImage: isLast ? "checkmark.circle.fill" : "arrow.right",
                           hint: isLast ? "Finishes the introduction and opens OpenCane"
                                        : "Goes to the next page",
                           value: OnboardingContent.spokenPosition(page: page, count: pages.count)) {
            advance()
        }
    }

    /// Next page, or finish on the last one. No slide under Reduce Motion.
    private func advance() {
        guard page < pages.count - 1 else { onFinish(); return }
        if reduceMotion {
            page += 1
        } else {
            withAnimation(.easeInOut(duration: 0.25)) { page += 1 }
        }
    }
}

// MARK: - Permissions

/// The camera / location / microphone rows on the last onboarding page. Each row says why in one
/// line and offers Allow, shows Allowed, or — after a refusal, which only the Settings app can
/// undo — Open Settings. States refresh when the page appears and every time the app becomes
/// active again (a system permission alert makes the app inactive while it is up).
struct PermissionsPanel: View {
    /// Live states and the request calls.
    let center: PermissionCenter
    /// `.active` after a system alert closes → re-read every state.
    @Environment(\.scenePhase) private var scenePhase

    /// One card per permission, in `OnboardingContent.permissions` order.
    var body: some View {
        VStack(spacing: CKSpacing.md) {
            ForEach(OnboardingContent.permissions, id: \.kind) { row in
                rowCard(row)
            }
        }
        .onAppear { center.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { center.refresh() }
        }
    }

    /// The row's feature line (one VoiceOver sentence ending in the state) and its action.
    private func rowCard(_ row: PermissionRow) -> some View {
        let state = center.state(row.kind)
        return CKCard {
            CKFeatureRow(systemImage: row.systemImage, title: row.title, detail: row.reason,
                         spokenSuffix: "\(OnboardingContent.spokenState(state).capitalizedFirst).")
            action(for: row, state: state)
        }
    }

    /// Allow (primary), Open Settings (secondary) or a non-interactive "Allowed" mark.
    @ViewBuilder
    private func action(for row: PermissionRow, state: PermissionState) -> some View {
        switch state {
        case .allowed:
            Label(OnboardingContent.actionTitle(for: state), systemImage: "checkmark.circle.fill")
                .font(CKFont.body.weight(.semibold))
                .foregroundStyle(CKColor.textPrimary)
                .frame(maxWidth: .infinity, minHeight: CKMetrics.minimumTarget)
                // The row's label already ends in "Allowed."
                .accessibilityHidden(true)
        case .notAsked, .denied:
            Button {
                if state == .denied { center.openSettings() } else { center.request(row.kind) }
            } label: {
                Text(OnboardingContent.actionTitle(for: state))
                    .font(CKFont.button)
                    .frame(maxWidth: .infinity, minHeight: CKMetrics.touchTarget)
            }
            .buttonStyle(CKBigButtonStyle(role: state == .denied ? .secondary : .primary))
            .accessibilityLabel(state == .denied
                                ? "Open Settings for \(row.title)"
                                : "Allow \(row.title)")
            .accessibilityHint(state == .denied
                               ? "Opens the Settings app, where you can turn this permission on"
                               : "Shows the system permission alert")
        }
    }
}

/// Reads and requests the three onboarding permissions. Main actor (project default); every
/// system callback is a `@Sendable` closure that hops back with `Task { @MainActor in … }` — the
/// SDK may call them on any thread, and an inferred-`@MainActor` closure called off-main traps
/// (the mechanism behind the 2026-09-12 crash reports; see `VoiceInputEngine`).
@Observable
final class PermissionCenter {
    /// Camera (ARKit / LiDAR obstacle detection).
    private(set) var camera: PermissionState = .notAsked
    /// Location (When In Use is enough to guide).
    private(set) var location: PermissionState = .notAsked
    /// Microphone and speech recognition together: voice commands need both.
    private(set) var microphone: PermissionState = .notAsked
    /// The app's location service; its `requestAuthorization()` is the same call `start()` makes.
    @ObservationIgnored private let locationService: LocationService

    /// - Parameter location: `AppModel.location`.
    init(location: LocationService) {
        self.locationService = location
        refresh()
    }

    /// The state shown on a row.
    func state(_ kind: PermissionKind) -> PermissionState {
        switch kind {
        case .camera: camera
        case .location: location
        case .microphone: microphone
        }
    }

    /// Re-reads every state from the system. Cheap; safe to call often.
    func refresh() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: camera = .allowed
        case .denied, .restricted: camera = .denied
        default: camera = .notAsked
        }
        location = PermissionState(locationAuthorizationName: locationService.authorizationName)
        let mic = AVAudioApplication.shared.recordPermission
        let speech = SFSpeechRecognizer.authorizationStatus()
        if mic == .denied || speech == .denied || speech == .restricted {
            microphone = .denied
        } else if mic == .granted && speech == .authorized {
            microphone = .allowed
        } else {
            microphone = .notAsked
        }
    }

    /// Shows the system alert for `kind`. Location's answer arrives through the scene-phase refresh
    /// (`PermissionsPanel`); camera and microphone refresh in their callbacks too.
    func request(_ kind: PermissionKind) {
        switch kind {
        case .camera:
            AVCaptureDevice.requestAccess(for: .video) { @Sendable [weak self] _ in
                Task { @MainActor [weak self] in self?.refresh() }
            }
        case .location:
            locationService.requestAuthorization()
        case .microphone:
            // Microphone first, then speech recognition (the order `VoiceInputEngine` would ask in
            // reverse; either order ends with both answered). Speech is asked only after a grant.
            AVAudioApplication.requestRecordPermission { @Sendable [weak self] granted in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    guard granted else { self.refresh(); return }
                    SFSpeechRecognizer.requestAuthorization { @Sendable [weak self] _ in
                        Task { @MainActor [weak self] in self?.refresh() }
                    }
                }
            }
        }
    }

    /// Opens OpenCane's page in the Settings app (the only place a refused permission can change).
    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private extension String {
    /// "not allowed yet" → "Not allowed yet" (the state ends the row's spoken sentence).
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

#Preview("Onboarding") {
    OnboardingView(location: LocationService()) {}
}
