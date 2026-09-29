//
//  OnboardingContentTests.swift
//  CaneKitLogicTests
//
//  Purpose: pins OnboardingContent.swift — the first-launch pages and the permission rows' words
//  (Step 69.3).
//
//  Why these are the tests: the owner's brief. "3 to 4 swipeable pages … each page: large SF
//  Symbol, short title, one or two sentences of body text" (`threeOrFourPagesOfShortCopy`); "a
//  large Get Started button … on the last page, a Next button on earlier pages"
//  (`nextThenGetStarted`); the last page explains and requests permissions in context
//  (`lastPageIsPermissions`); every permission row says why in one line and its button says what
//  will happen, including a refused permission, which can only be changed in Settings
//  (`permissionButtonsSayWhatHappens`, `locationNamesMapToStates`). The spoken position ("Page 2
//  of 4") is what VoiceOver reads on the Next button (`spokenPositionCountsFromOne`).
//
//  Source pinned: `ios/Logic/Sources/CaneKitLogic/OnboardingContent.swift`. Callers:
//  `OnboardingView`, `PermissionsPanel` (app).
//

import Testing
@testable import CaneKitLogic

@Suite("Onboarding content")
struct OnboardingContentTests {

    /// Counts sentences the way a listener hears them: runs ending in . ! or ?.
    private func sentences(_ text: String) -> Int {
        text.split(whereSeparator: { ".!?".contains($0) })
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }

    @Test func threeOrFourPagesOfShortCopy() {
        let pages = OnboardingContent.pages
        #expect((3...4).contains(pages.count))
        for page in pages {
            #expect(!page.systemImage.isEmpty)
            #expect(page.title.count <= 40, "title too long: \(page.title)")
            #expect((1...2).contains(sentences(page.body)), "body must be one or two sentences: \(page.body)")
        }
        // Stable, zero-based, in order: the TabView tags and the focus state key on `id`.
        #expect(pages.map(\.id) == Array(0..<pages.count))
    }

    /// The brief's order: the product, what LiDAR adds, how guidance feels, then permissions.
    @Test func lastPageIsPermissions() {
        let pages = OnboardingContent.pages
        #expect(pages.last?.isPermissions == true)
        #expect(pages.dropLast().allSatisfy { !$0.isPermissions })
        #expect(pages[1].body.contains("head height"))
    }

    @Test func nextThenGetStarted() {
        let count = OnboardingContent.pages.count
        #expect(OnboardingContent.primaryButtonTitle(page: 0, count: count) == "Next")
        #expect(OnboardingContent.primaryButtonTitle(page: count - 2, count: count) == "Next")
        #expect(OnboardingContent.primaryButtonTitle(page: count - 1, count: count) == "Get Started")
        // Skip is offered everywhere but the last page (where Get Started already finishes).
        #expect(OnboardingContent.showsSkip(page: 0, count: count))
        #expect(!OnboardingContent.showsSkip(page: count - 1, count: count))
    }

    @Test func spokenPositionCountsFromOne() {
        #expect(OnboardingContent.spokenPosition(page: 0, count: 4) == "Page 1 of 4")
        #expect(OnboardingContent.spokenPosition(page: 3, count: 4) == "Page 4 of 4")
    }

    @Test func permissionRowsSayWhy() {
        let rows = OnboardingContent.permissions
        #expect(rows.map(\.kind) == [.camera, .location, .microphone])
        for row in rows {
            #expect(!row.reason.isEmpty)
            #expect(sentences(row.reason) == 1, "one line of why: \(row.reason)")
        }
    }

    @Test func permissionButtonsSayWhatHappens() {
        #expect(OnboardingContent.actionTitle(for: .notAsked) == "Allow")
        #expect(OnboardingContent.actionTitle(for: .allowed) == "Allowed")
        #expect(OnboardingContent.actionTitle(for: .denied) == "Open Settings")
        #expect(OnboardingContent.spokenState(.notAsked) == "not allowed yet")
        #expect(OnboardingContent.spokenState(.allowed) == "allowed")
        #expect(OnboardingContent.spokenState(.denied) == "turned off. Change it in Settings")
    }

    /// `LocationService.authorizationName` strings → states (When In Use is enough to guide).
    @Test func locationNamesMapToStates() {
        #expect(PermissionState(locationAuthorizationName: "always") == .allowed)
        #expect(PermissionState(locationAuthorizationName: "whenInUse") == .allowed)
        #expect(PermissionState(locationAuthorizationName: "denied") == .denied)
        #expect(PermissionState(locationAuthorizationName: "restricted") == .denied)
        #expect(PermissionState(locationAuthorizationName: "notDetermined") == .notAsked)
        #expect(PermissionState(locationAuthorizationName: "unknown") == .notAsked)
    }
}
