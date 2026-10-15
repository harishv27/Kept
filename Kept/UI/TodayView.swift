import SwiftUI
import SwiftData
import KeptCore

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(filter: #Predicate<Habit> { !$0.archived }, sort: \Habit.sortOrder) private var habits: [Habit]

    @State private var today = Habit.today()
    @State private var showingNew = false
    @State private var ticks = 0

    private var open: [Habit] { habits.filter { $0.isOpenToday(today) } }
    private var rest: [Habit] { habits.filter { !$0.isOpenToday(today) } }
    private var doneCount: Int { open.filter { $0.isDone(on: today) }.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                if habits.isEmpty {
                    EmptyToday { showingNew = true }
                } else {
                    VStack(alignment: .leading, spacing: 22) {
                        if !open.isEmpty { Summary(done: doneCount, total: open.count, date: Date.now.longDay) }
                        if !open.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(open) { habit in
                                    row(habit)
                                    if habit.id != open.last?.id { Divider().padding(.leading, 70) }
                                }
                            }
                            .card()
                        }
                        if !rest.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(open.isEmpty ? "Nothing scheduled today" : "Not today")
                                    .font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                                    .padding(.horizontal, 4)
                                VStack(spacing: 0) {
                                    ForEach(rest) { habit in
                                        row(habit)
                                        if habit.id != rest.last?.id { Divider().padding(.leading, 70) }
                                    }
                                }
                                .card()
                                .opacity(0.75)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.side)
                    .padding(.bottom, 24)
                }
            }
            .background(Theme.background)
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingNew = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("New habit")
                }
            }
            .navigationDestination(for: Habit.self) { HabitDetailView(habit: $0, today: today) }
            .sheet(isPresented: $showingNew) { HabitEditor(habit: nil) }
            .sensoryFeedback(.success, trigger: ticks)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refreshDay() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in refreshDay() }
        }
    }

    private func row(_ habit: Habit) -> some View {
        HabitRow(habit: habit, today: today) {
            withAnimation(.snappy(duration: 0.2)) { _ = habit.toggle(today) }
            try? context.save()
            SharedStore.reloadWidgets()
            if habit.isDone(on: today) { ticks += 1 }
        }
    }

    private func refreshDay() {
        today = Habit.today()
    }
}

private struct Summary: View {
    let done: Int
    let total: Int
    let date: String

    private var fraction: Double { total == 0 ? 0 : Double(done) / Double(total) }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color.accentColor.opacity(0.15), lineWidth: 8)
                Circle().trim(from: 0, to: fraction)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.snappy, value: fraction)
                Text("\(Int((fraction * 100).rounded()))%").font(.caption.weight(.semibold)).monospacedDigit()
            }
            .frame(width: 60, height: 60)
            VStack(alignment: .leading, spacing: 3) {
                Text(done == total ? "All done for today" : "\(done) of \(total) done")
                    .font(.title3.weight(.semibold))
                Text(date).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .padding(.top, 4)
    }
}

struct HabitRow: View {
    let habit: Habit
    let today: Int
    let toggle: () -> Void

    var body: some View {
        let color = HabitPalette.color(habit.colorIndex)
        HStack(spacing: 4) {
            NavigationLink(value: habit) {
                HStack(spacing: 14) {
                    HabitIcon(symbol: habit.symbol, color: color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(habit.name).font(.body.weight(.medium)).foregroundStyle(.primary)
                        subtitle
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            CheckButton(done: habit.isDone(on: today), color: color, label: habit.name, action: toggle)
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .padding(.vertical, 8)
    }

    @ViewBuilder private var subtitle: some View {
        if let week = habit.weekProgress(today: today) {
            Text("\(week.done) of \(week.target) this week").font(.footnote).foregroundStyle(.secondary)
        } else {
            let streak = habit.streak(today: today)
            if streak.current > 0 {
                Label {
                    Text("\(streak.current) \(streak.unit)")
                } icon: {
                    Image(systemName: "flame.fill").foregroundStyle(.orange)
                }
                .font(.footnote).foregroundStyle(.secondary)
            } else {
                Text(habit.schedule.summary()).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

private struct EmptyToday: View {
    let add: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle").font(.system(size: 44)).foregroundStyle(Color.accentColor)
            Text("Start with one habit").font(.title3.weight(.semibold))
            Text("Small and daily beats big and rare. Pick something you can do in two minutes.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Add a habit", action: add).buttonStyle(.borderedProminent).padding(.top, 4)
        }
        .padding(.horizontal, 40)
        .padding(.top, 120)
        .frame(maxWidth: .infinity)
    }
}
