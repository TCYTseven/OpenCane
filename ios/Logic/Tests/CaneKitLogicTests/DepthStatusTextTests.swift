//
//  DepthStatusTextTests.swift
//  CaneKitLogicTests
//
//  Purpose: pins DepthStatusText.swift — the words the Details page shows for `DepthEngine.status`
//  (Step 69.4 UI pass).
//
//  Why these are the tests: the Details status card printed the engine's raw strings ("Depth OK",
//  "No LiDAR / sceneDepth on this device", "AR error: …"), which read as debug output to a walker or
//  a judge. The raw strings stay exactly as they are — the trip log records them and
//  `AppModel` compares against "AR interrupted" — so the translation is a display layer. Every raw
//  string `DepthEngine` can set is listed here (`everyEngineStringHasPlainWords`), and one it has
//  never set still shows *something* (`unknownStringsPassThrough`). A missing LiDAR must still say
//  that guidance works (`noLidarKeepsGuidanceHonest`).
//
//  Source pinned: `ios/Logic/Sources/CaneKitLogic/DepthStatusText.swift`. Caller: the Details page
//  status card (`SensePage.statusCard`, ContentView.swift).
//

import Testing
@testable import CaneKitLogic

@Suite("Depth status text")
struct DepthStatusTextTests {

    /// Every `status =` assignment in ios/CaneKit/Depth/DepthEngine.swift, verbatim.
    static let engineStrings = [
        "Depth idle", "No LiDAR / sceneDepth on this device", "Waiting for depth…", "Depth paused",
        "Depth resuming…", "Mesh classification on", "Mesh classification off (thermal)", "Depth OK",
        "AR interrupted", "AR resumed", "AR error: Camera access denied — enable it in Settings",
        "AR error: LiDAR sensor unavailable", "AR error: Unsupported AR configuration",
    ]

    @Test func everyEngineStringHasPlainWords() {
        for raw in Self.engineStrings {
            let text = DepthStatusText.display(raw)
            #expect(text.title != raw, "\(raw) is shown raw")
            #expect(!text.title.contains("AR "), "jargon in \(text.title)")
            #expect(!text.title.contains("sceneDepth"))
            #expect(!text.detail.isEmpty)
        }
    }

    @Test func healthyIsSaidPlainly() {
        let ok = DepthStatusText.display("Depth OK")
        #expect(ok.title == "Obstacle detection is on")
        #expect(ok.tone == .ok)
        #expect(DepthStatusText.display("Mesh classification on").tone == .ok)
        #expect(DepthStatusText.display("AR resumed").tone == .ok)
    }

    @Test func noLidarKeepsGuidanceHonest() {
        let none = DepthStatusText.display("No LiDAR / sceneDepth on this device")
        #expect(none.title == "This iPhone has no LiDAR")
        #expect(none.detail.contains("Route guidance still works"))
        #expect(none.tone == .problem)
    }

    /// `DepthEngine.sessionFailed` hints come without a full stop ("LiDAR sensor unavailable").
    @Test func errorsKeepTheirReasonAsASentence() {
        let err = DepthStatusText.display("AR error: LiDAR sensor unavailable")
        #expect(err.title == "Obstacle detection stopped")
        #expect(err.detail == "LiDAR sensor unavailable. Close and reopen OpenCane to try again.")
        #expect(err.tone == .problem)
        let dotted = DepthStatusText.display("AR error: Session failed.")
        #expect(dotted.detail == "Session failed. Close and reopen OpenCane to try again.")
    }

    /// A denied camera is fixed in Settings, not by reopening the app.
    @Test func deniedCameraPointsToSettings() {
        let denied = DepthStatusText.display("AR error: Camera access denied — enable it in Settings")
        #expect(denied.title == "Obstacle detection needs the camera")
        #expect(denied.detail == "Turn on Camera for OpenCane in the Settings app.")
        #expect(denied.tone == .problem)
    }

    @Test func transitionalStatesAreWaiting() {
        for raw in ["Depth idle", "Waiting for depth…", "Depth resuming…", "Depth paused", "AR interrupted"] {
            #expect(DepthStatusText.display(raw).tone == .waiting, "\(raw)")
        }
        #expect(DepthStatusText.display("Mesh classification off (thermal)").tone == .waiting)
    }

    @Test func unknownStringsPassThrough() {
        let text = DepthStatusText.display("Something new")
        #expect(text.title == "Something new")
        #expect(text.tone == .waiting)
    }

    /// VoiceOver hears one sentence: "Obstacle detection is on. LiDAR is watching …".
    @Test func spokenIsTitleThenDetail() {
        let ok = DepthStatusText.display("Depth OK")
        #expect(ok.spoken == "\(ok.title). \(ok.detail)")
    }
}
