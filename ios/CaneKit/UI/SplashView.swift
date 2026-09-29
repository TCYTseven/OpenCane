//
//  SplashView.swift
//  CaneKit
//
//  The brand moment between the static launch screen and the first usable screen (Step 69.2).
//
//  It repeats the launch screen exactly — `LaunchLogo` at its own point size, centred in the safe
//  area on the brand navy (`CKColor.brand`, the same hex as the asset colour `LaunchBackground`) —
//  so the handoff has no flash, then adds the "OpenCane" wordmark and one line under it. `RootView`
//  removes it after `LaunchFlow.splash(...)`'s plan: ≤ 1 s in total, a still cut under Reduce
//  Motion, and no splash at all under VoiceOver or automation.
//
//  Accessibility: the whole view is `accessibilityHidden`. It carries nothing a VoiceOver user
//  needs, VoiceOver launches skip it entirely (`LaunchFlow`), and hiding it means a VoiceOver user
//  who turns VoiceOver on mid-splash is never parked on a view that is about to vanish. The main
//  screen and its engines run underneath from the first frame; the splash never delays `start()`.
//
//  Owner / caller: `RootView` (overlay above the first screen). Tests: the timing is
//  `LaunchFlowTests`; the picture is checked by eye (`make tour` starts after it, under automation,
//  so the tour never sees it).
//

import SwiftUI

/// Navy ground, the launch logo, and the wordmark rising in under it.
struct SplashView: View {
    /// False under Reduce Motion: the wordmark is simply there, with no fade and no rise.
    let animates: Bool
    /// Drives the wordmark's fade / rise when `animates`.
    @State private var wordmarkIn = false

    /// The launch screen's picture plus the wordmark, positioned below the logo with an alignment
    /// guide so the logo stays exactly where the launch screen drew it.
    var body: some View {
        ZStack {
            CKColor.brand.ignoresSafeArea()
            Image("LaunchLogo")
                .overlay(alignment: .bottom) {
                    wordmark
                        .alignmentGuide(.bottom) { d in d[.top] - CKSpacing.xl }
                }
        }
        .accessibilityHidden(true)
        .onAppear {
            guard animates else { wordmarkIn = true; return }
            withAnimation(.easeOut(duration: 0.3)) { wordmarkIn = true }
        }
    }

    /// "OpenCane" and the one-line promise, centred, fading and rising 8 pt into place.
    private var wordmark: some View {
        VStack(spacing: CKSpacing.xs) {
            Text("OpenCane")
                .font(CKFont.display)
                .foregroundStyle(CKColor.onBrand)
            Text("A smart cane kit for your iPhone")
                .font(CKFont.secondary)
                .foregroundStyle(CKColor.onBrandSecondary)
        }
        .multilineTextAlignment(.center)
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)
        .opacity(wordmarkIn ? 1 : 0)
        .offset(y: wordmarkIn || !animates ? 0 : 8)
    }
}

#Preview("Splash") {
    SplashView(animates: true)
}
