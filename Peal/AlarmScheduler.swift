//
//  AlarmScheduler.swift
//  Peal
//

import AlarmKit
import Combine
import SwiftUI
import UserNotifications

struct EmptyAlarmMetadata: AlarmMetadata {}

enum AlarmRecurrence: Codable, Equatable {
    case never
    case weekly(Set<Locale.Weekday>)
    case monthly(day: Int)

    var isRecurring: Bool {
        if case .never = self { return false }
        return true
    }
}

struct MonthlyOccurrence: Codable, Equatable {
    let alarmID: UUID
    let date: Date
}

struct StoredAlarm: Identifiable, Codable, Equatable {
    let id: UUID
    var date: Date
    var recurrence: AlarmRecurrence
    var label: String
    var isEnabled: Bool
    var skippedOccurrenceDate: Date? = nil
    var scheduledMonthlyOccurrences: [MonthlyOccurrence] = []
    var icon: AlarmIconOption = .alarm
    var colorOption: AlarmColorOption = .orange
    /// True only for a one-time alarm whose single occurrence has fired and
    /// passed — distinct from `isEnabled == false`, which just means paused.
    var hasExpired: Bool = false
}

@MainActor
final class AlarmScheduler: ObservableObject {
    static let shared = AlarmScheduler()

    @Published private(set) var storedAlarms: [StoredAlarm] = []
    @Published private(set) var authorizationState: AlarmManager.AuthorizationState

    var activeAlarms: [StoredAlarm] { storedAlarms.filter { !$0.hasExpired } }
    var historyAlarms: [StoredAlarm] { storedAlarms.filter(\.hasExpired) }

    private let manager = AlarmManager.shared
    private var updatesTask: Task<Void, Never>?

    private static let storedAlarmsDefaultsKey = "com.alarmplus.storedAlarms"
    private static let snoozeDuration: TimeInterval = 9 * 60

    /// How many future occurrences of a monthly alarm stay pre-scheduled at once.
    /// Since AlarmKit can't express "monthly" natively, each occurrence is its own
    /// one-time alarm — this buffer is what keeps the alarm firing even if the app
    /// isn't reopened for a while between firings.
    private static let monthlyBufferSize = 6
    private static let bufferReminderLeadDays = 5

    private init() {
        authorizationState = manager.authorizationState
        storedAlarms = Self.loadStoredAlarms()

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        if let current = try? manager.alarms {
            reconcile(activeAlarms: current)
        }

        updatesTask = Task { [weak self] in
            guard let self else { return }
            for await activeAlarms in manager.alarmUpdates {
                self.reconcile(activeAlarms: activeAlarms)
            }
        }
    }

    func requestAuthorizationIfNeeded() async {
        guard authorizationState == .notDetermined else { return }
        do {
            authorizationState = try await manager.requestAuthorization()
        } catch {
            print("AlarmKit authorization failed: \(error)")
        }
    }

    func createAlarm(
        date: Date,
        recurrence: AlarmRecurrence,
        label: String,
        icon: AlarmIconOption = .alarm,
        colorOption: AlarmColorOption = .orange
    ) async {
        await requestAuthorizationIfNeeded()
        guard authorizationState == .authorized else { return }

        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        var stored = StoredAlarm(
            id: UUID(),
            date: date,
            recurrence: recurrence,
            label: trimmed.isEmpty ? "Alarm" : trimmed,
            isEnabled: true,
            icon: icon,
            colorOption: colorOption
        )

        do {
            stored = try await scheduleWithSystem(stored)
            storedAlarms.append(stored)
            persist()
            syncBufferReminder(for: stored)
        } catch {
            print("Failed to schedule alarm: \(error)")
        }
    }

    func updateAlarm(
        id: UUID,
        date: Date,
        recurrence: AlarmRecurrence,
        label: String,
        icon: AlarmIconOption,
        colorOption: AlarmColorOption
    ) async {
        guard let index = storedAlarms.firstIndex(where: { $0.id == id }) else { return }
        await requestAuthorizationIfNeeded()

        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        var updated = storedAlarms[index]
        cancelAllSystemAlarms(for: updated)
        updated.date = date
        updated.recurrence = recurrence
        updated.label = trimmed.isEmpty ? "Alarm" : trimmed
        updated.skippedOccurrenceDate = nil
        updated.scheduledMonthlyOccurrences = []
        updated.icon = icon
        updated.colorOption = colorOption
        // Saving from the editor always (re)activates the alarm — this is also
        // how reviving an expired one-time alarm from History works.
        updated.isEnabled = true
        updated.hasExpired = false

        if authorizationState == .authorized {
            do {
                updated = try await scheduleWithSystem(updated)
            } catch {
                print("Failed to reschedule alarm: \(error)")
                updated.isEnabled = false
            }
        }

        storedAlarms[index] = updated
        persist()
        syncBufferReminder(for: updated)
    }

    /// Quick one-tap revive for an expired one-time alarm from History: reuses its
    /// original time-of-day, moved to the next time that time-of-day still occurs.
    func reviveAlarm(id: UUID) async {
        guard let stored = storedAlarms.first(where: { $0.id == id }) else { return }
        guard case .never = stored.recurrence else { return }

        let components = Calendar.current.dateComponents([.hour, .minute], from: stored.date)
        var newDate = Calendar.current.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: 0,
            of: Date()
        ) ?? Date()
        if newDate <= Date() {
            newDate = Calendar.current.date(byAdding: .day, value: 1, to: newDate) ?? newDate
        }

        await updateAlarm(
            id: id,
            date: newDate,
            recurrence: stored.recurrence,
            label: stored.label,
            icon: stored.icon,
            colorOption: stored.colorOption
        )
    }

    func deleteAlarm(_ alarm: StoredAlarm) {
        cancelAllSystemAlarms(for: alarm)
        storedAlarms.removeAll { $0.id == alarm.id }
        persist()
        cancelBufferReminder(for: alarm.id)
    }

    func setEnabled(_ enabled: Bool, for id: UUID) {
        guard let index = storedAlarms.firstIndex(where: { $0.id == id }) else { return }

        if enabled {
            var stored = storedAlarms[index]
            Task { [weak self] in
                guard let self else { return }
                do {
                    stored = try await self.scheduleWithSystem(stored)
                    stored.isEnabled = true
                    if let idx = self.storedAlarms.firstIndex(where: { $0.id == id }) {
                        self.storedAlarms[idx] = stored
                        self.persist()
                        self.syncBufferReminder(for: stored)
                    }
                } catch {
                    print("Failed to enable alarm: \(error)")
                }
            }
        } else {
            cancelAllSystemAlarms(for: storedAlarms[index])
            storedAlarms[index].isEnabled = false
            storedAlarms[index].scheduledMonthlyOccurrences = []
            persist()
            cancelBufferReminder(for: id)
        }
    }

    /// Skips just the next scheduled occurrence of a recurring alarm without
    /// touching its recurrence rule — the alarm resumes normally afterward.
    func toggleSkipNextOccurrence(for id: UUID) {
        guard let index = storedAlarms.firstIndex(where: { $0.id == id }) else { return }
        guard storedAlarms[index].recurrence.isRecurring else { return }

        storedAlarms[index].skippedOccurrenceDate = storedAlarms[index].skippedOccurrenceDate == nil ? Date() : nil
        var stored = storedAlarms[index]
        persist()

        guard stored.isEnabled else { return }
        Task { [weak self] in
            guard let self else { return }
            stored = (try? await self.scheduleWithSystem(stored)) ?? stored
            if let idx = self.storedAlarms.firstIndex(where: { $0.id == id }) {
                self.storedAlarms[idx] = stored
                self.persist()
                self.syncBufferReminder(for: stored)
            }
        }
    }

    /// The date AlarmKit is (or will be) scheduled to fire next for this alarm.
    func nextOccurrenceDate(for alarm: StoredAlarm) -> Date {
        switch alarm.recurrence {
        case .never:
            return alarm.date
        case .weekly(let weekdays):
            let effective = effectiveWeekdays(weekdays, skippedOccurrenceDate: alarm.skippedOccurrenceDate)
            guard !effective.isEmpty else { return alarm.date }
            let components = Calendar.current.dateComponents([.hour, .minute], from: alarm.date)
            return Self.nextWeeklyDate(
                weekdays: effective,
                hour: components.hour ?? 0,
                minute: components.minute ?? 0,
                notBefore: notBeforeDate(for: alarm)
            )
        case .monthly(let day):
            if let soonest = alarm.scheduledMonthlyOccurrences.map(\.date).min() {
                return soonest
            }
            let components = Calendar.current.dateComponents([.hour, .minute], from: alarm.date)
            return Self.nextMonthlyDate(
                day: day,
                hour: components.hour ?? 0,
                minute: components.minute ?? 0,
                notBefore: notBeforeDate(for: alarm)
            )
        }
    }

    private func notBeforeDate(for alarm: StoredAlarm) -> Date {
        let skipActive = alarm.skippedOccurrenceDate.map(Calendar.current.isDateInToday) ?? false
        guard skipActive else { return Date() }
        return Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }

    private func cancelAllSystemAlarms(for stored: StoredAlarm) {
        switch stored.recurrence {
        case .never, .weekly:
            try? manager.cancel(id: stored.id)
        case .monthly:
            for occurrence in stored.scheduledMonthlyOccurrences {
                try? manager.cancel(id: occurrence.alarmID)
            }
        }
    }

    private func scheduleWithSystem(_ stored: StoredAlarm) async throws -> StoredAlarm {
        switch stored.recurrence {
        case .never:
            try await scheduleFixedAlarm(id: stored.id, date: stored.date, label: stored.label)
            return stored

        case .weekly(let weekdays):
            let effective = effectiveWeekdays(weekdays, skippedOccurrenceDate: stored.skippedOccurrenceDate)
            guard !effective.isEmpty else {
                // Every day this alarm could fire is skipped right now (e.g. a
                // once-a-week alarm skipped for today) — nothing to schedule
                // until the skip clears on its own tomorrow.
                try? manager.cancel(id: stored.id)
                return stored
            }
            let components = Calendar.current.dateComponents([.hour, .minute], from: stored.date)
            let time = Alarm.Schedule.Relative.Time(hour: components.hour ?? 0, minute: components.minute ?? 0)
            let configuration = makeConfiguration(
                label: stored.label,
                schedule: .relative(.init(time: time, repeats: .weekly(Array(effective))))
            )
            _ = try await manager.schedule(id: stored.id, configuration: configuration)
            return stored

        case .monthly:
            return try await scheduleMonthlyOccurrences(stored)
        }
    }

    /// AlarmKit has no monthly recurrence primitive, so a monthly alarm is a
    /// buffer of several individually-scheduled one-time alarms. Expired ones
    /// are dropped and the buffer is topped back up to `monthlyBufferSize`.
    private func scheduleMonthlyOccurrences(_ stored: StoredAlarm) async throws -> StoredAlarm {
        guard case .monthly(let day) = stored.recurrence else { return stored }
        var updated = stored

        let skipToday = updated.skippedOccurrenceDate.map(Calendar.current.isDateInToday) ?? false
        var kept: [MonthlyOccurrence] = []
        for occurrence in updated.scheduledMonthlyOccurrences {
            if occurrence.date < Date() {
                continue
            }
            if skipToday, Calendar.current.isDateInToday(occurrence.date) {
                try? manager.cancel(id: occurrence.alarmID)
                continue
            }
            kept.append(occurrence)
        }
        updated.scheduledMonthlyOccurrences = kept

        let components = Calendar.current.dateComponents([.hour, .minute], from: updated.date)
        var notBefore = kept.map(\.date).max() ?? notBeforeDate(for: updated)
        while updated.scheduledMonthlyOccurrences.count < Self.monthlyBufferSize {
            let nextDate = Self.nextMonthlyDate(
                day: day,
                hour: components.hour ?? 0,
                minute: components.minute ?? 0,
                notBefore: notBefore
            )
            let alarmID = UUID()
            try await scheduleFixedAlarm(id: alarmID, date: nextDate, label: updated.label)
            updated.scheduledMonthlyOccurrences.append(MonthlyOccurrence(alarmID: alarmID, date: nextDate))
            notBefore = nextDate
        }

        return updated
    }

    private func scheduleFixedAlarm(id: UUID, date: Date, label: String) async throws {
        let configuration = makeConfiguration(label: label, schedule: .fixed(date))
        _ = try await manager.schedule(id: id, configuration: configuration)
    }

    private func makeConfiguration(label: String, schedule: Alarm.Schedule) -> AlarmManager.AlarmConfiguration<EmptyAlarmMetadata> {
        let alertContent = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: label),
            secondaryButton: AlarmButton(
                text: LocalizedStringResource(stringLiteral: "Snooze"),
                textColor: .white,
                systemImageName: "zzz"
            ),
            secondaryButtonBehavior: .countdown
        )
        let countdown = AlarmPresentation.Countdown(
            title: LocalizedStringResource(stringLiteral: "Snoozing")
        )
        let presentation = AlarmPresentation(alert: alertContent, countdown: countdown)
        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: EmptyAlarmMetadata(),
            tintColor: Color.accentColor
        )
        return AlarmManager.AlarmConfiguration(
            countdownDuration: .init(preAlert: nil, postAlert: Self.snoozeDuration),
            schedule: schedule,
            attributes: attributes
        )
    }

    private func effectiveWeekdays(_ weekdays: Set<Locale.Weekday>, skippedOccurrenceDate: Date?) -> Set<Locale.Weekday> {
        guard
            let skipped = skippedOccurrenceDate,
            Calendar.current.isDateInToday(skipped),
            let today = Self.weekday(for: Date())
        else { return weekdays }
        return weekdays.subtracting([today])
    }

    private static func weekday(for date: Date) -> Locale.Weekday? {
        switch Calendar.current.component(.weekday, from: date) {
        case 1: .sunday
        case 2: .monday
        case 3: .tuesday
        case 4: .wednesday
        case 5: .thursday
        case 6: .friday
        case 7: .saturday
        default: nil
        }
    }

    /// Earliest date strictly after `notBefore` that falls on one of `weekdays` at the given time.
    private static func nextWeeklyDate(weekdays: Set<Locale.Weekday>, hour: Int, minute: Int, notBefore: Date) -> Date {
        guard !weekdays.isEmpty else { return notBefore }
        let calendar = Calendar.current
        var dayOffset = 0

        while dayOffset < 14 {
            guard let candidateDay = calendar.date(
                byAdding: .day,
                value: dayOffset,
                to: calendar.startOfDay(for: notBefore)
            ) else { break }

            defer { dayOffset += 1 }
            guard let candidateWeekday = weekday(for: candidateDay), weekdays.contains(candidateWeekday) else {
                continue
            }

            var components = calendar.dateComponents([.year, .month, .day], from: candidateDay)
            components.hour = hour
            components.minute = minute
            if let candidate = calendar.date(from: components), candidate > notBefore {
                return candidate
            }
        }
        return notBefore
    }

    /// Earliest date strictly after `notBefore` that falls on `day` of some month
    /// at the given time, clamping to a month's last day when it's shorter than `day`.
    private static func nextMonthlyDate(day: Int, hour: Int, minute: Int, notBefore: Date) -> Date {
        let calendar = Calendar.current
        var monthOffset = 0

        while monthOffset < 24 {
            guard let monthStart = calendar.date(
                byAdding: .month,
                value: monthOffset,
                to: calendar.startOfDay(for: notBefore)
            ) else { break }

            let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 28
            var components = calendar.dateComponents([.year, .month], from: monthStart)
            components.day = min(day, daysInMonth)
            components.hour = hour
            components.minute = minute

            if let candidate = calendar.date(from: components), candidate > notBefore {
                return candidate
            }
            monthOffset += 1
        }
        return notBefore
    }

    /// Reschedules a monthly alarm's local "come back and refresh" notification to
    /// fire a few days before its farthest buffered occurrence — the one guaranteed,
    /// OS-delivered signal that survives even if the app never runs in the background.
    private func syncBufferReminder(for stored: StoredAlarm) {
        guard
            case .monthly = stored.recurrence,
            stored.isEnabled,
            let farthest = stored.scheduledMonthlyOccurrences.map(\.date).max()
        else {
            cancelBufferReminder(for: stored.id)
            return
        }

        var reminderDate = Calendar.current.date(
            byAdding: .day,
            value: -Self.bufferReminderLeadDays,
            to: farthest
        ) ?? farthest
        if reminderDate <= Date() {
            reminderDate = Date().addingTimeInterval(60)
        }

        let content = UNMutableNotificationContent()
        content.title = "Check your monthly alarm"
        content.body = "\"\(stored.label)\" hasn't been refreshed in a while — open Peal to keep it scheduled."
        content.sound = .default

        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.reminderIdentifier(for: stored.id),
            content: content,
            trigger: trigger
        )

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.reminderIdentifier(for: stored.id)])
        center.add(request)
    }

    private func cancelBufferReminder(for id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Self.reminderIdentifier(for: id)]
        )
    }

    private static func reminderIdentifier(for id: UUID) -> String {
        "com.alarmplus.bufferReminder.\(id.uuidString)"
    }

    /// One-time alarms disappear from the system once they fire; flip their
    /// local switch off so the list reflects that without deleting them.
    /// Monthly alarms stay enabled and get their buffer topped back up instead.
    private func reconcile(activeAlarms: [Alarm]) {
        let activeIDs = Set(activeAlarms.map(\.id))
        var changed = false
        var toReschedule: [StoredAlarm] = []

        for index in storedAlarms.indices {
            let stored = storedAlarms[index]

            switch stored.recurrence {
            case .never:
                if stored.isEnabled, stored.date < Date(), !activeIDs.contains(stored.id) {
                    storedAlarms[index].isEnabled = false
                    storedAlarms[index].hasExpired = true
                    changed = true
                }
            case .monthly:
                if stored.isEnabled {
                    let hasFiredOccurrence = stored.scheduledMonthlyOccurrences.contains { !activeIDs.contains($0.alarmID) }
                    let bufferLow = stored.scheduledMonthlyOccurrences.count < Self.monthlyBufferSize
                    if hasFiredOccurrence || bufferLow {
                        toReschedule.append(stored)
                    }
                }
            case .weekly:
                break
            }

            if let skipped = stored.skippedOccurrenceDate, !Calendar.current.isDateInToday(skipped) {
                storedAlarms[index].skippedOccurrenceDate = nil
                changed = true
                if storedAlarms[index].isEnabled, case .weekly = storedAlarms[index].recurrence {
                    toReschedule.append(storedAlarms[index])
                }
            }
        }

        if changed { persist() }

        for stored in toReschedule {
            Task { [weak self] in
                guard let self else { return }
                guard let updated = try? await self.scheduleWithSystem(stored) else { return }
                if let idx = self.storedAlarms.firstIndex(where: { $0.id == stored.id }) {
                    self.storedAlarms[idx] = updated
                    self.persist()
                    self.syncBufferReminder(for: updated)
                }
            }
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(storedAlarms) else { return }
        UserDefaults.standard.set(data, forKey: Self.storedAlarmsDefaultsKey)
    }

    private static func loadStoredAlarms() -> [StoredAlarm] {
        guard
            let data = UserDefaults.standard.data(forKey: storedAlarmsDefaultsKey),
            let decoded = try? JSONDecoder().decode([StoredAlarm].self, from: data)
        else { return [] }
        return decoded
    }
}
