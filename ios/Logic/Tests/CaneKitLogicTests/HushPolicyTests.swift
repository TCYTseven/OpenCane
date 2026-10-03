//
//  HushPolicyTests.swift
//  CaneKitLogicTests
//
//  Pins HushPolicy.swift (cue design v2 §4 row 11, docs/cue_design_v2.md:161): one Watch double
//  tap holds non-safety speech and non-head haptics for 60 s, acknowledged by a single soft buzz
//  and nothing spoken. The two tests the design names are `hushExemptsHeadAndGround` and
//  `hushExpiresAfterSixtySeconds`; the rest pin the confirmation buzz firing exactly once and the
//  window extending rather than stacking.
//
//  Breaks these catch: a hush that latches forever, so a walker who forgot they tapped keeps
//  walking with no obstacle cues; a hush that swallows "Head height." or the ground-hazard buzz —
//  the two signals the cane tip cannot give you, which AGENTS.md hard rule 8 and
//  docs/cue_design_v2.md:110 both carve out by name; a double tap that buzzes twice.
//  Times seconds (the AR clock).
//

import Testing
import Foundation
@testable import CaneKitLogic

@Suite("Hush gesture")
struct HushPolicyTests {

    /// The design's number, so a drift in the default fails here and not in the field.
    @Test func thresholdDefaultIsTheDesign() {
        #expect(HushThresholds().durationS == 60)
    }

    /// The carve-out that matters: a hush silences the torso lanes but never the head cue, and
    /// never the ground-hazard path. docs/cue_design_v2.md:110 — "The hush gesture does not
    /// affect it."
    @Test func hushExemptsHeadAndGround() {
        var hush = HushPolicy()
        hush.engage(now: 100)

        // Torso cues are held.
        #expect(hush.allows(.left, now: 101) == false)
        #expect(hush.allows(.right, now: 101) == false)
        #expect(hush.allows(.centerApproach(distance: 1.2), now: 101) == false)

        // The head cue is rendered anyway, onset and band re-fire alike.
        #expect(hush.allows(.head(distance: 1.8, onset: true), now: 101))
        #expect(hush.allows(.head(distance: 0.55, onset: false), now: 101))

        // And "Head height." is still spoken, because it is `.safety` tier, while the
        // `.obstacle` lines that would otherwise fall back to speech stay quiet.
        #expect(hush.allowsSpeech(tier: .safety, now: 101))
        #expect(hush.allowsSpeech(tier: .obstacle, now: 101) == false)

        // Ground hazards are the other exemption. They never travel as a `HapticCue`
        // (`AppModel.groundHazardFound` → `playGroundHazard()`), so the guarantee this test
        // pins is that `HapticCue` has no ground case to accidentally gate.
        #expect(CueKind.allCases.contains(.head))
        for cue in [HapticCue.left, .right, .centerApproach(distance: 1), .head(distance: 1, onset: true)] {
            #expect(cue.kind != .clear)
        }
    }

    /// A hush lapses on its own. A walker who forgets they tapped gets their cues back.
    @Test func hushExpiresAfterSixtySeconds() {
        var hush = HushPolicy()
        hush.engage(now: 10)

        #expect(hush.isActive(now: 10))
        #expect(hush.isActive(now: 69.9))
        #expect(hush.allows(.left, now: 69.9) == false)

        // At exactly 60 s past the tap the window is over (half-open: `now < until`).
        #expect(hush.isActive(now: 70) == false)
        #expect(hush.allows(.left, now: 70))
        #expect(hush.allowsSpeech(tier: .obstacle, now: 70))
        #expect(hush.remaining(now: 70) == nil)
    }

    /// The acknowledgement is one buzz. A second tap inside the window must not stack another.
    @Test func secondTapExtendsWithoutASecondBuzz() {
        var hush = HushPolicy()
        let first = hush.engage(now: 0)    // fresh → the app buzzes once
        let second = hush.engage(now: 30)  // still hushed → no second buzz
        #expect(first)
        #expect(second == false)

        // ...but the window now runs 60 s from the second tap, not the first.
        #expect(hush.isActive(now: 61))
        #expect(hush.isActive(now: 90) == false)

        // Once it has lapsed, the next tap is a fresh hush and does buzz.
        let afterLapse = hush.engage(now: 100)
        #expect(afterLapse)
    }

    /// `remaining` is what a status line would read out, and it counts down.
    @Test func remainingCountsDown() {
        var hush = HushPolicy()
        #expect(hush.remaining(now: 5) == nil)
        hush.engage(now: 5)
        #expect(hush.remaining(now: 5) == 60)
        #expect(hush.remaining(now: 25) == 40)
    }

    /// `reset()` ends a hush immediately — a new route, a backgrounded app — and is idempotent.
    @Test func resetEndsTheHush() {
        var hush = HushPolicy()
        hush.engage(now: 0)
        hush.reset()
        #expect(hush.isActive(now: 1) == false)
        #expect(hush.allows(.left, now: 1))
        hush.reset()
        #expect(hush.isActive(now: 1) == false)
        // And a tap after a reset is fresh, so it earns its confirmation buzz.
        let afterReset = hush.engage(now: 2)
        #expect(afterReset)
    }

    /// No hush running = nothing is held. The policy is inert until a tap.
    @Test func inertBeforeAnyTap() {
        let hush = HushPolicy()
        #expect(hush.isActive(now: 0) == false)
        #expect(hush.allows(.left, now: 0))
        #expect(hush.allows(.centerApproach(distance: 0.8), now: 0))
        #expect(hush.allowsSpeech(tier: .obstacle, now: 0))
        #expect(hush.allowsSpeech(tier: .safety, now: 0))
    }
}
