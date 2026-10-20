//
//  MenuBarView.swift
//  Sandman
//
//  Created by Jakub Řičař on 20.10.2026.
//

import AppKit
import SwiftUI

/// The panel that drops down from the menu bar icon.
struct MenuBarView: View {
    let monitor: AssertionMonitor
    @Environment(\.openWindow) private var openWindow

    private static let maxRowsWithoutScrolling = 7

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StatusHeader(monitor: monitor)
                .padding(12)

            if !monitor.blockers.isEmpty {
                Divider()
                if monitor.blockers.count > Self.maxRowsWithoutScrolling {
                    ScrollView { rows }.frame(height: 320)
                } else {
                    rows
                }
            }

            Divider()
            VStack(spacing: 0) {
                MenuItemButton(title: "Open Sandman", shortcut: "o", action: openMainWindow)
                MenuItemButton(title: "Quit Sandman", shortcut: "q") { NSApp.terminate(nil) }
            }
            .padding(6)
        }
        .frame(width: 320)
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(monitor.blockers) { blocker in
                Button(action: openMainWindow) {
                    CompactBlockerRow(blocker: blocker)
                }
                .buttonStyle(.plain)
                .hoverHighlight()
                .contextMenu { OwnerActions(owner: blocker.owner) }
            }
        }
        .padding(6)
    }

    private func openMainWindow() {
        openWindow(id: "main")
        NSApp.activate()
    }
}

private struct CompactBlockerRow: View {
    let blocker: Blocker

    var body: some View {
        HStack(spacing: 10) {
            OwnerIcon(owner: blocker.owner, size: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(blocker.owner.name)
                    .lineLimit(1)
                Text(blocker.reasons.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if blocker.kind == .display {
                Image(systemName: "display")
                    .foregroundStyle(.secondary)
                    .help("Keeps the display on")
            }
            if let since = blocker.since {
                ElapsedText(since: since)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .contentShape(.rect)
    }
}

/// A full-width row that behaves like a menu item: hover highlight and a shortcut hint.
private struct MenuItemButton: View {
    let title: String
    let shortcut: KeyEquivalent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Text("⌘\(String(shortcut.character).uppercased())")
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(shortcut)
        .hoverHighlight()
    }
}

private struct HoverHighlight: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 6))
            .onHover { isHovered = $0 }
    }
}

private extension View {
    func hoverHighlight() -> some View { modifier(HoverHighlight()) }
}
