import SwiftUI
import SwiftData
import KeptCore

struct HabitsView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Habit> { !$0.archived }, sort: \Habit.sortOrder) private var habits: [Habit]
    @Query(filter: #Predicate<Habit> { $0.archived }, sort: \Habit.sortOrder) private var archived: [Habit]

    @State private var showingNew = false
    private let today = Habit.today()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(habits) { habit in
                        NavigationLink(value: habit) { HabitListRow(habit: habit, today: today) }
                            .swipeActions(edge: .trailing) {
                                Button("Archive") { archive(habit, true) }.tint(.orange)
                            }
                    }
                    .onMove(perform: move)
                } footer: {
                    if habits.isEmpty { Text("No habits yet. Tap + to add one.") }
                }
                if !archived.isEmpty {
                    Section("Archived") {
                        ForEach(archived) { habit in
                            NavigationLink(value: habit) { HabitListRow(habit: habit, today: today) }
                                .swipeActions(edge: .trailing) {
                                    Button("Restore") { archive(habit, false) }.tint(.accentColor)
                                }
                        }
                    }
                }
            }
            .navigationTitle("Habits")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { if habits.count > 1 { EditButton() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingNew = true } label: { Image(systemName: "plus") }.accessibilityLabel("New habit")
                }
            }
            .navigationDestination(for: Habit.self) { HabitDetailView(habit: $0, today: today) }
            .sheet(isPresented: $showingNew) { HabitEditor(habit: nil) }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = habits
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, habit) in ordered.enumerated() { habit.sortOrder = index }
        try? context.save()
    }

    private func archive(_ habit: Habit, _ value: Bool) {
        habit.archived = value
        if value == false { habit.sortOrder = (habits.map(\.sortOrder).max() ?? -1) + 1 }
        try? context.save()
        SharedStore.reloadWidgets()
        Task { await Reminders.syncAll() }
    }
}

private struct HabitListRow: View {
    let habit: Habit
    let today: Int

    var body: some View {
        let streak = habit.streak(today: today)
        HStack(spacing: 14) {
            HabitIcon(symbol: habit.symbol, color: HabitPalette.color(habit.colorIndex), size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name).font(.body.weight(.medium))
                Text(habit.schedule.summary()).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            if streak.current > 0 {
                Text("\(streak.current)\(streak.inWeeks ? "w" : "d")")
                    .font(.footnote.weight(.semibold)).monospacedDigit().foregroundStyle(.secondary)
                    .accessibilityLabel("\(streak.current) \(streak.unit) streak")
            }
        }
    }
}
