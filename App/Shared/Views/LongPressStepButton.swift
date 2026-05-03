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
/// mouse button goes down. A `@GestureState` flag ensures the repeat task is
/// cancelled even when the gesture fails rather than ends normally.
struct LongPressStepButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder var label: () -> Label

    @GestureState private var isHolding = false
    @State private var longPressTask: Task<Void, Never>?

    var body: some View {
        label()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isHolding) { _, state, _ in state = true }
                    .onChanged { _ in
                        // Allow a new task only when there is no active (non-cancelled) task.
                        if let existing = longPressTask, !existing.isCancelled {
                            return
                        }
                        longPressTask = Task { @MainActor in
                            action()
                            try? await Task.sleep(for: .seconds(0.4))
                            guard !Task.isCancelled else { return }
                            let repeatStart = Date()
                            while true {
                                guard !Task.isCancelled else { return }
                                action()
                                let elapsed = Date().timeIntervalSince(repeatStart)
                                let interval: TimeInterval = elapsed > 2.0 ? 0.07 : 0.2
                                try? await Task.sleep(for: .seconds(interval))
                            }
                        }
                    }
                    .onEnded { _ in
                        longPressTask?.cancel()
                        longPressTask = nil
                    }
            )
            .onChange(of: isHolding) { _, holding in
                if !holding {
                    longPressTask?.cancel()
                    longPressTask = nil
                }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
            .onDisappear {
                longPressTask?.cancel()
                longPressTask = nil
            }
    }
}
