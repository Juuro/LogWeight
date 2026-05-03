import SwiftUI

/// A button that fires `action` immediately on press, then auto-repeats at an
/// accelerating rate while the user holds the control down.
///
/// Timing contract:
/// - **t = 0**: first `action` fires as soon as the press is detected.
/// - **t = 0.4 s**: first auto-repeat step fires; subsequent steps every **0.2 s**.
/// - **After 2 s of repeating**: interval drops to **0.07 s** (≈ 14 steps / s).
/// - **Release**: all repeating stops immediately.
///
/// Works on iOS (touch), watchOS (touch), and macOS (mouse hold) via
/// `DragGesture(minimumDistance: 0)` which detects the moment a finger or
/// mouse button goes down.
///
/// **Accessibility note**: VoiceOver and Switch Control users activate the button
/// once per interaction (single `action` call), which is standard behaviour for
/// increment / decrement controls. Long-press acceleration is a touch / pointer
/// feature and does not apply to assistive-technology activation.
///
/// Callers should apply `.accessibilityLabel` and `.accessibilityIdentifier`
/// directly on `LongPressStepButton` — in SwiftUI, custom `View` structs are
/// transparent accessibility boundaries, so those modifiers reach the same
/// underlying element as the `.accessibilityAddTraits` / `.accessibilityAction`
/// modifiers set internally by this component.
struct LongPressStepButton<Label: View>: View {

    // MARK: - Timing constants

    /// Delay between the initial press and the start of auto-repeat.
    private static let initialDelay: TimeInterval = 0.4
    /// Auto-repeat interval during the slow phase.
    private static let slowInterval: TimeInterval = 0.2
    /// How long the slow phase lasts before acceleration kicks in.
    private static let accelerationThreshold: TimeInterval = 2.0
    /// Auto-repeat interval after acceleration.
    private static let fastInterval: TimeInterval = 0.07

    // MARK: -

    let action: () -> Void
    @ViewBuilder var label: () -> Label

    @State private var longPressTask: Task<Void, Never>?

    var body: some View {
        label()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard longPressTask == nil else { return }
                        longPressTask = Task { @MainActor in
                            // The initial action fires unconditionally so that every
                            // press-down (including a quick tap that is immediately
                            // cancelled) registers at least one step. Cancellation is
                            // checked only before each *repeat* step in the loop below.
                            action()
                            try? await Task.sleep(for: .seconds(Self.initialDelay))
                            guard !Task.isCancelled else { return }
                            let repeatStart = Date()
                            var accelerated = false
                            while !Task.isCancelled {
                                action()
                                if !accelerated,
                                   Date().timeIntervalSince(repeatStart) > Self.accelerationThreshold {
                                    accelerated = true
                                }
                                try? await Task.sleep(
                                    for: .seconds(accelerated ? Self.fastInterval : Self.slowInterval)
                                )
                            }
                        }
                    }
                    .onEnded { _ in
                        longPressTask?.cancel()
                        longPressTask = nil
                    }
            )
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
            .onDisappear {
                longPressTask?.cancel()
                longPressTask = nil
            }
    }
}
