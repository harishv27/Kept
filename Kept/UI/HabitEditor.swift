import SwiftUI
import SwiftData
import KeptCore

/// Create or edit a habit. `habit == nil` means create.
struct HabitEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Habit.sortOrder) private var all: [Habit]

    let habit: Habit?

    private enum Kind: String, CaseIterable, Identifiable {
        case daily = "Every day", days = "Days", perWeek = "Per week"
        var id: String { rawValue }
    }

    @State private var name = ""
    @State private var symbol = "checkmark"
    @State private var colorIndex = 0
    @State private var kind = Kind.daily
    @State private var days: Set<Int> = [2, 3, 4, 5, 6]
    @State private var perWeek = 3
    @State private var reminderOn = false
    @State private var reminder = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now
    @State private var denied = false
    @FocusState private var nameFocused: Bool

    private var color: Color { HabitPalette.color(colorIndex) }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && !(kind == .days && days.isEmpty) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        HabitIcon(symbol: symbol, color: color, size: 36)
                        TextField("Name", text: $name)
                            .focused($nameFocused).submitLabel(.done).textInputAutocapitalization(.sentences)
                    }
                }
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                        ForEach(HabitPalette.symbols, id: \.self) { name in
                            Button { symbol = name } label: {
                                Image(systemName: name).font(.system(size: 17))
                                    .frame(width: 34, height: 34)
                                    .foregroundStyle(symbol == name ? color : .secondary)
                                    .background(symbol == name ? color.opacity(0.16) : .clear, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(name.replacingOccurrences(of: ".fill", with: "").replacingOccurrences(of: ".", with: " "))
                            .accessibilityAddTraits(symbol == name ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Colour") {
                    HStack {
                        ForEach(HabitPalette.colors.indices, id: \.self) { index in
                            Button { colorIndex = index } label: {
                                Circle().fill(HabitPalette.colors[index]).frame(width: 28, height: 28)
                                    .overlay { if colorIndex == index { Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white) } }
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel("Colour \(index + 1)")
                            .accessibilityAddTraits(colorIndex == index ? .isSelected : [])
                        }
                    }
                }
                Section("Repeat") {
                    Picker("Repeat", selection: $kind) {
                        ForEach(Kind.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden()
                    switch kind {
                    case .daily: EmptyView()
                    case .days: weekdayPicker
                    case .perWeek: Stepper("\(perWeek) \(perWeek == 1 ? "time" : "times") a week", value: $perWeek, in: 1...7)
                    }
                }
                Section {
                    Toggle("Remind me", isOn: $reminderOn)
                    if reminderOn { DatePicker("Time", selection: $reminder, displayedComponents: .hourAndMinute) }
                } footer: {
                    if denied { Text("Notifications are turned off for Kept. Allow them in Settings to get reminders.") }
                }
            }
            .navigationTitle(habit == nil ? "New habit" : "Edit habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(!canSave) }
            }
            .onChange(of: reminderOn) { _, on in
                guard on else { return }
                Task { denied = !(await Reminders.requestAuthorization()) }
            }
            .onAppear(perform: load)
        }
        .presentationDetents([.large])
    }

    private var weekdayPicker: some View {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        let order = (0..<7).map { (Calendar.current.firstWeekday - 1 + $0) % 7 + 1 }
        return HStack {
            ForEach(order, id: \.self) { weekday in
                let on = days.contains(weekday)
                Button {
                    if on { days.remove(weekday) } else { days.insert(weekday) }
                } label: {
                    Text(symbols[weekday - 1]).font(.subheadline.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .foregroundStyle(on ? .white : .primary)
                        .background(on ? color : Color.secondary.opacity(0.15), in: Circle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(Calendar.current.weekdaySymbols[weekday - 1])
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    private func load() {
        guard let habit else { nameFocused = true; return }
        name = habit.name
        symbol = habit.symbol
        colorIndex = habit.colorIndex
        switch habit.schedule {
        case .daily: kind = .daily
        case .weekdays(let set): kind = .days; days = set
        case .timesPerWeek(let n): kind = .perWeek; perWeek = n
        }
        if let minutes = habit.reminderMinutes {
            reminderOn = true
            reminder = Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
        }
    }

    private func save() {
        let schedule: Schedule = switch kind {
        case .daily: .daily
        case .days: days.count == 7 ? .daily : .weekdays(days)
        case .perWeek: .timesPerWeek(perWeek)
        }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: reminder)
        let minutes = reminderOn ? (parts.hour ?? 8) * 60 + (parts.minute ?? 0) : nil
        let title = name.trimmingCharacters(in: .whitespaces)

        if let habit {
            habit.name = title
            habit.symbol = symbol
            habit.colorIndex = colorIndex
            habit.schedule = schedule
            habit.reminderMinutes = minutes
        } else {
            let order = (all.map(\.sortOrder).max() ?? -1) + 1
            context.insert(Habit(name: title, symbol: symbol, colorIndex: colorIndex, schedule: schedule,
                                 reminderMinutes: minutes, createdDay: Habit.today(), sortOrder: order))
        }
        try? context.save()
        SharedStore.reloadWidgets()
        Task { await Reminders.syncAll() }
        dismiss()
    }
}
