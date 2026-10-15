import Foundation
import SwiftData
import WidgetKit

/// The one SwiftData store, kept in an App Group container so the app, the widget and Shortcuts all read and write
/// the same habits.
enum SharedStore {
    static let appGroup = "group.com.harishv27.kept"

    static let container: ModelContainer = {
        let schema = Schema([Habit.self])
        let configuration = ModelConfiguration(schema: schema, groupContainer: .identifier(appGroup))
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not open the habit store: \(error)")
        }
    }()

    /// A fresh context for work outside the main view hierarchy (widget buttons, Shortcuts).
    static func makeContext() -> ModelContext { ModelContext(container) }

    static func reloadWidgets() { WidgetCenter.shared.reloadAllTimelines() }
}
