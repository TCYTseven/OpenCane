//
//  DepthStatusText.swift
//  CaneKitLogic
//
//  Plain words for `DepthEngine.status` on the Details page (Step 69.4 UI pass).
//
//  Why: the Details status card printed the engine's raw strings ("Depth OK", "No LiDAR /
//  sceneDepth on this device", "AR error: …"), which read as debug output. The raw strings are NOT
//  changed — the trip log records them and `AppModel` compares one of them ("AR interrupted") — so
//  this is a display layer only. A string the table does not know is shown as it is, never hidden.
//
//  Caller: `SensePage.statusCard` (ContentView.swift). Tests: DepthStatusTextTests.swift, which
//  lists every `status =` assignment in DepthEngine.swift; add a row there when you add one here.
//

import Foundation

/// A depth status as the Details page shows it.
public struct DepthStatusText: Sendable, Equatable {
    /// How the card marks it: a check, an hourglass, or a warning.
    public enum Tone: Sendable, Equatable { case ok, waiting, problem }

    /// One short line.
    public let title: String
    /// One sentence under it: what it means for the walker.
    public let detail: String
    /// The card's glyph and colour.
    public let tone: Tone

    /// "title. detail" — the card's VoiceOver label.
    public var spoken: String { "\(title). \(detail)" }

    /// The words for a raw `DepthEngine.status` string.
    public static func display(_ raw: String) -> DepthStatusText {
        switch raw {
        case "Depth OK", "Mesh classification on", "AR resumed":
            return .init(title: "Obstacle detection is on",
                         detail: "LiDAR is watching for obstacles at waist and head height.", tone: .ok)
        case "Mesh classification off (thermal)":
            return .init(title: "Obstacle detection is on",
                         detail: "The phone is warm, so it has stopped naming objects. Warnings continue.",
                         tone: .waiting)
        case "Depth idle", "Waiting for depth…", "Depth resuming…":
            return .init(title: "Starting obstacle detection",
                         detail: "This takes a moment. Hold the cane still if you can.", tone: .waiting)
        case "Depth paused", "AR interrupted":
            return .init(title: "Obstacle detection is paused",
                         detail: "It resumes on its own when OpenCane is on screen and the camera is free.", tone: .waiting)
        case "No LiDAR / sceneDepth on this device":
            return .init(title: "This iPhone has no LiDAR",
                         detail: "Obstacle warnings need an iPhone Pro with LiDAR. Route guidance still works.",
                         tone: .problem)
        default:
            if raw.hasPrefix("AR error: ") {
                let reason = String(raw.dropFirst("AR error: ".count))
                // `DepthEngine.sessionFailed`'s camera hint: only the Settings app can fix it.
                if reason.hasPrefix("Camera access denied") {
                    return .init(title: "Obstacle detection needs the camera",
                                 detail: "Turn on Camera for OpenCane in the Settings app.", tone: .problem)
                }
                // The engine's hints have no full stop ("LiDAR sensor unavailable").
                let sentence = reason.hasSuffix(".") ? reason : reason + "."
                return .init(title: "Obstacle detection stopped",
                             detail: "\(sentence) Close and reopen OpenCane to try again.", tone: .problem)
            }
            return .init(title: raw, detail: "Obstacle detection status.", tone: .waiting)
        }
    }
}
