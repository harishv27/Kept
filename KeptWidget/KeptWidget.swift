import WidgetKit
import SwiftUI
import SwiftData
import AppIntents
import KeptCore

@main
struct KeptWidgetBundle: WidgetBundle {
    var body: some Widget { TodayWidget() }
}

/// What the widget needs to know about one habit. Plain values, so the timeline entry is cheap to keep around.
struct HabitSnapshot: Identifiable {
    let id: UUID
    let name: String
    let symbol: String
    let colorIndex: Int
    let done: Bool
    let streak: Int
}

struct TodayEntry: TimelineEntry {
    let date: Date
    let habits: [HabitSnapshot]

    var done: Int { habits.filter(\.done).count }
    var fraction: Double { habits.isEmpty ? 0 : Double(done) / Double(habits.count) }
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: .now, habits: [
            HabitSnapshot(id: UUID(), name: "Read", symbol: "book.fill", colorIndex: 2, done: true, streak: 6),
            HabitSnapshot(id: UUID(), name: "Run", symbol: "figure.run", colorIndex: 1, done: false, streak: 3),
            HabitSnapshot(id: UUID(), name: "Water", symbol: "drop.fill", colorIndex: 0, done: false, streak: 12),
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        // One entry now, and a refresh at midnight so a new day starts with the new day's habits.
        let midnight = Calendar.current.nextDate(after: .now, matching: DateComponents(hour: 0, minute: 1),
                                                 matchingPolicy: .nextTime) ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: [load()], policy: .after(midnight)))
    }

    private func load() -> TodayEntry {
        let context = SharedStore.makeContext()
        let today = Habit.today()
        let all = (try? context.fetch(FetchDescriptor<Habit>(predicate: #Predicate { !$0.archived },
                                                             sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        let snapshots = all.filter { $0.isOpenToday(today) }.map {
            HabitSnapshot(id: $0.id, name: $0.name, symbol: $0.symbol, colorIndex: $0.colorIndex,
                          done: $0.isDone(on: today), streak: $0.streak(today: today).current)
        }
        return TodayEntry(date: .now, habits: snapshots)
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayWidget", provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today")
        .description("See what's left today and tick habits off from the Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    var body: some View {
        switch family {
        case .systemSmall: small
        case .systemMedium: medium
        case .accessoryCircular: circular
        default: rectangular
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressRing(fraction: entry.fraction, lineWidth: 7)
                .overlay { Text("\(entry.done)/\(entry.habits.count)").font(.headline).monospacedDigit() }
                .frame(width: 64, height: 64)
            Spacer(minLength: 0)
            if entry.habits.isEmpty {
                Text("Nothing scheduled").font(.subheadline.weight(.semibold))
            } else if entry.done == entry.habits.count {
                Text("All done").font(.subheadline.weight(.semibold))
            } else {
                Text("\(entry.habits.count - entry.done) left").font(.subheadline.weight(.semibold))
                Text(entry.habits.first { !$0.done }?.name ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                ProgressRing(fraction: entry.fraction, lineWidth: 7)
                    .overlay { Text("\(entry.done)/\(entry.habits.count)").font(.subheadline.weight(.semibold)).monospacedDigit() }
                    .frame(width: 56, height: 56)
                Spacer(minLength: 0)
                Text(Date.now, format: .dateTime.weekday(.wide)).font(.caption.weight(.semibold))
                Text(Date.now, format: .dateTime.day().month(.abbreviated)).font(.caption).foregroundStyle(.secondary)
            }
            if entry.habits.isEmpty {
                Text("Nothing scheduled today").font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 6) {
                    ForEach(entry.habits.prefix(4)) { habit in
                        Button(intent: ToggleHabitIntent(habit: HabitEntity(id: habit.id, name: habit.name))) {
                            HStack(spacing: 8) {
                                Image(systemName: habit.symbol).font(.caption)
                                    .foregroundStyle(HabitPalette.color(habit.colorIndex)).frame(width: 18)
                                Text(habit.name).font(.subheadline).lineLimit(1)
                                    .strikethrough(habit.done).foregroundStyle(habit.done ? .secondary : .primary)
                                Spacer(minLength: 0)
                                Image(systemName: habit.done ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(habit.done ? HabitPalette.color(habit.colorIndex) : .secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    if entry.habits.count > 4 {
                        Text("+\(entry.habits.count - 4) more").font(.caption2).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var circular: some View {
        Gauge(value: entry.fraction) {
            Image(systemName: "checkmark")
        } currentValueLabel: {
            Text("\(entry.done)/\(entry.habits.count)")
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.habits.isEmpty ? "Nothing today" : "\(entry.done) of \(entry.habits.count) done").font(.headline)
            if let next = entry.habits.first(where: { !$0.done }) {
                Text("Next: \(next.name)").font(.caption).lineLimit(1)
            } else if !entry.habits.isEmpty {
                Text("All done").font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProgressRing: View {
    let fraction: Double
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle().stroke(Color("AccentColor").opacity(0.18), lineWidth: lineWidth)
            Circle().trim(from: 0, to: fraction)
                .stroke(Color("AccentColor"), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
