import SwiftUI

/// A button that fires `action` immediately on press, then auto-repeats at an
/// accelerating rate while the user holds the control down.
///
/// Timing contract (see `LongPressRepeatPolicy.stepButtonDefault`):
/// - **t = 0**: first `action` fires as soon as the press is detected.
/// - **t = 0.4 s**: first auto-repeat step fires; subsequent steps every **0.2 s**.
/// - **After 2 s of repeating**: interval drops to **0.04 s** (about 25 steps/s).
/// - **Release**: all repeating stops immediately.
public struct LongPressStepButton<Label: View>: View {

    let action: () -> Void
    @ViewBuilder var label: () -> Label

    @State private var longPressTask: Task<Void, Never>?

    public init(action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.label = label
    }

    public var body: some View {
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
