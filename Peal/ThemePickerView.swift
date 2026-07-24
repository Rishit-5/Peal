//
//  ThemePickerView.swift
//  Peal
//

import SwiftUI

struct ThemePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTheme: AlarmListTheme
    @Binding var selectedColorScheme: AppColorScheme

    var body: some View {
        NavigationStack {
            List {
                Section("Layout") {
                    ForEach(AlarmListTheme.allCases) { theme in
                        Button {
                            selectedTheme = theme
                        } label: {
                            HStack {
                                Image(systemName: theme.iconName)
                                    .frame(width: 24)
                                Text(theme.displayName)
                                Spacer()
                                if theme == selectedTheme {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }

                Section("Color scheme") {
                    ForEach(AppColorScheme.allCases) { scheme in
                        Button {
                            selectedColorScheme = scheme
                        } label: {
                            HStack {
                                Image(systemName: scheme.iconName)
                                    .frame(width: 24)
                                Text(scheme.displayName)
                                Spacer()
                                if scheme == selectedColorScheme {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Appearance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
