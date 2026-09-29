//
//  AppInfo.swift
//  CaneKitLogic
//
//  Small facts about the app shown on screen (Step 69.4 UI pass): the About card's version line,
//  the public links (privacy policy, terms of use, source code) shared by Settings and the paywall,
//  and the initials on the Profile avatar.
//
//  Why the links live here: Settings and the paywall must point at the same pages, and App Review
//  requires working privacy / terms links next to a subscription. The privacy policy is
//  `PRIVACY.md` at the repository root (it resolves once the branch is merged to `main`); the terms
//  are Apple's standard licensed-application EULA, which applies when an app ships no EULA of its own.
//
//  Callers: `SettingsPage.aboutCard` (ContentView.swift), `PaywallView`, `ProfilePage`.
//  Tests: AppInfoTests.swift.
//

import Foundation

/// Version line, public links and avatar initials.
public enum AppInfo {
    /// OpenCane's privacy policy (repository root, `main`).
    public static let privacyPolicyURL = "https://github.com/TCYTseven/OpenCane/blob/main/PRIVACY.md"
    /// Apple's standard EULA, which covers an app that ships none of its own.
    public static let termsOfUseURL = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    /// The public repository.
    public static let sourceCodeURL = "https://github.com/TCYTseven/OpenCane"

    /// "Version 1.0 (7)" from `CFBundleShortVersionString` / `CFBundleVersion`.
    public static func versionLine(short: String?, build: String?) -> String {
        guard let short, !short.isEmpty else { return "Version unknown" }
        guard let build, !build.isEmpty else { return "Version \(short)" }
        return "Version \(short) (\(build))"
    }

    /// Up to two initials (first and last word) for the Profile avatar; nil for an empty name or
    /// the default profile's placeholder "Not set" (`CKMedicalProfile.standardDefault`).
    public static func initials(of name: String) -> String? {
        let words = name.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty, name.trimmingCharacters(in: .whitespaces) != "Not set" else { return nil }
        let first = words.first!.prefix(1)
        let last = words.count > 1 ? words.last!.prefix(1) : ""
        return (first + last).uppercased()
    }
}
