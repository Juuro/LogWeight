import AppIntents

/// Spoken and Shortcuts entry point for logging a weight.
///
/// Phrases belong to `LogWeightIntent` only; the widget's `SaveWeightIntent`
/// has no spoken phrases. Localized phrases live in
/// `Resources/<locale>.lproj/AppShortcuts.strings`.
struct LogWeightAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogWeightIntent(),
            phrases: [
                "Log weight in \(.applicationName)",
                "Log my weight in \(.applicationName)",
                "Save weight in \(.applicationName)",
            ],
            shortTitle: "Log Weight",
            systemImageName: "scalemass"
        )
    }
}
