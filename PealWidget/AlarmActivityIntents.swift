//
//  AlarmActivityIntents.swift
//  PealWidget
//

import AlarmKit
import AppIntents

/// Invoked directly by the custom Live Activity's own Snooze button, rather than
/// relying on AlarmKit's automatic secondary-button wiring — this way the button
/// works regardless of whether that wiring extends to fully custom Live Activity UI.
struct AlarmSnoozeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Snooze Alarm"

    @Parameter(title: "Alarm ID")
    var alarmID: String

    init() {}

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    func perform() async throws -> some IntentResult {
        if let uuid = UUID(uuidString: alarmID) {
            try? AlarmManager.shared.countdown(id: uuid)
        }
        return .result()
    }
}

struct AlarmStopIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Alarm"

    @Parameter(title: "Alarm ID")
    var alarmID: String

    init() {}

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    func perform() async throws -> some IntentResult {
        if let uuid = UUID(uuidString: alarmID) {
            try? AlarmManager.shared.stop(id: uuid)
        }
        return .result()
    }
}
