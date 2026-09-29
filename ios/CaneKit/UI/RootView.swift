//
//  RootView.swift
//  CaneKit
//
//  The launch sequence (Step 69): splash → (first launch) onboarding → the main app.
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

/// Splash over the first screen, then the first screen alone.
struct RootView: View {
    /// The app-wide owner of every engine; `start()` is called when the main screen appears.
    @Environment(AppModel.self) private var model
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
    }

    /// The main screen (engines start with it) with the splash above it while `splashVisible`.
    var body: some View {
        ZStack {
            ContentView()
                // `start()` is idempotent (guards on `started`), so a re-run of this task is safe.
                .task { model.start() }
            if splashVisible {
                SplashView(animates: splash.animates)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task { await dismissSplash() }
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
    /// `CANEKIT_DEMO_ROUTE=1` launches: straight to the Guide screen, no splash, no onboarding.
    static var isAutomationLaunch: Bool {
        AppModel.isAutomation
            || CommandLine.arguments.contains("--demo-route")
            || ProcessInfo.processInfo.environment["CANEKIT_DEMO_ROUTE"] == "1"
    }
}
