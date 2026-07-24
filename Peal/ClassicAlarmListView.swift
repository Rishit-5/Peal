//
//  ClassicAlarmListView.swift
//  Peal
//

import AlarmKit
import SwiftUI

struct ClassicAlarmListView: View {
    @ObservedObject var scheduler: AlarmScheduler
    let onEdit: (StoredAlarm) -> Void

    var body: some View {
        List {
            if scheduler.authorizationState == .denied {
                Section {
                    PermissionDeniedBanner()
                }
            }

            if scheduler.activeAlarms.isEmpty {
                ContentUnavailableView(
                    "No Alarms",
                    systemImage: "alarm",
                    description: Text("Tap + to add an alarm")
                )
            } else {
                ForEach(scheduler.activeAlarms) { alarm in
                    AlarmRow(alarm: alarm) {
                        onEdit(alarm)
                    }
                    .environmentObject(scheduler)
                    .swipeActions(edge: .leading) {
                        if alarm.recurrence.isRecurring, alarm.isEnabled {
                            let isSkipped = alarm.skippedOccurrenceDate.map(Calendar.current.isDateInToday) ?? false
                            Button {
                                scheduler.toggleSkipNextOccurrence(for: alarm.id)
                            } label: {
                                Label(isSkipped ? "Cancel Skip" : "Skip Next", systemImage: "moon.zzz")
                            }
                            .tint(.indigo)
                        }
                    }
                }
                .onDelete(perform: deleteAlarms)
            }
        }
    }

    private func deleteAlarms(at offsets: IndexSet) {
        for index in offsets {
            scheduler.deleteAlarm(scheduler.activeAlarms[index])
        }
    }
}

private struct AlarmRow: View {
    @EnvironmentObject private var scheduler: AlarmScheduler
    let alarm: StoredAlarm
    let onTap: () -> Void

    var body: some View {
        HStack {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(scheduler.timeString(for: alarm))
                        .font(.largeTitle)
                    HStack(spacing: 6) {
                        if let recurrenceString = scheduler.recurrenceString(for: alarm) {
                            Text(recurrenceString)
                        }
                        Text(alarm.label)
                        if isSkippedToday {
                            Label("Skipped", systemImage: "moon.zzz")
                                .font(.caption)
                                .foregroundStyle(.indigo)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .opacity(alarm.isEnabled ? 1 : 0.4)

            Spacer()

            Toggle("", isOn: Binding(
                get: { alarm.isEnabled },
                set: { scheduler.setEnabled($0, for: alarm.id) }
            ))
            .labelsHidden()
        }
    }

    private var isSkippedToday: Bool {
        alarm.skippedOccurrenceDate.map(Calendar.current.isDateInToday) ?? false
    }
}

#Preview {
    ClassicAlarmListView(scheduler: .shared, onEdit: { _ in })
}
