import SwiftUI
import LogWeightCore

/// A button that fires `action` immediately on press, then auto-repeats at an
/// accelerating rate while the user holds the control down.
///
/// Timing contract (see `LongPressRepeatPolicy.stepButtonDefault` in `LogWeightCore`):
/// - **t = 0**: first `action` fires as soon as the press is detected.
/// - **t = 0.4 s**: first auto-repeat step fires; subsequent steps every **0.2 s**.
/// - **After 2 s of repeating**: interval drops to **0.04 s** (≈ 25 steps / s).
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
                            await runLongPressRepeatLoop(
                                policy: .stepButtonDefault,
                                clock: SystemLongPressClock()
                            ) {
                                action()
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
