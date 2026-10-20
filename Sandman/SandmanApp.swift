//
//  SandmanApp.swift
//  Sandman
//
//  Created by Jakub Řičař on 20.10.2026.
//

import SwiftUI

@main
struct SandmanApp: App {
    @State private var monitor = AssertionMonitor()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(monitor: monitor)
        } label: {
            Image(systemName: monitor.statusSymbol)
                .accessibilityLabel(monitor.statusTitle)
        }
        .menuBarExtraStyle(.window)

        Window("Sandman", id: "main") {
            MainWindowView(monitor: monitor)
        }
        .defaultSize(width: 560, height: 440)
        .defaultLaunchBehavior(.presented)
    }
}
