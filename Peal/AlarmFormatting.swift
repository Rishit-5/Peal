//
//  AlarmFormatting.swift
//  Peal
//

import Foundation

extension AlarmScheduler {
    private static let weekdayOrder: [Locale.Weekday] = [
        .sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday
    ]

    func timeString(for alarm: StoredAlarm) -> String {
        switch alarm.recurrence {
        case .never:
            return alarm.date.formatted(date: .abbreviated, time: .shortened)
        case .weekly:
            return alarm.date.formatted(date: .omitted, time: .shortened)
        case .monthly:
            return nextOccurrenceDate(for: alarm).formatted(date: .abbreviated, time: .shortened)
        }
    }

    func recurrenceString(for alarm: StoredAlarm) -> String? {
        switch alarm.recurrence {
        case .never:
            return nil
        case .weekly(let weekdays):
            guard !weekdays.isEmpty else { return nil }
            if weekdays.count == 7 { return "Every day" }
            let ordered = Self.weekdayOrder.filter { weekdays.contains($0) }
            return ordered.map(Self.shortWeekdayName).joined(separator: ", ")
        case .monthly(let day):
            return "Monthly on \(Self.ordinal(day))"
        }
    }

    func subtitle(for alarm: StoredAlarm) -> String {
        if let recurrence = recurrenceString(for: alarm) {
            return "\(recurrence) \u{00B7} \(alarm.label)"
        }
        return alarm.label
    }

    func countdownText(for alarm: StoredAlarm) -> String {
        let interval = nextOccurrenceDate(for: alarm).timeIntervalSinceNow
        guard interval > 0 else { return "Now" }
        let totalMinutes = Int(interval / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "In \(hours)h \(minutes)m" : "In \(minutes)m"
    }

    private static func shortWeekdayName(_ day: Locale.Weekday) -> String {
        switch day {
        case .sunday: "Sun"
        case .monday: "Mon"
        case .tuesday: "Tue"
        case .wednesday: "Wed"
        case .thursday: "Thu"
        case .friday: "Fri"
        case .saturday: "Sat"
        @unknown default: ""
        }
    }

    private static func ordinal(_ day: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: day)) ?? "\(day)"
    }
}
