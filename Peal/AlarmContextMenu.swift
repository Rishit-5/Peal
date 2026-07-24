//
//  AlarmContextMenu.swift
//  Peal
//

import SwiftUI

@ViewBuilder
func AlarmContextMenu(alarm: StoredAlarm, scheduler: AlarmScheduler) -> some View {
    if alarm.recurrence.isRecurring, alarm.isEnabled {
        let isSkipped = alarm.skippedOccurrenceDate.map(Calendar.current.isDateInToday) ?? false
        Button {
            scheduler.toggleSkipNextOccurrence(for: alarm.id)
        } label: {
            Label(isSkipped ? "Cancel Skip" : "Skip Next", systemImage: "moon.zzz")
        }
    }
    Button(role: .destructive) {
        scheduler.deleteAlarm(alarm)
    } label: {
        Label("Delete", systemImage: "trash")
    }
}
