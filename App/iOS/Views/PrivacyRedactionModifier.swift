import SwiftUI
import UIKit

/// Overlays an opaque redaction view when the app is backgrounded or being
/// recorded.
///
/// `.privacySensitive()` covers the system's own screenshot moments
/// (app switcher, Siri suggestions). This modifier covers the additional cases
/// where the user is foregrounded but the screen is being captured (screen
/// recording, AirPlay mirroring), AS FAR AS Apple's APIs report.
///
/// Known limitations (DA8, documented in `Docs/Privacy.md`):
/// - `isSceneCaptured` does not always fire during AirPlay mirroring.
/// - `isSceneCaptured` does not fire during wired QuickTime recording.
/// These are Apple-framework limitations, not defects in LogWeight.
struct PrivacyRedactionModifier: ViewModifier {

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isSceneCaptured) private var isCaptured

    func body(content: Content) -> some View {
        ZStack {
            content
            if shouldRedact {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("LogWeight")
                                .font(.headline)
                        }
                    )
                    .accessibilityHidden(true)
            }
        }
    }

    private var shouldRedact: Bool {
        if scenePhase != .active { return true }
        if isCaptured { return true }
        return false
    }
}
