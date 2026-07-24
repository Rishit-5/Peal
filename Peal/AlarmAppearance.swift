//
//  AlarmAppearance.swift
//  Peal
//

import SwiftUI

enum AlarmColorOption: String, CaseIterable, Codable, Identifiable {
    case orange, indigo, green, pink, purple, blue, teal, red, yellow

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .orange: .orange
        case .indigo: .indigo
        case .green: .green
        case .pink: .pink
        case .purple: .purple
        case .blue: .blue
        case .teal: .teal
        case .red: .red
        case .yellow: .yellow
        }
    }
}

enum AlarmIconOption: String, CaseIterable, Codable, Identifiable {
    case alarm
    case sun = "sun.max"
    case moon = "moon.zzz"
    case dumbbell
    case house
    case briefcase
    case book
    case airplane
    case heart
    case cup = "cup.and.saucer"
    case pill = "pills"
    case creditcard

    var id: String { rawValue }
    var systemImage: String { rawValue }
}
