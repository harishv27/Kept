import AppIntents

/// Registers the Siri / Shortcuts phrase. Lives in the app target only; the widget shares the intents themselves.
struct KeptShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: CompleteHabitIntent(), phrases: ["Complete a habit in \(.applicationName)",
                                                             "Log a habit in \(.applicationName)"],
                    shortTitle: "Complete a habit", systemImageName: "checkmark.circle")
    }
}
