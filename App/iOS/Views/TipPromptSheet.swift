import SwiftUI

/// One-time, subtle nudge shown after `TipPromptCoordinator.promptThreshold`
/// successful entries. Never shown again after this, regardless of which
/// button the user taps — `EntryView` marks it presented before showing it.
struct TipPromptSheet: View {
    let onOpenTipJar: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart")
                .font(.largeTitle)
                .foregroundStyle(.pink)
            Text("Enjoying LogWeight?")
                .font(.title3.weight(.semibold))
            Text("It's free, with no ads and no tracking. If it's been useful, a small tip helps keep it that way.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                onOpenTipJar()
                dismiss()
            } label: {
                Text("Leave a tip")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("tipprompt.leaveTip")
            Button("Maybe later") { dismiss() }
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("tipprompt.later")
        }
        .padding(24)
        .presentationDetents([.medium])
    }
}

#if DEBUG
#Preview {
    TipPromptSheet(onOpenTipJar: {})
}
#endif
