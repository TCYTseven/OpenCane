//
//  RootView.swift
//  CaneKit
//
//  The launch sequence (Step 69): splash → (first launch) onboarding → the main app.
//  On a first launch `ContentView` — and with it `AppModel.start()`, ARKit, the launch line and
//  the launch microphone — waits until onboarding's Get Started / Skip, so the app does not talk
//  over VoiceOver reading the pages or raise permission alerts before the page that explains them.
//
//  Why it exists: `CaneKitApp` used to show `ContentView` directly. The Shipaton build adds a
//  brand splash and first-launch onboarding, and both must stay out of the way of what already
//  works: on a returning launch the main screen and `AppModel.start()` run from the first frame,
//  underneath the splash, so the splash never delays the engines, the launch line or a
//  `--demo-route` walk. The decisions (how long, when skipped, when onboarding shows) are
//  `LaunchFlow` in CaneKitLogic, with tests.
//
//  Owner / caller: `CaneKitApp` (the `WindowGroup` root), with `AppModel` in the environment.
//  Threading: SwiftUI view, main actor.
//  Tests: `LaunchFlowTests` (timing / skip rules). Every XCUITest and e2e run launches under
//  automation, so for them this view is `ContentView` with no splash.
//

import CaneKitLogic
import SwiftUI
import UIKit

/// Splash over the first screen (onboarding on a first launch, else the app), then that screen alone.
struct RootView: View {
    /// The app-wide owner of every engine; `start()` is called when the main screen appears.
    @Environment(AppModel.self) private var model
    /// Set by Get Started / Skip; read once at launch (through `UserDefaults`, in `init`).
    @AppStorage(LaunchFlow.onboardingCompletedKey) private var onboardingCompleted = false
    /// True while onboarding shows. Decided once at launch; cleared by `finishOnboarding()`.
    @State private var onboardingActive: Bool
    /// The onboarding → app handoff fades unless Reduce Motion is on.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// This launch's splash plan, decided once from the system settings at launch.
    @State private var splash: LaunchFlow.Splash
    /// True until the plan's hold (and fade) has run. False from the start when the plan is `.skip`.
    @State private var splashVisible: Bool

    /// Reads Reduce Motion and VoiceOver from UIKit at launch: SwiftUI's environment is not
    /// available in an initializer, and the plan must be known before the first frame so a
    /// skipped splash never flashes.
    init() {
        let plan = LaunchFlow.splash(reduceMotion: UIAccessibility.isReduceMotionEnabled,
                                     voiceOver: UIAccessibility.isVoiceOverRunning,
                                     automation: Self.isAutomationLaunch)
        _splash = State(initialValue: plan)
        _splashVisible = State(initialValue: plan != .skip)
        let completed = UserDefaults.standard.bool(forKey: LaunchFlow.onboardingCompletedKey)
        _onboardingActive = State(initialValue: LaunchFlow.showsOnboarding(
            completed: completed,
            automation: Self.isAutomationLaunch,
            forced: ProcessInfo.processInfo.environment["CANEKIT_SHOW_ONBOARDING"] == "1"))
    }

    /// Onboarding or the main screen (engines start with the main screen), with the splash above
    /// either while `splashVisible`.
    var body: some View {
        ZStack {
            if onboardingActive {
                OnboardingView(location: model.location) { finishOnboarding() }
                    .transition(.opacity)
            } else {
                ContentView()
                    // `start()` is idempotent (guards on `started`), so a re-run is safe.
                    .task { model.start() }
                    .transition(.opacity)
                    // Step 69.5: the Premium paywall. Only `AppModel.requestPaywall(for:)` sets the
                    // request, and it refuses during a walk.
                    .sheet(item: paywallRequest) { request in
                        PaywallView(request: request)
                    }
            }
            if splashVisible {
                SplashView(animates: splash.animates)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task { await dismissSplash() }
        // Step 69.5: RevenueCat is configured at launch (before onboarding ends, so the cached
        // subscription is known early). It starts no engine and makes no sound.
        .task { model.configurePremium() }
        // A walk starting closes an open paywall at once (a Siri "Take me to …" while it is up);
        // a walk ending lets a deferred lapse switch its features off and clears the walk notice.
        .onChange(of: model.isWalkActive) { _, walking in
            if walking {
                model.paywallRequest = nil
            } else {
                model.reconcilePremium()
            }
        }
    }

    /// `AppModel.paywallRequest` as the sheet's binding (the sheet clears it on dismiss).
    private var paywallRequest: Binding<PaywallRequest?> {
        Binding(get: { model.paywallRequest }, set: { model.paywallRequest = $0 })
    }

    /// Get Started or Skip: remember it, then show the app (whose appearance starts the engines).
    private func finishOnboarding() {
        onboardingCompleted = true
        if reduceMotion {
            onboardingActive = false
        } else {
            withAnimation(.easeOut(duration: 0.25)) { onboardingActive = false }
        }
    }

    /// Holds for the plan's time, then fades (or, under Reduce Motion, cuts) the splash away.
    private func dismissSplash() async {
        guard case .show(let hold, let fade) = splash else { return }
        try? await Task.sleep(for: .seconds(hold))
        if fade > 0 {
            withAnimation(.easeOut(duration: fade)) { splashVisible = false }
        } else {
            splashVisible = false
        }
    }

    /// XCUITests (`CANEKIT_UITEST=1`), muted e2e (`CANEKIT_MUTE=1`) and `--demo-route` /
    /// `CANEKIT_DEMO_ROUTE=1` launches: straight to the Guide screen, no splash, no onboarding
    /// (unless `CANEKIT_SHOW_ONBOARDING=1` forces the pages for a UI test of them).
    static var isAutomationLaunch: Bool {
        AppModel.isAutomation
            || CommandLine.arguments.contains("--demo-route")
            || ProcessInfo.processInfo.environment["CANEKIT_DEMO_ROUTE"] == "1"
    }
}
