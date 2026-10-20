//
//  SandmanApp.swift
//  Sandman
//
//  Created by Jakub Řičař on 20.10.2026.
//

import AppKit
import SwiftUI

@main
struct SandmanApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var monitor = AssertionMonitor()
    @State private var loginItem = LoginItem()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(monitor: monitor, loginItem: loginItem)
        } label: {
            MenuBarLabel(monitor: monitor, appDelegate: appDelegate)
        }
        .menuBarExtraStyle(.window)

        Window("Sandman", id: "main") {
            MainWindowView(monitor: monitor)
        }
        .defaultSize(width: 560, height: 440)
        // Opened at login, Sandman should sit quietly in the menu bar.
        .defaultLaunchBehavior(loginItem.isEnabled ? .suppressed : .presented)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set by the menu bar label, which is always on screen, so the delegate can open SwiftUI's window.
    var showMainWindow: (() -> Void)?

    /// Launching Sandman again (from Spotlight or Finder) while it runs in the menu bar opens its window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow?()
        return false
    }
}

private struct MenuBarLabel: View {
    let monitor: AssertionMonitor
    let appDelegate: AppDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: monitor.statusSymbol)
            .accessibilityLabel(monitor.statusTitle)
            .onAppear {
                appDelegate.showMainWindow = {
                    openWindow(id: "main")
                    NSApp.activate()
                }
            }
    }
}
