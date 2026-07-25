//
//  PealAlarmLiveActivity.swift
//  PealWidget
//

import ActivityKit
import AlarmKit
import PealShared
import SwiftUI
import WidgetKit

struct PealAlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<PealAlarmActivityMetadata>.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(context.attributes.tintColor)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    IconBadge(context: context)
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    StatusGlyph(context: context)
                        .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenter(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedActions(context: context)
                        .padding(.top, 2)
                }
            } compactLeading: {
                Image(systemName: context.attributes.metadata?.iconSystemName ?? "alarm")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(context.attributes.tintColor)
            } compactTrailing: {
                CompactTrailingLabel(context: context)
            } minimal: {
                Image(systemName: context.attributes.metadata?.iconSystemName ?? "alarm")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(context.attributes.tintColor)
            }
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<AlarmAttributes<PealAlarmActivityMetadata>>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(.white.opacity(0.2))
                    Image(systemName: context.attributes.metadata?.iconSystemName ?? "alarm")
                        .foregroundStyle(.white)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 0) {
                    Text(headline)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.65))
                    Text(context.attributes.presentation.alert.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                }
            }

            modeContent
                .foregroundStyle(.white)

            if case .alert = context.state.mode, let secondary = context.attributes.presentation.alert.secondaryButton {
                HStack(spacing: 8) {
                    Button(intent: AlarmSnoozeIntent(alarmID: context.state.alarmID.uuidString)) {
                        Label {
                            Text(secondary.text)
                        } icon: {
                            Image(systemName: secondary.systemImageName)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .tint(.white.opacity(0.22))

                    Button(intent: AlarmStopIntent(alarmID: context.state.alarmID.uuidString)) {
                        Text("Stop")
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.white)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 16))
            }
        }
        .padding()
    }

    private var headline: String {
        switch context.state.mode {
        case .countdown: "SNOOZING"
        case .paused: "PAUSED"
        case .alert: "PEAL"
        @unknown default: "PEAL"
        }
    }

    @ViewBuilder
    private var modeContent: some View {
        switch context.state.mode {
        case .alert(let alert):
            Text(LockScreenFormat.formattedTime(hour: alert.time.hour, minute: alert.time.minute))
                .font(.system(size: 40, weight: .semibold))
        case .countdown(let countdown):
            Text(timerInterval: countdown.startDate...countdown.fireDate, countsDown: true)
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
        case .paused:
            Text(context.attributes.presentation.paused?.title ?? "Paused")
                .font(.title3.weight(.semibold))
        @unknown default:
            EmptyView()
        }
    }
}

private struct IconBadge: View {
    let context: ActivityViewContext<AlarmAttributes<PealAlarmActivityMetadata>>

    var body: some View {
        ZStack {
            Circle().fill(context.attributes.tintColor)
            Image(systemName: context.attributes.metadata?.iconSystemName ?? "alarm")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.black)
        }
        .frame(width: 36, height: 36)
    }
}

/// Marks the current state in the alarm's own color. Deliberately icon-only: the
/// expanded island's trailing region is only a few points wide, so a real word
/// here gets squeezed until it wraps to one letter per line.
private struct StatusGlyph: View {
    let context: ActivityViewContext<AlarmAttributes<PealAlarmActivityMetadata>>

    var body: some View {
        ZStack {
            Circle().fill(context.attributes.tintColor.opacity(0.18))
            Image(systemName: glyph)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(context.attributes.tintColor)
        }
        .frame(width: 36, height: 36)
    }

    private var glyph: String {
        switch context.state.mode {
        case .countdown: "zzz"
        case .paused: "pause.fill"
        case .alert: "bell.and.waves.left.and.right.fill"
        @unknown default: "bell.fill"
        }
    }
}

private struct ExpandedCenter: View {
    let context: ActivityViewContext<AlarmAttributes<PealAlarmActivityMetadata>>

    var body: some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)

            switch context.state.mode {
            case .alert(let alert):
                Text(LockScreenFormat.formattedTime(hour: alert.time.hour, minute: alert.time.minute))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            case .countdown(let countdown):
                Text(timerInterval: countdown.startDate...countdown.fireDate, countsDown: true)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
            case .paused:
                Text(context.attributes.presentation.alert.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            @unknown default:
                EmptyView()
            }
        }
        .padding(.top, 2)
    }

    /// Name the state, not the alarm. While snoozing, the alarm's own label
    /// ("Alarm") sitting over a counting-down clock reads as a bug.
    private var title: LocalizedStringResource {
        switch context.state.mode {
        case .countdown:
            context.attributes.presentation.countdown?.title ?? "Snoozing"
        case .paused:
            context.attributes.presentation.paused?.title ?? "Paused"
        default:
            context.attributes.presentation.alert.title
        }
    }
}

private struct ExpandedActions: View {
    let context: ActivityViewContext<AlarmAttributes<PealAlarmActivityMetadata>>

    @ViewBuilder
    var body: some View {
        switch context.state.mode {
        case .alert:
            HStack(spacing: 10) {
                if let secondary = context.attributes.presentation.alert.secondaryButton {
                    snoozeButton(secondary)
                }
                stopButton
            }
        case .countdown, .paused:
            // Without this the bottom region collapses to nothing while snoozing,
            // leaving a tall pill with dead space under the countdown.
            stopButton
        @unknown default:
            EmptyView()
        }
    }

    private func snoozeButton(_ secondary: AlarmButton) -> some View {
        Button(intent: AlarmSnoozeIntent(alarmID: context.state.alarmID.uuidString)) {
            HStack(spacing: 5) {
                Image(systemName: secondary.systemImageName)
                Text(secondary.text)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                Capsule().fill(.white.opacity(0.16))
            )
        }
        .buttonStyle(.plain)
    }

    private var stopButton: some View {
        Button(intent: AlarmStopIntent(alarmID: context.state.alarmID.uuidString)) {
            Text("Stop")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    Capsule().fill(context.attributes.tintColor)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct CompactTrailingLabel: View {
    let context: ActivityViewContext<AlarmAttributes<PealAlarmActivityMetadata>>

    var body: some View {
        switch context.state.mode {
        case .alert(let alert):
            Text(LockScreenFormat.formattedTime(hour: alert.time.hour, minute: alert.time.minute))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(context.attributes.tintColor)
        case .countdown(let countdown):
            Text(timerInterval: countdown.startDate...countdown.fireDate, countsDown: true)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(context.attributes.tintColor)
                .frame(width: 44)
        case .paused:
            Image(systemName: "pause.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(context.attributes.tintColor)
        @unknown default:
            EmptyView()
        }
    }
}

private enum LockScreenFormat {
    static func formattedTime(hour: Int, minute: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}
