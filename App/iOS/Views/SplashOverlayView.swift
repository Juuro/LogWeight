import SwiftUI

struct SplashOverlayView: View {
    let showPreparing: Bool
    let onSkip: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var ringAnimating = false
    @State private var iconFloating = false

    var body: some View {
        ZStack {
            Color("LaunchBackground")
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(Color.accentColor.opacity(0.28), lineWidth: 12)
                        .frame(width: 152, height: 152)
                        .scaleEffect(ringAnimating ? 1.06 : 0.93)
                        .opacity(ringAnimating ? 0.34 : 0.9)
                        .animation(
                            reduceMotion ? .linear(duration: 0.01) : .easeInOut(duration: 0.92).repeatForever(autoreverses: true),
                            value: ringAnimating
                        )

                    Image(systemName: "scalemass.fill")
                        .font(.system(size: 60, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .scaleEffect(1.0)
                        .opacity(1.0)
                        .offset(y: iconFloating ? -3 : 3)
                        .animation(
                            reduceMotion ? .linear(duration: 0.01) : .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                            value: iconFloating
                        )
                }

                Text("LogWeight")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                if showPreparing {
                    Text("Preparing your data…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 24)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("LogWeight splash screen")
        .accessibilityHint(showPreparing ? "Preparing your data. Tap to continue when ready." : "Tap to continue")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("splash.overlay")
        .contentShape(Rectangle())
        .onTapGesture {
            onSkip()
        }
        .onAppear {
            // Animate immediately on first frame so startup feels responsive.
            ringAnimating = true
            iconFloating = true
        }
    }
}
