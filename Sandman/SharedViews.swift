//
//  SharedViews.swift
//  Sandman
//
//  Created by Jakub Řičař on 20.10.2026.
//

import AppKit
import SwiftUI

extension SleepAssertion.Kind {
    var label: String {
        switch self {
        case .display: "Keeps display on"
        case .system: "Prevents sleep"
        case .background: "Background"
        }
    }

    var symbol: String {
        switch self {
        case .display: "lightbulb.max.fill"
        case .system: "lightbulb.fill"
        case .background: "gearshape.2"
        }
    }

    var tint: Color {
        switch self {
        case .display: .displayOn
        case .system: .indigo
        case .background: .secondary
        }
    }
}

extension AssertionMonitor {
    var statusSymbol: String {
        if isUnavailable { return "exclamationmark.triangle" }
        if blockers.isEmpty { return "lightbulb" }
        return keepsDisplayOn ? SleepAssertion.Kind.display.symbol : SleepAssertion.Kind.system.symbol
    }

    /// Black or white while the Mac can sleep, then the color of what's keeping it awake.
    var statusTint: Color {
        if blockers.isEmpty { return .primary }
        return keepsDisplayOn ? SleepAssertion.Kind.display.tint : SleepAssertion.Kind.system.tint
    }

    var statusTitle: String {
        if isUnavailable { return "Can't read sleep status" }
        if blockers.isEmpty { return "Your Mac can sleep" }
        return keepsDisplayOn ? "Your display is kept on" : "Your Mac is kept awake"
    }

    var statusSubtitle: String {
        if isUnavailable { return "powerd didn't answer. Sandman will keep trying." }
        if blockers.isEmpty { return "Nothing is keeping it awake." }
        let names = blockers.map(\.owner.name)
        let shown = names.count > 3 ? Array(names.prefix(2)) + ["\(names.count - 2) more"] : names
        return "by " + shown.formatted(.list(type: .and))
    }
}

struct StatusHeader: View {
    let monitor: AssertionMonitor
    var symbolSize: CGFloat = 24

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: monitor.statusSymbol)
                .font(.system(size: symbolSize))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(monitor.statusTint)
                .frame(width: symbolSize + 12)
                .contentTransition(.symbolEffect(.replace))
            VStack(alignment: .leading, spacing: 2) {
                Text(monitor.statusTitle).font(.headline)
                Text(monitor.statusSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }
}

struct OwnerIcon: View {
    let owner: ProcessIdentity
    let size: CGFloat

    var body: some View {
        Image(nsImage: owner.icon)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
    }
}

/// "12 min", "1 hr, 5 min" — how long something has been going on.
struct ElapsedText: View {
    let since: Date
    var prefix = ""

    var body: some View {
        TimelineView(.periodic(from: since, by: 15)) { context in
            Text(Self.describe(context.date.timeIntervalSince(since), prefix: prefix))
                .monospacedDigit()
        }
    }

    static func describe(_ interval: TimeInterval, prefix: String) -> String {
        guard interval >= 60 else { return "just now" }
        return prefix + formatDuration(interval)
    }
}

/// "<1 min", "40 min", "3 hr, 30 min".
func formatDuration(_ interval: TimeInterval) -> String {
    guard interval >= 60 else { return "<1 min" }
    return Duration.seconds(interval)
        .formatted(.units(allowed: [.days, .hours, .minutes], width: .abbreviated, maximumUnitCount: 2))
}

/// "Show in Finder", "Quit" and "Force Quit…", for context menus and the row menu.
struct OwnerActions: View {
    let owner: ProcessIdentity

    var body: some View {
        if let path = owner.path {
            Button("Show in Finder", systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: path)])
            }
        }
        if owner.canQuit {
            Divider()
            Button("Quit \(owner.name)", systemImage: "xmark.circle") {
                owner.quit()
            }
            Button("Force Quit \(owner.name)…", systemImage: "xmark.octagon") {
                Self.confirmForceQuit(owner)
            }
        }
    }

    private static func confirmForceQuit(_ owner: ProcessIdentity) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Force quit \(owner.name)?"
        alert.informativeText = "It stops immediately, without a chance to save. Any unsaved changes will be lost."
        alert.addButton(withTitle: "Force Quit").hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn {
            owner.forceQuit()
        }
    }
}
