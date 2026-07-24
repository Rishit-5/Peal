//
//  BentoAlarmListView.swift
//  Peal
//

import AlarmKit
import SwiftUI

struct BentoAlarmListView: View {
    @ObservedObject var scheduler: AlarmScheduler
    let onEdit: (StoredAlarm) -> Void
    let onAdd: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if scheduler.authorizationState == .denied {
                    PermissionDeniedBanner()
                        .padding(.horizontal, 4)
                }

                if scheduler.activeAlarms.isEmpty {
                    ContentUnavailableView(
                        "No Alarms",
                        systemImage: "alarm",
                        description: Text("Tap + to add an alarm")
                    )
                    .padding(.top, 60)
                } else {
                    if let hero = heroAlarm {
                        HeroTile(scheduler: scheduler, alarm: hero) {
                            onEdit(hero)
                        }
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(otherAlarms) { alarm in
                            BentoTile(scheduler: scheduler, alarm: alarm) {
                                onEdit(alarm)
                            }
                        }
                    }

                    Button(action: onAdd) {
                        Label("Add alarm", systemImage: "plus")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }

    private var heroAlarm: StoredAlarm? {
        let enabled = scheduler.activeAlarms.filter(\.isEnabled)
        guard !enabled.isEmpty else { return scheduler.activeAlarms.first }
        return enabled.min { scheduler.nextOccurrenceDate(for: $0) < scheduler.nextOccurrenceDate(for: $1) }
    }

    private var otherAlarms: [StoredAlarm] {
        guard let hero = heroAlarm else { return scheduler.activeAlarms }
        return scheduler.activeAlarms.filter { $0.id != hero.id }
    }
}

private struct HeroTile: View {
    @ObservedObject var scheduler: AlarmScheduler
    let alarm: StoredAlarm
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(alarm.isEnabled ? "NEXT \u{00B7} \(scheduler.countdownText(for: alarm).uppercased())" : "OFF")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Image(systemName: alarm.icon.systemImage)
                        .foregroundStyle(.white.opacity(0.85))
                    Menu {
                        AlarmContextMenu(alarm: alarm, scheduler: scheduler)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Toggle("", isOn: Binding(
                        get: { alarm.isEnabled },
                        set: { scheduler.setEnabled($0, for: alarm.id) }
                    ))
                    .labelsHidden()
                    .tint(.white.opacity(0.4))
                }
                Text(scheduler.timeString(for: alarm))
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                HStack(spacing: 4) {
                    Text(scheduler.subtitle(for: alarm))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                    if isSkippedToday {
                        Text("\u{00B7} Skipped")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(alarm.colorOption.color)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .contextMenu {
            AlarmContextMenu(alarm: alarm, scheduler: scheduler)
        }
    }

    private var isSkippedToday: Bool {
        alarm.skippedOccurrenceDate.map(Calendar.current.isDateInToday) ?? false
    }
}

private struct BentoTile: View {
    @ObservedObject var scheduler: AlarmScheduler
    let alarm: StoredAlarm
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: alarm.icon.systemImage)
                        .foregroundStyle(alarm.colorOption.color)
                    Spacer()
                    Menu {
                        AlarmContextMenu(alarm: alarm, scheduler: scheduler)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                    Toggle("", isOn: Binding(
                        get: { alarm.isEnabled },
                        set: { scheduler.setEnabled($0, for: alarm.id) }
                    ))
                    .labelsHidden()
                    .scaleEffect(0.75)
                }
                Text(scheduler.timeString(for: alarm))
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(spacing: 4) {
                    Text(scheduler.subtitle(for: alarm))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if isSkippedToday {
                        Text("\u{00B7} Skipped")
                            .font(.caption2.bold())
                            .foregroundStyle(.indigo)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(alarm.colorOption.color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .opacity(alarm.isEnabled ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .contextMenu {
            AlarmContextMenu(alarm: alarm, scheduler: scheduler)
        }
    }

    private var isSkippedToday: Bool {
        alarm.skippedOccurrenceDate.map(Calendar.current.isDateInToday) ?? false
    }
}

#Preview {
    BentoAlarmListView(scheduler: .shared, onEdit: { _ in }, onAdd: {})
}
