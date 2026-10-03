//
//  HushPolicy.swift
//  CaneKitLogic
//
//  The hush gesture: one Watch double tap silences non-safety speech and non-head haptics for
//  60 s, and the only acknowledgement is a single soft buzz — no spoken line, because a hush that
//  announces itself out loud defeats the request that prompted it. Cue design v2
//  (docs/cue_design_v2.md §3.5 line 161 and §4 row 11).
//
//  Why: "Silence haptics" is the wrong shape for the problem it gets reached for. It mutes the
//  cane and *re-routes* obstacle cues into speech and the watch (docs/design.md:370,
//  `CueSpeechPolicy.line(for:phoneCannotBuzz:)`), so a walker who wants the phone to stop talking
//  in a quiet carriage has no control that does it — the one toggle they have makes the talking
//  worse. v2 logs this as violation V8 (docs/cue_design_v2.md:85): "No verbosity levels, only
//  per-feature toggles … I did not find a one-gesture speech hush in the files I read." This is
//  that gesture, and it runs the substitution the other way: the buzz carries the signal and the
//  voice stops.
//
//  The rules (numbers in `HushThresholds`, seconds):
//    · A hush lasts `durationS` (60 s) from the tap, then lapses on its own. There is no "hushed
//      until I say otherwise": a walker who forgets they hushed must get their cues back, so the
//      window expires rather than latching.
//    · Head cues are exempt, haptic and spoken alike — AGENTS.md hard rule 8 and `TorsoHapticPolicy`'s
//      safety floor ("the `.head` haptic is never suppressed and its onset never delayed"). An
//      overhang at face height is the one thing a walker cannot discover with the cane tip, and a
//      60-second silence must not be able to hide it. docs/cue_design_v2.md:110 states the carve-out
//      directly: "The hush gesture does not affect it."
//    · Ground hazards are exempt for the same reason. They do not travel as a `HapticCue` at all
//      (`AppModel.groundHazardFound` → `HapticPlayer.playGroundHazard()`), so that path must simply
//      never consult this policy; `allows(_:)` covers the cue channel only.
//    · `.safety`-tier speech is exempt; `.obstacle`-tier speech is held. The tier split is already
//      `CueSpeechPolicy.Tier`, so hush adds no second notion of what counts as safety.
//    · Left, right and centre-approach haptics are held. With speech held too, this is the state
//      the owner asked for: the cane buzzes for what it finds, head height still speaks, nothing
//      else does.
//    · Re-tapping inside an active hush extends the window to a full `durationS` from the new tap
//      and returns false, so the app does not stack a second confirmation buzz on the first.
//
//  Pure: Foundation-only, no clock — the caller passes `now` (the depth report's AR timestamp in
//  the app), which must not go backwards within one policy's life, exactly as `TorsoHapticPolicy`
//  and `CueDecider` take it. Value type; not shared between actors.
//  Owner (not yet wired — this step adds the decision, the app effects come next): `AppModel`,
//  consulted in `handle(_:)` after `TorsoHapticPolicy.update` and in `speakCueIfNeeded`, engaged
//  from the Watch double tap over `WatchMessage`, and `reset()` wherever the decider resets.
//  Tests: `HushPolicyTests.swift` (suite "Hush gesture").
//

import Foundation

/// The numbers behind `HushPolicy` (seconds). The default is the approved design
/// (docs/cue_design_v2.md:161); pinned by `thresholdDefaultIsTheDesign`.
public struct HushThresholds: Sendable, Equatable {
    /// How long one tap holds the hush. Lapses on its own — see the header on why it never latches.
    public var durationS: TimeInterval = 60

    /// Creates the approved 60 s window.
    public init() {}
}

/// What a hush is allowed to silence, for one cue or one spoken line.
public struct HushPolicy: Sendable, Equatable {
    /// The numbers; `durationS` is the only one.
    public var thresholds = HushThresholds()

    /// When the active hush lapses; nil when no hush is running.
    private var activeUntil: TimeInterval?

    /// Creates a policy with no hush running and the approved 60 s window.
    public init(thresholds: HushThresholds = HushThresholds()) {
        self.thresholds = thresholds
    }

    /// Start a hush, or extend the one already running.
    /// - Parameter now: seconds (the depth report's timestamp in the app).
    /// - Returns: true when this tap started a hush from nothing — the app plays the single soft
    ///   confirmation buzz only then. A re-tap inside an active hush extends the window and
    ///   returns false, so a walker tapping twice does not feel two buzzes.
    @discardableResult
    public mutating func engage(now: TimeInterval) -> Bool {
        let fresh = !isActive(now: now)
        activeUntil = now + thresholds.durationS
        return fresh
    }

    /// True while a hush is holding. Expiry is evaluated against `now`, never on a timer.
    public func isActive(now: TimeInterval) -> Bool {
        guard let until = activeUntil else { return false }
        return now < until
    }

    /// Seconds until the hush lapses, or nil when none is running. For the status line
    /// ("Hushed, 40 seconds left") and the trip log.
    public func remaining(now: TimeInterval) -> TimeInterval? {
        guard let until = activeUntil, now < until else { return nil }
        return until - now
    }

    /// End the hush now — a new route, a backgrounded app, a reset decider. Idempotent.
    public mutating func reset() {
        activeUntil = nil
    }

    /// Whether a fired haptic cue should still be rendered.
    ///
    /// Head cues are always allowed: the safety floor outranks the hush (AGENTS.md hard rule 8,
    /// docs/cue_design_v2.md:110). Ground hazards never reach this method — they are not a
    /// `HapticCue` — and must stay on the unconditional `playGroundHazard()` path.
    public func allows(_ cue: HapticCue, now: TimeInterval) -> Bool {
        if case .head = cue { return true }
        return !isActive(now: now)
    }

    /// Whether a spoken line should still be said. `.safety` always passes; `.obstacle` is held
    /// for the duration of the hush.
    public func allowsSpeech(tier: CueSpeechPolicy.Tier, now: TimeInterval) -> Bool {
        if tier == .safety { return true }
        return !isActive(now: now)
    }
}
