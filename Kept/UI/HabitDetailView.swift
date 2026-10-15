import SwiftUI
import SwiftData
import Charts
import KeptCore

struct HabitDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var habit: Habit
    let today: Int

    @State private var editing = false
    @State private var confirmingDelete = false
    @State private var ticks = 0

    private var color: Color { HabitPalette.color(habit.colorIndex) }

    var body: some View {
        let streak = habit.streak(today: today)
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                HStack(spacing: 12) {
                    StatTile(value: "\(streak.current)", label: streak.inWeeks ? "Week streak" : "Day streak", tint: color)
                    StatTile(value: "\(streak.best)", label: "Best streak", tint: color)
                    StatTile(value: "\(Int((habit.rate(today: today) * 100).rounded()))%", label: "Last 30 days", tint: color)
                }
                section("Last 17 weeks", hint: "Tap a day to fix it") {
                    Heatmap(habit: habit, today: today, color: color) { day in
                        habit.toggle(day)
                        try? context.save()
                        SharedStore.reloadWidgets()
                        ticks += 1
                    }
                }
                section("Per week") { weeklyChart }
            }
            .padding(.horizontal, Theme.side)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .navigationTitle(habit.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Edit", systemImage: "pencil") { editing = true }
                    Button(habit.archived ? "Restore" : "Archive", systemImage: "archivebox") { toggleArchive() }
                    Button("Delete", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                } label: { Image(systemName: "ellipsis.circle") }
                    .accessibilityLabel("Habit options")
            }
        }
        .sheet(isPresented: $editing) { HabitEditor(habit: habit) }
        .confirmationDialog("Delete \(habit.name)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete habit and history", role: .destructive) { delete() }
        } message: { Text("This can't be undone. Archive it instead to keep the history.") }
        .sensoryFeedback(.selection, trigger: ticks)
    }

    private var header: some View {
        HStack(spacing: 14) {
            HabitIcon(symbol: habit.symbol, color: color, size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(habit.schedule.summary()).font(.headline)
                if let minutes = habit.reminderMinutes {
                    Label(Self.time(minutes), systemImage: "bell.fill").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text("No reminder").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.top, 4)
    }

    private var weeklyChart: some View {
        let counts = Stats.weeklyCounts(completed: habit.completed, today: today, weeks: 12,
                                        firstWeekday: Calendar.current.firstWeekday)
        let target = habit.schedule.weeklyTarget
        let top = max(target, counts.map(\.count).max() ?? 0) + (target < 7 ? 1 : 0)
        return Chart {
            ForEach(counts) { week in
                BarMark(x: .value("Week", Day.date(for: week.weekStart), unit: .weekOfYear),
                        y: .value("Done", week.count))
                    .foregroundStyle(week.count >= target ? color : color.opacity(0.45))
                    .cornerRadius(3)
            }
            RuleMark(y: .value("Target", target))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(.secondary)
                .annotation(position: .top, alignment: .trailing) {
                    Text("target \(target)").font(.caption2).foregroundStyle(.secondary)
                }
        }
        .chartYScale(domain: 0...top)
        .chartYAxis { AxisMarks(values: Array(Set([0, top]))) }
        .chartXAxis { AxisMarks(values: .stride(by: .weekOfYear, count: 3)) { _ in AxisValueLabel(format: .dateTime.day().month(.abbreviated)) } }
        .frame(height: 150)
        .accessibilityLabel("Completions per week for the last 12 weeks")
        .accessibilityValue(counts.map { "\($0.count)" }.joined(separator: ", "))
    }

    private func section<Content: View>(_ title: String, hint: String? = nil,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                if let hint { Text(hint).font(.caption).foregroundStyle(.tertiary) }
            }
            content().padding(16).frame(maxWidth: .infinity, alignment: .leading).card()
        }
    }

    private func toggleArchive() {
        habit.archived.toggle()
        try? context.save()
        SharedStore.reloadWidgets()
        Task { await Reminders.syncAll() }
        if habit.archived { dismiss() }
    }

    private func delete() {
        context.delete(habit)
        try? context.save()
        SharedStore.reloadWidgets()
        Task { await Reminders.syncAll() }
        dismiss()
    }

    static func time(_ minutes: Int) -> String {
        let date = Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}

private struct StatTile: View {
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title2.weight(.bold)).monospacedDigit().foregroundStyle(tint)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .card()
        .accessibilityElement(children: .combine)
    }
}

/// GitHub-style grid: one column per week, one row per weekday, newest week on the right.
private struct Heatmap: View {
    let habit: Habit
    let today: Int
    let color: Color
    let toggle: (Int) -> Void

    private let weeks = 17
    private let spacing: CGFloat = 4
    private let labelWidth: CGFloat = 14

    var body: some View {
        let calendar = Calendar.current
        let firstWeekday = calendar.firstWeekday
        let thisWeek = Day.weekStart(of: today, firstWeekday: firstWeekday)
        let completed = habit.completed
        let schedule = habit.schedule
        let total = completed.filter { $0 >= thisWeek - (weeks - 1) * 7 }.count
        let letters = calendar.veryShortStandaloneWeekdaySymbols

        GeometryReader { proxy in
            let cell = (proxy.size.width - labelWidth - spacing * CGFloat(weeks)) / CGFloat(weeks)
            HStack(alignment: .top, spacing: spacing) {
                VStack(spacing: spacing) {
                    ForEach(0..<7, id: \.self) { row in
                        Text(letters[(firstWeekday - 1 + row) % 7])
                            .font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
                            .frame(width: labelWidth, height: cell)
                    }
                }
                ForEach(0..<weeks, id: \.self) { column in
                    VStack(spacing: spacing) {
                        ForEach(0..<7, id: \.self) { row in
                            let day = thisWeek - (weeks - 1 - column) * 7 + row
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(fill(day: day, done: completed.contains(day), due: schedule.isDue(on: day)))
                                .frame(width: cell, height: cell)
                                .overlay {
                                    if day == today {
                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                            .strokeBorder(Color.primary.opacity(0.6), lineWidth: 1)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { if day <= today { toggle(day) } }
                        }
                    }
                }
            }
        }
        .aspectRatio(2.45, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Completion calendar, last 17 weeks")
        .accessibilityValue("\(total) days done")
    }

    private func fill(day: Int, done: Bool, due: Bool) -> Color {
        if day > today { return .clear }
        if done { return color }
        return Color.secondary.opacity(due ? 0.16 : 0.07)
    }
}
