//
//  AlarmListTheme.swift
//  Peal
//

import Foundation

enum AlarmListTheme: String, CaseIterable, Identifiable {
    case classic
    case bento

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: "Classic"
        case .bento: "Bento"
        }
    }

    var iconName: String {
        switch self {
        case .classic: "list.bullet"
        case .bento: "square.grid.2x2"
        }
    }
}
