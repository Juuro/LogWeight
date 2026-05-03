import SwiftUI

/// A button that fires `action` immediately on press, then auto-repeats at an
/// accelerating rate while the user holds the control down.
///
/// Timing contract:
/// - **Immediate**: first `action` fires as soon as the press is detected.
/// - **0.4 s**: auto-repeat begins at **0.2 s** intervals.
/// - **2 s** of repeating: interval drops to **0.07 s** (≈ 14 steps / s).
/// - Release: all repeating stops immediately.
///
/// Works on iOS (touch), watchOS (touch), and macOS (mouse hold) via
/// `DragGesture(minimumDistance: 0)` which detects the moment a finger or
/// mouse button goes down.
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
                            action()
                            try? await Task.sleep(for: .seconds(0.4))
                            guard !Task.isCancelled else { return }
                            let repeatStart = Date()
                            while !Task.isCancelled {
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
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
            .onDisappear {
                longPressTask?.cancel()
                longPressTask = nil
            }
    }
}
