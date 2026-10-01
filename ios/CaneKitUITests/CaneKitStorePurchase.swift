//
//  CaneKitStorePurchase.swift
//  CaneKitUITests
//
//  The one UI test that talks to the real store: a RevenueCat Test Store purchase of OpenCane
//  Premium, end to end (Details → Hazard watch → paywall → Subscribe → the Test Store's purchase
//  sheet → Hazard watch on → Settings shows the subscription). It shoots the screens on the way
//  for Devpost and the video.
//
//  ⚠ Opt-in. It needs a RevenueCat key in Secrets.plist (a `test_…` Test Store key works in the
//  simulator) and the network, so `make uitest` skips it. Run it with
//      TEST_RUNNER_CANEKIT_STORE_TEST=1 make uitest-store SIM="CaneKit Indoor A"
//  It launches WITHOUT `CANEKIT_UITEST` (that flag forces "no store", `EntitlementManager`), and
//  passes `-onboardingCompleted YES` so the app opens on the Guide. Location and motion are
//  granted by `make sim-grant`.
//

import XCTest

@MainActor
final class CaneKitStorePurchase: XCTestCase {

    private var shotIndex = 0

    func testTestStorePurchaseUnlocksHazardWatch() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CANEKIT_STORE_TEST"] == "1",
                          "Opt-in: set TEST_RUNNER_CANEKIT_STORE_TEST=1 (needs a RevenueCat key and network)")
        continueAfterFailure = true
        let app = XCUIApplication()
        app.launchArguments += ["-onboardingCompleted", "YES"]
        app.launch()
        dismissSystemAlerts(app)

        XCTAssertTrue(app.buttons["Details"].waitForExistence(timeout: 15))
        app.buttons["Details"].tap()
        pause(1)
        let hazard = app.switches["Hazard watch, Premium"]
        XCTAssertTrue(hazard.waitForExistence(timeout: 10), "Hazard watch should be locked before the purchase")
        scrollTo(app, hazard)
        snap(app, "details-locked")
        // The row's own tap lands on the label; the knob is what flips it (same as the tour).
        let knob = hazard.switches.firstMatch
        if knob.exists, knob != hazard { knob.tap() } else { hazard.tap() }

        let subscribe = app.buttons["Subscribe"]
        XCTAssertTrue(subscribe.waitForExistence(timeout: 20), "Paywall should load the default offering")
        let price = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '49.99'")).firstMatch
        XCTAssertTrue(price.waitForExistence(timeout: 10), "Paywall should show $49.99")
        pause(1)
        snap(app, "paywall-test-store")
        subscribe.tap()

        // The Test Store's purchase sheet is an alert in the app's own process.
        let sheet = app.alerts.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 20), "Test Store purchase sheet should appear")
        pause(0.5)
        snap(app, "test-store-sheet")
        let labels = sheet.buttons.allElementsBoundByIndex.map { $0.label }
        print("TEST STORE BUTTONS: \(labels)")
        let buy = labels.first { $0.localizedCaseInsensitiveContains("valid")
                                 || $0.localizedCaseInsensitiveContains("success")
                                 || $0.localizedCaseInsensitiveContains("purchase") && !$0.localizedCaseInsensitiveContains("fail") }
        XCTAssertNotNil(buy, "No success button among \(labels)")
        if let buy { sheet.buttons[buy].tap() }

        // Purchased: the paywall closes and Hazard watch is on.
        XCTAssertTrue(subscribe.waitForNonExistence(timeout: 20), "Paywall should close after the purchase")
        pause(1.5)
        let unlocked = app.switches.matching(NSPredicate(format: "label BEGINSWITH 'Hazard watch'")).firstMatch
        XCTAssertTrue(unlocked.waitForExistence(timeout: 10))
        scrollTo(app, unlocked)
        snap(app, "details-unlocked")
        XCTAssertEqual(unlocked.value as? String, "1", "Hazard watch should be switched on after the purchase")

        app.buttons["Settings"].tap()
        pause(1)
        let renews = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'Renews' OR label CONTAINS[c] 'trial'")).firstMatch
        var swipes = 0
        while swipes < 6, !renews.exists { app.swipeUp(); swipes += 1 }
        XCTAssertTrue(renews.waitForExistence(timeout: 10), "Settings should show the subscription")
        snap(app, "settings-subscribed")
    }

    /// Location / notification prompts from a non-automation launch.
    private func dismissSystemAlerts(_ app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<4 {
            let alert = springboard.alerts.firstMatch
            guard alert.waitForExistence(timeout: 3) else { return }
            for label in ["Allow While Using App", "Allow", "OK", "Continue"] where alert.buttons[label].exists {
                alert.buttons[label].tap(); break
            }
            pause(0.5)
        }
    }

    private func scrollTo(_ app: XCUIApplication, _ element: XCUIElement) {
        var ups = 0
        while ups < 6, !(element.exists && element.isHittable) { app.swipeUp(); ups += 1 }
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        shotIndex += 1
        let png = XCUIScreen.main.screenshot().pngRepresentation
        let file = String(format: "store-%02d-%@", shotIndex, name)
        if let dir = ProcessInfo.processInfo.environment["CANEKIT_SHOTS"] {
            try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(file).png"))
        }
        let a = XCTAttachment(uniformTypeIdentifier: "public.png", name: file, payload: png)
        a.lifetime = .keepAlways
        add(a)
    }

    private func pause(_ s: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(s))
    }
}
