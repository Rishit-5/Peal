//
//  AlarmActivityMetadata.swift
//  PealShared
//

import AlarmKit

/// Carried on `AlarmAttributes` so the Live Activity (a separate target/process)
/// knows which icon to draw. Color doesn't need a field here — it rides along on
/// `AlarmAttributes.tintColor`, which AlarmKit already exposes directly.
///
/// Lives in this shared package (rather than being compiled into both the app
/// and widget targets separately) so both sides agree on one concrete Swift
/// type — ActivityKit matches a Live Activity to a widget's `ActivityConfiguration`
/// by exact `ActivityAttributes` type identity, and two separately-compiled
/// copies of an identical struct are NOT the same type.
public struct PealAlarmActivityMetadata: AlarmMetadata {
    public let iconSystemName: String

    public init(iconSystemName: String) {
        self.iconSystemName = iconSystemName
    }
}
