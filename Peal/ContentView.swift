//
//  ContentView.swift
//  Peal
//
//  Created by Rishit Patil on 7/22/26.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var scheduler = AlarmScheduler.shared
    @State private var isPresentingNewAlarm = false
    @State private var editingAlarm: StoredAlarm?
    @State private var isPresentingThemePicker = false
    @State private var isPresentingHistory = false
    @AppStorage("selectedAlarmTheme") private var selectedThemeRaw = AlarmListTheme.bento.rawValue
    @AppStorage("appColorScheme") private var appColorSchemeRaw = AppColorScheme.system.rawValue

    private var selectedTheme: AlarmListTheme {
        AlarmListTheme(rawValue: selectedThemeRaw) ?? .bento
    }

    private var selectedColorScheme: AppColorScheme {
        AppColorScheme(rawValue: appColorSchemeRaw) ?? .system
    }

    var body: some View {
        NavigationStack {
            Group {
                switch selectedTheme {
                case .classic:
                    ClassicAlarmListView(scheduler: scheduler) { editingAlarm = $0 }
                case .bento:
                    BentoAlarmListView(
                        scheduler: scheduler,
                        onEdit: { editingAlarm = $0 },
                        onAdd: { isPresentingNewAlarm = true }
                    )
                }
            }
            .navigationTitle("Alarms")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .overlay(alignment: .topTrailing) {
                        if !scheduler.historyAlarms.isEmpty {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .offset(x: 2, y: -2)
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingThemePicker = true
                    } label: {
                        Image(systemName: "paintpalette")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingNewAlarm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingNewAlarm) {
                NewAlarmView()
            }
            .sheet(item: $editingAlarm) { alarm in
                NewAlarmView(existingAlarm: alarm)
            }
            .sheet(isPresented: $isPresentingThemePicker) {
                ThemePickerView(
                    selectedTheme: Binding(
                        get: { selectedTheme },
                        set: { selectedThemeRaw = $0.rawValue }
                    ),
                    selectedColorScheme: Binding(
                        get: { selectedColorScheme },
                        set: { appColorSchemeRaw = $0.rawValue }
                    )
                )
            }
            .sheet(isPresented: $isPresentingHistory) {
                HistoryView(scheduler: scheduler) { alarm in
                    isPresentingHistory = false
                    editingAlarm = alarm
                }
            }
            .task {
                await scheduler.requestAuthorizationIfNeeded()
            }
        }
    }
}

#Preview {
    ContentView()
}
