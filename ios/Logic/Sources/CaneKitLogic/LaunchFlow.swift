//
//  LaunchFlow.swift
//  CaneKitLogic
//
//  What happens between the launch screen and the first usable screen (Step 69): how long the
//  SwiftUI splash may hold, when it is skipped, and when first-launch onboarding shows.
//
//  Why this file exists: the owner's accessibility rules for the Shipaton build are numbers —
//  "the splash screen must not block VoiceOver or delay launch more than about 1 second", "skip the
//  animation if Reduce Motion is on" — and numbers live here with tests (AGENTS.md hard rule 3).
//  Onboarding is the other half of the same decision: first launch only, and never in front of the
//  XCUITests or the GPS-replay e2e runs, which expect the Guide screen the moment the app opens.
//
//  What the splash is for: a brand handoff from the static launch screen (navy + logo, configured
//  in `ios/project.yml` → `UILaunchScreen`) to the app. It carries no information, so VoiceOver
//  users skip it entirely (a view swap while VoiceOver reads moves its focus), and automation skips
//  it too. Engines are NOT held back by it: on a returning launch the main screen and `AppModel.start()`
//  run underneath the splash from the first frame.
//
//  Owner / caller: `RootView` (app) reads `splash(reduceMotion:voiceOver:automation:)` once at launch
//  and `showsOnboarding(completed:automation:forced:)` once at launch; `OnboardingView` sets the
//  `onboardingCompletedKey` flag through `@AppStorage`.
//  Tests: LaunchFlowTests.swift.
//

import Foundation

/// The launch-to-first-screen rules. Pure decisions; no clock, no storage.
public enum LaunchFlow {

    /// How long the splash holds before it fades, seconds (normal motion).
    public static let splashHoldSeconds: Double = 0.6
    /// Length of the splash's fade-out, seconds (normal motion).
    public static let splashFadeSeconds: Double = 0.25
    /// Reduce Motion: a still hold of this length, then a cut (no fade, no scale).
    public static let reduceMotionHoldSeconds: Double = 0.4
    /// The owner's ceiling: the splash never adds more than this to launch, seconds.
    public static let maxSplashSeconds: Double = 1.0
    /// `UserDefaults` / `@AppStorage` key set once onboarding finishes (Get Started or Skip).
    /// ⚠ Renaming it shows onboarding again to every walker who already finished it.
    public static let onboardingCompletedKey = "onboardingCompleted"

    /// What the splash does this launch.
    public enum Splash: Equatable, Sendable {
        /// No splash: straight to the first screen.
        case skip
        /// Hold still for `holdSeconds`, then fade out over `fadeSeconds` (0 = a cut).
        case show(holdSeconds: Double, fadeSeconds: Double)

        /// Hold plus fade: how long the splash covers the screen. 0 for `.skip`.
        public var totalSeconds: Double {
            switch self {
            case .skip: 0
            case .show(let hold, let fade): hold + fade
            }
        }

        /// True when the splash animates (fades). False for `.skip` and for a Reduce Motion cut.
        public var animates: Bool {
            if case .show(_, let fade) = self { return fade > 0 }
            return false
        }
    }

    /// The splash plan for this launch.
    /// - Parameters:
    ///   - reduceMotion: Settings → Accessibility → Motion → Reduce Motion.
    ///   - voiceOver: VoiceOver is running at launch.
    ///   - automation: an XCUITest, a muted e2e run or a `--demo-route` launch.
    /// - Returns: `.skip` under VoiceOver or automation; a still `reduceMotionHoldSeconds` cut under
    ///   Reduce Motion; otherwise `splashHoldSeconds` then a `splashFadeSeconds` fade.
    ///   Every result is ≤ `maxSplashSeconds` (pinned by `splashNeverHoldsLongerThanASecond`).
    public static func splash(reduceMotion: Bool, voiceOver: Bool, automation: Bool) -> Splash {
        if voiceOver || automation { return .skip }
        if reduceMotion { return .show(holdSeconds: reduceMotionHoldSeconds, fadeSeconds: 0) }
        return .show(holdSeconds: splashHoldSeconds, fadeSeconds: splashFadeSeconds)
    }

    /// Whether first-launch onboarding shows this launch.
    /// - Parameters:
    ///   - completed: the stored `onboardingCompletedKey` flag.
    ///   - automation: an XCUITest, a muted e2e run or a `--demo-route` launch (they drive the Guide
    ///     screen at once and never finished onboarding in their simulator).
    ///   - forced: `CANEKIT_SHOW_ONBOARDING=1`, for a UI test of the pages themselves.
    /// - Returns: `forced`, or a fresh install outside automation.
    public static func showsOnboarding(completed: Bool, automation: Bool, forced: Bool) -> Bool {
        if forced { return true }
        return !completed && !automation
    }
}
