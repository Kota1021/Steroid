//
//  enhancedApp.swift
//  enhanced
//
//  Created by KotaroMatsumoto on 2026/04/11.
//

import SwiftUI

@main
struct enhancedApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar app — no main window
        Settings {
            EmptyView()
        }
    }
}
