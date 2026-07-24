//
//  Peal_App.swift
//  Peal
//
//  Created by Rishit Patil on 7/22/26.
//

import SwiftUI

@main
struct Peal_App: App {
    @AppStorage("appColorScheme") private var appColorSchemeRaw = AppColorScheme.system.rawValue

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(
                    (AppColorScheme(rawValue: appColorSchemeRaw) ?? .system).colorScheme
                )
        }
    }
}
