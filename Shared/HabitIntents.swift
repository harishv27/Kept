import AppIntents
import SwiftData
import KeptCore

/// A habit as Shortcuts and Siri see it.
struct HabitEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Habit"
    static let defaultQuery = HabitQuery()

    var id: UUID
    var name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }

    init(_ habit: Habit) { self.init(id: habit.id, name: habit.name) }
}

struct HabitQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [HabitEntity] {
        let context = SharedStore.makeContext()
        let habits = try context.fetch(FetchDescriptor<Habit>(predicate: #Predicate { !$0.archived }))
        return habits.filter { identifiers.contains($0.id) }.map(HabitEntity.init)
    }

    func suggestedEntities() async throws -> [HabitEntity] {
        let context = SharedStore.makeContext()
        let habits = try context.fetch(FetchDescriptor<Habit>(predicate: #Predicate { !$0.archived },
                                                              sortBy: [SortDescriptor(\.sortOrder)]))
        return habits.map(HabitEntity.init)
    }
}

/// Flips today's check for a habit. Used by the widget's buttons.
struct ToggleHabitIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle habit for today"
    static let isDiscoverable = false

    @Parameter(title: "Habit") var habit: HabitEntity

    init() {}
    init(habit: HabitEntity) { self.habit = habit }

    func perform() async throws -> some IntentResult {
        let context = SharedStore.makeContext()
        let id = habit.id
        if let match = try context.fetch(FetchDescriptor<Habit>(predicate: #Predicate { $0.id == id })).first {
            match.toggle(Habit.today())
            try context.save()
        }
        SharedStore.reloadWidgets()
        return .result()
    }
}

/// "Log Meditation" in Shortcuts or Siri. Marks today done; never un-does it.
struct CompleteHabitIntent: AppIntent {
    static let title: LocalizedStringResource = "Complete a habit"
    static let description = IntentDescription("Marks a habit as done for today.")

    @Parameter(title: "Habit") var habit: HabitEntity

    static var parameterSummary: some ParameterSummary { Summary("Complete \(\.$habit) for today") }

    init() {}
    init(habit: HabitEntity) { self.habit = habit }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedStore.makeContext()
        let id = habit.id
        guard let match = try context.fetch(FetchDescriptor<Habit>(predicate: #Predicate { $0.id == id })).first else {
            return .result(dialog: "I couldn't find that habit.")
        }
        match.set(Habit.today(), done: true)
        try context.save()
        SharedStore.reloadWidgets()
        let streak = match.streak(today: Habit.today())
        return .result(dialog: "Done. \(match.name): \(streak.current) \(streak.unit) in a row.")
    }
}
