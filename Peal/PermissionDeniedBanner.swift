//
//  PermissionDeniedBanner.swift
//  Peal
//

import SwiftUI

struct PermissionDeniedBanner: View {
    var body: some View {
        Text("Alarm permission was denied. Enable it in Settings to schedule alarms.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}
