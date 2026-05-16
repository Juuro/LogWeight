import AppIntents

/// Registers widget App Intents with the host app so interactive controls can
/// resolve types and run `SaveWeightIntent` in the app process.
struct LogWeightAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SaveWeightIntent(),
            phrases: [
                "Save weight in \(.applicationName)",
                "Log weight in \(.applicationName)",
            ],
            shortTitle: "Save Weight",
            systemImageName: "scalemass"
        )
    }
}
