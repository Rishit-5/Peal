# Peal

<img src="Peal/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" width="120" alt="Peal app icon">

A native iOS alarm app built on Apple's [AlarmKit](https://developer.apple.com/documentation/alarmkit) framework — full-screen alerts that ring through Silent and Focus, on the Lock Screen and Dynamic Island, the same system-level guarantees the built-in Clock app gets.

## Requirements

- iOS 26.2+
- Xcode 26+
- No third-party dependencies — AlarmKit and UserNotifications are both system frameworks

## Features

### Alarms

- **One-time, weekly, or monthly recurrence.** Weekly lets you pick any combination of weekdays (with Every Day / Weekdays / Weekends quick-select). Monthly lets you pick a day of the month, clamped to the last valid day for shorter months (the 31st fires on Feb 28/29).
- **Skip next occurrence.** Skip a single upcoming firing of a recurring alarm — swipe left on a Classic row or tap the ⋯ menu on a Bento tile — without disabling the alarm or losing the rest of its schedule.
- **Snooze.** A 9-minute snooze via AlarmKit's native secondary alert button.
- **Enable / disable.** Pause any alarm without deleting it.
- **Per-alarm icon and color.** 12 icons and 9 colors to choose from when creating or editing an alarm.
- **History & revive.** One-time alarms that have fired move to a History screen instead of just disappearing. Swipe to revive with one tap (reschedules for the next available time at the same time of day), or tap through to the editor to pick a different date.

### Layouts & appearance

- **Classic** — a plain list, closest to the system Clock app.
- **Bento** — a grid layout with a "next alarm" hero tile up top and colored tiles for the rest, mirroring recurrence type by default.
- Switch between them anytime from the palette icon in the toolbar — the same screen also has a **light / dark / system** appearance override, independent of the device's own setting.

## How recurrence actually works

AlarmKit only exposes two schedule types: a one-time alarm, or a native weekly-recurring rule. There's no "skip just one occurrence" and no monthly recurrence at all. Peal simulates both on top of what AlarmKit actually offers:

- **Weekly and monthly alarms are a rolling buffer of individually-scheduled one-time alarms** — the next 6 occurrences — rather than a single ongoing AlarmKit rule. This is what makes **skip next occurrence** fully reliable: the occurrence *after* the skipped one was already scheduled independently ahead of time, so it fires regardless of whether the app ever runs again.
- **The buffer tops itself back up** whenever the app launches, or whenever AlarmKit reports a change. The tradeoff is that a weekly or monthly alarm needs the app reopened occasionally to stay fully stocked — anywhere from about a week (an every-weekday alarm) to a few months (a single-weekday or monthly alarm), depending on how many days are selected.
- **A local notification is the safety net** for when that doesn't happen. It fires before the buffer would actually run dry, with a lead time that scales with how much runway is left — 25% of the buffer's remaining span, clamped between 1 and 10 days — so a short buffer isn't warned absurdly early and a long one isn't warned at the last minute.

## Project structure

```
Peal/
├── Peal_App.swift              App entry point, appearance override
├── ContentView.swift           Root view: theme routing, toolbar, sheets
├── AlarmScheduler.swift        Source of truth: AlarmKit scheduling, buffering, history
├── AlarmFormatting.swift       Shared date/recurrence display logic
├── AlarmAppearance.swift       Icon and color option definitions
├── AlarmListTheme.swift        Classic/Bento theme enum
├── AppColorScheme.swift        Light/dark/system appearance enum
├── ClassicAlarmListView.swift  List layout
├── BentoAlarmListView.swift    Grid layout
├── NewAlarmView.swift          Create/edit alarm sheet
├── ThemePickerView.swift       Layout + appearance picker sheet
├── HistoryView.swift           Expired one-time alarms, revive
├── AlarmContextMenu.swift      Shared skip/delete menu
├── PermissionDeniedBanner.swift
└── Info.plist                 AlarmKit usage description
```

## Permissions

Peal requests two separate permissions on first launch:

- **AlarmKit authorization** — required to schedule any alarm at all.
- **Notification authorization** — used only for the buffer-refresh safety net described above; alarms themselves don't depend on it.

## Building

Open `Peal.xcodeproj` in Xcode 26+ and run. AlarmKit requires an iOS 26.2+ simulator or device.
