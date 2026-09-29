//
//  OnboardingContent.swift
//  CaneKitLogic
//
//  The words of first-launch onboarding (Step 69.3): four pages, the permission rows on the last
//  one, and the button / state wording. Pure data and small decisions, so the copy rules are
//  tested (one or two sentences a page, Next then Get Started, a refused permission sends the
//  walker to Settings).
//
//  Why the permissions are camera, location and microphone: they are what OpenCane actually uses
//  on a walk (LiDAR + camera for obstacles, GPS for guidance, the microphone for spoken commands and
//  the optional siren listener). The owner's brief also named notifications; OpenCane posts no
//  notifications (family alerts go out through the Grok Bot service, the Live Activity needs no
//  permission), so asking would be a prompt with no purpose — CHANGELOG Step 69.3 records the
//  swap. Motion and HealthKit stay where they are, asked at the first route start.
//
//  Owner / callers: `OnboardingView` and `PermissionsPanel` (app, ios/CaneKit/UI/OnboardingView.swift).
//  Tests: OnboardingContentTests.swift.
//

import Foundation

/// One onboarding page.
public struct OnboardingPage: Sendable, Equatable, Identifiable {
    /// Zero-based position; the `TabView` tag and the VoiceOver focus key.
    public let id: Int
    /// The page's large SF Symbol (decoration; hidden from VoiceOver).
    public let systemImage: String
    /// Short title, read as a heading.
    public let title: String
    /// One or two sentences.
    public let body: String
    /// True for the last page, which also shows the permission rows.
    public let isPermissions: Bool
}

/// Whether the walker has answered a permission, as the onboarding row shows it.
public enum PermissionState: Sendable, Equatable {
    /// Never asked: the row offers "Allow".
    case notAsked
    /// Granted (for location, When In Use is enough).
    case allowed
    /// Refused or restricted: only the Settings app can change it now.
    case denied

    /// Maps `LocationService.authorizationName` ("always", "whenInUse", "denied", "restricted",
    /// "notDetermined", "unknown").
    public init(locationAuthorizationName name: String) {
        switch name {
        case "always", "whenInUse": self = .allowed
        case "denied", "restricted": self = .denied
        default: self = .notAsked
        }
    }
}

/// A permission OpenCane asks for on the last onboarding page.
public enum PermissionKind: String, Sendable, CaseIterable {
    case camera, location, microphone
}

/// One permission row: what it is and why, in a line.
public struct PermissionRow: Sendable, Equatable {
    public let kind: PermissionKind
    /// SF Symbol for the row.
    public let systemImage: String
    /// "Camera and LiDAR".
    public let title: String
    /// One sentence: why OpenCane needs it.
    public let reason: String
}

/// The onboarding pages and wording.
public enum OnboardingContent {

    /// The four pages, in order: the product, what LiDAR adds, how guidance feels, permissions.
    public static let pages: [OnboardingPage] = [
        OnboardingPage(id: 0, systemImage: "iphone.gen3",
                       title: "Your iPhone, on your cane",
                       body: "OpenCane turns the iPhone you already own into a smart cane attachment. Clip it to your white cane and it guides every walk.",
                       isPermissions: false),
        OnboardingPage(id: 1, systemImage: "dot.radiowaves.forward",
                       title: "Warnings above the cane tip",
                       body: "LiDAR detects obstacles at waist and head height, which a cane tip misses. The cane taps before you reach them.",
                       isPermissions: false),
        OnboardingPage(id: 2, systemImage: "airpodspro",
                       title: "Feel and hear the way",
                       body: "Haptics and spatial audio guide you to your destination. Turns and crossings are spoken before you reach them.",
                       isPermissions: false),
        OnboardingPage(id: 3, systemImage: "checkmark.shield.fill",
                       title: "A few permissions",
                       body: "OpenCane asks only for what guidance needs. You can change any of these later in the Settings app.",
                       isPermissions: true),
    ]

    /// The rows on the permissions page, in the order they are shown.
    public static let permissions: [PermissionRow] = [
        PermissionRow(kind: .camera, systemImage: "camera.fill", title: "Camera and LiDAR",
                      reason: "Detects obstacles ahead of you, including at head height."),
        PermissionRow(kind: .location, systemImage: "location.fill", title: "Location",
                      reason: "Guides you along your route, turn by turn."),
        PermissionRow(kind: .microphone, systemImage: "mic.fill", title: "Microphone",
                      reason: "Hears spoken commands, and sirens if you turn that on."),
    ]

    /// "Next" on every page but the last, which says "Get Started".
    public static func primaryButtonTitle(page: Int, count: Int) -> String {
        page >= count - 1 ? "Get Started" : "Next"
    }

    /// Skip sits in the top corner of every page but the last.
    public static func showsSkip(page: Int, count: Int) -> Bool {
        page < count - 1
    }

    /// "Page 2 of 4" — the Next button's VoiceOver value.
    public static func spokenPosition(page: Int, count: Int) -> String {
        "Page \(page + 1) of \(count)"
    }

    /// The row button's title for a state.
    public static func actionTitle(for state: PermissionState) -> String {
        switch state {
        case .notAsked: "Allow"
        case .allowed: "Allowed"
        case .denied: "Open Settings"
        }
    }

    /// The state as VoiceOver says it at the end of the row's label.
    public static func spokenState(_ state: PermissionState) -> String {
        switch state {
        case .notAsked: "not allowed yet"
        case .allowed: "allowed"
        case .denied: "turned off. Change it in Settings"
        }
    }
}
