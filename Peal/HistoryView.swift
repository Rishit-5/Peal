//
//  HistoryView.swift
//  Peal
//

import SwiftUI

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var scheduler: AlarmScheduler
    let onEdit: (StoredAlarm) -> Void

    var body: some View {
        NavigationStack {
            List {
                if scheduler.historyAlarms.isEmpty {
                    ContentUnavailableView(
                        "No History",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Alarms that have fired and expired show up here")
                    )
                } else {
                    ForEach(scheduler.historyAlarms) { alarm in
                        Button {
                            onEdit(alarm)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: alarm.icon.systemImage)
                                    .foregroundStyle(alarm.colorOption.color)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(alarm.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(alarm.label)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .leading) {
                            Button {
                                Task { await scheduler.reviveAlarm(id: alarm.id) }
                                dismiss()
                            } label: {
                                Label("Revive", systemImage: "arrow.clockwise")
                            }
                            .tint(.green)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                scheduler.deleteAlarm(alarm)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
