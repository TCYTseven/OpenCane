//
//  LaunchFlowTests.swift
//  CaneKitLogicTests
//
//  Purpose: pins LaunchFlow.swift — how long the splash may hold the screen, when it is skipped,
//  and when first-launch onboarding shows (Step 69.2 / 69.3).
//
//  Why these are the tests: the owner's accessibility rules for the Shipaton build. "The splash
//  screen must not block VoiceOver or delay launch more than about 1 second" and "skip the
//  animation if Reduce Motion is on" (`splashNeverHoldsLongerThanASecond`,
//  `voiceOverAndAutomationSkipTheSplash`, `reduceMotionIsACutNotAFade`). Onboarding is first launch
//  only, and must never stand between an XCUITest / e2e run and the Guide screen those runs drive
//  (`automationAndDemoRoutesNeverOnboard`); a UI test that wants the pages forces them
//  (`aForcedRunShowsOnboardingEvenAfterCompletion`).
//
//  Source pinned: `ios/Logic/Sources/CaneKitLogic/LaunchFlow.swift` (`splashHoldSeconds` 0.6,
//  `splashFadeSeconds` 0.25, `reduceMotionHoldSeconds` 0.4, `maxSplashSeconds` 1.0,
//  `onboardingCompletedKey`, `splash(reduceMotion:voiceOver:automation:)`,
//  `showsOnboarding(completed:priorInstall:automation:forced:)`, `isPriorInstall`). Caller: `RootView` (app).
//

import Testing
@testable import CaneKitLogic

@Suite("Launch flow: splash and onboarding")
struct LaunchFlowTests {

    /// The numbers, as the doc comments and CHANGELOG Step 69 state them.
    @Test func numbersArePinned() {
        #expect(LaunchFlow.splashHoldSeconds == 0.6)
        #expect(LaunchFlow.splashFadeSeconds == 0.25)
        #expect(LaunchFlow.reduceMotionHoldSeconds == 0.4)
        #expect(LaunchFlow.maxSplashSeconds == 1.0)
        // ⚠ Persisted under this key by `@AppStorage`: renaming it re-onboards every walker.
        #expect(LaunchFlow.onboardingCompletedKey == "onboardingCompleted")
    }

    /// Owner rule: "delay launch no more than about 1 second" — for every combination of inputs.
    @Test func splashNeverHoldsLongerThanASecond() {
        for reduceMotion in [false, true] {
            for voiceOver in [false, true] {
                for automation in [false, true] {
                    let plan = LaunchFlow.splash(reduceMotion: reduceMotion, voiceOver: voiceOver,
                                                 automation: automation)
                    #expect(plan.totalSeconds <= LaunchFlow.maxSplashSeconds)
                }
            }
        }
    }

    /// VoiceOver users go straight to the app (the splash carries nothing they need, and a view
    /// swap mid-read moves focus); automation must not wait on a brand moment.
    @Test func voiceOverAndAutomationSkipTheSplash() {
        #expect(LaunchFlow.splash(reduceMotion: false, voiceOver: true, automation: false) == .skip)
        #expect(LaunchFlow.splash(reduceMotion: true, voiceOver: true, automation: false) == .skip)
        #expect(LaunchFlow.splash(reduceMotion: false, voiceOver: false, automation: true) == .skip)
        #expect(LaunchFlow.splash(reduceMotion: false, voiceOver: false, automation: true).totalSeconds == 0)
    }

    /// Reduce Motion keeps a short, still hold (the launch-screen handoff) with no fade.
    @Test func reduceMotionIsACutNotAFade() {
        let plan = LaunchFlow.splash(reduceMotion: true, voiceOver: false, automation: false)
        #expect(plan == .show(holdSeconds: 0.4, fadeSeconds: 0))
        #expect(plan.animates == false)
    }

    /// The default: hold, then fade.
    @Test func defaultHoldsThenFades() {
        let plan = LaunchFlow.splash(reduceMotion: false, voiceOver: false, automation: false)
        #expect(plan == .show(holdSeconds: 0.6, fadeSeconds: 0.25))
        #expect(plan.animates)
        #expect(plan.totalSeconds == 0.85)
    }

    /// First launch only.
    @Test func onboardingShowsOnceOnAFreshInstall() {
        #expect(LaunchFlow.showsOnboarding(completed: false, priorInstall: false, automation: false, forced: false))
        #expect(!LaunchFlow.showsOnboarding(completed: true, priorInstall: false, automation: false, forced: false))
    }

    /// Review round 69.7: a phone that ran OpenCane before Step 69 has no `onboardingCompleted` key.
    /// Onboarding in front of it would hold every engine (and "OpenCane ready.") behind silent
    /// pages on the owner's own demo phone. A prior install counts as completed.
    @Test func anUpgradedInstallIsNeverOnboarded() {
        #expect(!LaunchFlow.showsOnboarding(completed: false, priorInstall: true, automation: false, forced: false))
        #expect(LaunchFlow.showsOnboarding(completed: false, priorInstall: true, automation: false, forced: true))
    }

    /// The UserDefaults keys that prove an earlier launch (each written by a pre-Step-69 build).
    @Test func priorInstallKeysAreRealSettings() {
        #expect(LaunchFlow.isPriorInstall(defaultsKeys: ["AppleLanguages", "cueLevel"], documentNames: []))
        #expect(LaunchFlow.isPriorInstall(defaultsKeys: [], documentNames: ["canekit-2026-09-13T15-48-34Z.jsonl"]))
        #expect(!LaunchFlow.isPriorInstall(defaultsKeys: ["AppleLanguages", "NSInterfaceStyle"], documentNames: ["notes.txt"]))
        #expect(LaunchFlow.priorInstallKeys.contains("opencane_medical_profile"))
    }

    /// XCUITests (`CANEKIT_UITEST=1`), muted e2e (`CANEKIT_MUTE=1`) and `--demo-route` launches all
    /// expect the Guide screen at once; none of them has "completed" onboarding in its simulator.
    @Test func automationAndDemoRoutesNeverOnboard() {
        #expect(!LaunchFlow.showsOnboarding(completed: false, priorInstall: false, automation: true, forced: false))
    }

    /// `CANEKIT_SHOW_ONBOARDING=1` (a UI test of the pages) wins over both.
    @Test func aForcedRunShowsOnboardingEvenAfterCompletion() {
        #expect(LaunchFlow.showsOnboarding(completed: true, priorInstall: true, automation: true, forced: true))
        #expect(LaunchFlow.showsOnboarding(completed: false, priorInstall: false, automation: true, forced: true))
    }
}
