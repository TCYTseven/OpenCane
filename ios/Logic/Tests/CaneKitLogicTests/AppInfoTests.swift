//
//  AppInfoTests.swift
//  CaneKitLogicTests
//
//  Purpose: pins AppInfo.swift — the About card's version line, the public links (privacy
//  policy, terms, source) shared by Settings and the paywall, and the Profile avatar's initials
//  (Step 69.4 UI pass).
//
//  Why these are the tests: App Review and the RevenueCat judges both look for a privacy policy and
//  terms link that work (`linksAreHTTPS`); the version line is what a tester reads back to the team
//  (`versionLineReadsLikeSettings`); the Profile avatar used to be one teammate's photo for every
//  walker, and the default profile's name is the placeholder "Not set", which must not become "NS"
//  (`initialsSkipThePlaceholder`).
//
//  Source pinned: `ios/Logic/Sources/CaneKitLogic/AppInfo.swift`. Callers: the Settings About card
//  (ContentView.swift), `PaywallView`, `ProfilePage`.
//

import Testing
@testable import CaneKitLogic

@Suite("App info")
struct AppInfoTests {

    @Test func versionLineReadsLikeSettings() {
        #expect(AppInfo.versionLine(short: "1.0", build: "7") == "Version 1.0 (7)")
        #expect(AppInfo.versionLine(short: "1.0", build: nil) == "Version 1.0")
        #expect(AppInfo.versionLine(short: nil, build: nil) == "Version unknown")
    }

    @Test func linksAreHTTPS() {
        for link in [AppInfo.privacyPolicyURL, AppInfo.termsOfUseURL, AppInfo.sourceCodeURL] {
            #expect(link.hasPrefix("https://"), "\(link)")
        }
        #expect(AppInfo.privacyPolicyURL.hasSuffix("PRIVACY.md"))
    }

    @Test func initialsFromAName() {
        #expect(AppInfo.initials(of: "Aritro Bhattacharya") == "AB")
        #expect(AppInfo.initials(of: "  jane   q  public ") == "JP")
        #expect(AppInfo.initials(of: "Cher") == "C")
    }

    @Test func initialsSkipThePlaceholder() {
        #expect(AppInfo.initials(of: "Not set") == nil)
        #expect(AppInfo.initials(of: "") == nil)
        #expect(AppInfo.initials(of: "   ") == nil)
    }
}
