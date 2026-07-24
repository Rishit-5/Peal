//
//  NewAlarmView.swift
//  Peal
//

import SwiftUI

private enum RecurrenceMode: String, CaseIterable {
    case never = "Never"
    case weekly = "Weekly"
    case monthly = "Monthly"
}

struct NewAlarmView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var scheduler = AlarmScheduler.shared

    private let existingAlarm: StoredAlarm?

    @State private var selectedDate: Date
    @State private var recurrenceMode: RecurrenceMode
    @State private var selectedWeekdays: Set<Locale.Weekday>
    @State private var monthDay: Int
    @State private var label: String
    @State private var selectedIcon: AlarmIconOption
    @State private var selectedColor: AlarmColorOption

    private static let weekdayOrder: [Locale.Weekday] = [
        .sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday
    ]
    private static let everyDaySet: Set<Locale.Weekday> = Set(weekdayOrder)
    private static let weekdaysSet: Set<Locale.Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    private static let weekendSet: Set<Locale.Weekday> = [.saturday, .sunday]

    init(existingAlarm: StoredAlarm? = nil) {
        self.existingAlarm = existingAlarm
        _selectedDate = State(initialValue: Self.initialPickerDate(for: existingAlarm))

        switch existingAlarm?.recurrence ?? .never {
        case .never:
            _recurrenceMode = State(initialValue: .never)
            _selectedWeekdays = State(initialValue: [])
            _monthDay = State(initialValue: Calendar.current.component(.day, from: Date()))
        case .weekly(let weekdays):
            _recurrenceMode = State(initialValue: .weekly)
            _selectedWeekdays = State(initialValue: weekdays)
            _monthDay = State(initialValue: Calendar.current.component(.day, from: Date()))
        case .monthly(let day):
            _recurrenceMode = State(initialValue: .monthly)
            _selectedWeekdays = State(initialValue: [])
            _monthDay = State(initialValue: day)
        }

        _label = State(initialValue: existingAlarm?.label ?? "")
        _selectedIcon = State(initialValue: existingAlarm?.icon ?? .alarm)
        _selectedColor = State(initialValue: existingAlarm?.colorOption ?? .orange)
    }

    var body: some View {
        NavigationStack {
            Form {
                if recurrenceMode == .never {
                    DatePicker(
                        "Date & Time",
                        selection: $selectedDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                } else {
                    DatePicker(
                        "Time",
                        selection: $selectedDate,
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                }

                Section("Repeat") {
                    Picker("Repeat", selection: $recurrenceMode) {
                        ForEach(RecurrenceMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    switch recurrenceMode {
                    case .never:
                        EmptyView()
                    case .weekly:
                        HStack {
                            Spacer()
                            ForEach(Self.weekdayOrder, id: \.self) { day in
                                weekdayButton(day)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)

                        HStack(spacing: 8) {
                            quickSelectButton("Every Day", set: Self.everyDaySet)
                            quickSelectButton("Weekdays", set: Self.weekdaysSet)
                            quickSelectButton("Weekends", set: Self.weekendSet)
                        }
                    case .monthly:
                        Picker("Day of the month", selection: $monthDay) {
                            ForEach(1...31, id: \.self) { day in
                                Text("\(day)").tag(day)
                            }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()
                        .frame(height: 120)
                        if monthDay > 28 {
                            Text("Shorter months use their last day instead")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                TextField("Label", text: $label)

                Section("Appearance") {
                    HStack(spacing: 10) {
                        ForEach(AlarmColorOption.allCases) { option in
                            colorSwatch(option)
                        }
                    }
                    .padding(.vertical, 4)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                        ForEach(AlarmIconOption.allCases) { option in
                            iconButton(option)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(existingAlarm == nil ? "New Alarm" : "Edit Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
    }

    private func weekdayButton(_ day: Locale.Weekday) -> some View {
        let isSelected = selectedWeekdays.contains(day)
        return Button {
            if isSelected {
                selectedWeekdays.remove(day)
            } else {
                selectedWeekdays.insert(day)
            }
        } label: {
            Text(Self.shortLabel(for: day))
                .font(.subheadline.bold())
                .frame(width: 32, height: 32)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func quickSelectButton(_ title: String, set: Set<Locale.Weekday>) -> some View {
        Button(title) {
            selectedWeekdays = set
        }
        .font(.caption)
        .buttonStyle(.bordered)
        .tint(selectedWeekdays == set ? Color.accentColor : Color.secondary)
    }

    private func colorSwatch(_ option: AlarmColorOption) -> some View {
        Button {
            selectedColor = option
        } label: {
            Circle()
                .fill(option.color)
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .stroke(Color.primary, lineWidth: selectedColor == option ? 2 : 0)
                        .padding(-3)
                )
        }
        .buttonStyle(.plain)
    }

    private func iconButton(_ option: AlarmIconOption) -> some View {
        let isSelected = selectedIcon == option
        return Button {
            selectedIcon = option
        } label: {
            Image(systemName: option.systemImage)
                .font(.system(size: 16))
                .foregroundStyle(isSelected ? Color.white : selectedColor.color)
                .frame(width: 36, height: 36)
                .background(isSelected ? selectedColor.color : selectedColor.color.opacity(0.15))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private static func shortLabel(for day: Locale.Weekday) -> String {
        switch day {
        case .sunday: "S"
        case .monday: "M"
        case .tuesday: "T"
        case .wednesday: "W"
        case .thursday: "T"
        case .friday: "F"
        case .saturday: "S"
        @unknown default: "?"
        }
    }

    /// For a one-time alarm, keep its stored date. For a recurring alarm only the
    /// time-of-day is meaningful, so anchor the picker to today (or tomorrow if
    /// that time has already passed) rather than the alarm's original creation date.
    private static func initialPickerDate(for alarm: StoredAlarm?) -> Date {
        guard let alarm else { return Date() }
        guard alarm.recurrence.isRecurring else {
            return max(alarm.date, Date())
        }

        let components = Calendar.current.dateComponents([.hour, .minute], from: alarm.date)
        var merged = Calendar.current.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: 0,
            of: Date()
        ) ?? Date()
        if merged < Date() {
            merged = Calendar.current.date(byAdding: .day, value: 1, to: merged) ?? merged
        }
        return merged
    }

    private func save() {
        let recurrence: AlarmRecurrence
        switch recurrenceMode {
        case .never: recurrence = .never
        case .weekly: recurrence = .weekly(selectedWeekdays)
        case .monthly: recurrence = .monthly(day: monthDay)
        }

        Task {
            if let existingAlarm {
                await scheduler.updateAlarm(
                    id: existingAlarm.id,
                    date: selectedDate,
                    recurrence: recurrence,
                    label: label,
                    icon: selectedIcon,
                    colorOption: selectedColor
                )
            } else {
                await scheduler.createAlarm(
                    date: selectedDate,
                    recurrence: recurrence,
                    label: label,
                    icon: selectedIcon,
                    colorOption: selectedColor
                )
            }
            dismiss()
        }
    }
}

#Preview {
    NewAlarmView()
}
