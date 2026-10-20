//
//  MainWindowView.swift
//  Sandman
//
//  Created by Jakub Řičař on 20.10.2026.
//

import SwiftUI

enum MainWindowTab: String {
    case now, history
}

/// Everything keeping the Mac awake right now, and what kept it awake while you were away.
struct MainWindowView: View {
    let monitor: AssertionMonitor
    let recorder: AbsenceRecorder
    @AppStorage("mainWindowTab") private var tab = MainWindowTab.now
    @AppStorage("showBackgroundActivity") private var showBackground = false

    private var visibleBackground: [Blocker] { showBackground ? monitor.background : [] }

    var body: some View {
        Group {
            switch tab {
            case .now: now
            case .history: HistoryView(recorder: recorder)
            }
        }
        .frame(minWidth: 480, minHeight: 320)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("View", selection: $tab) {
                    Text("Now").tag(MainWindowTab.now)
                    Text("History").tag(MainWindowTab.history)
                }
                .pickerStyle(.segmented)
            }
            if tab == .now {
                ToolbarItem {
                    Toggle(isOn: $showBackground) {
                        Label("Background Activity", systemImage: "gearshape.2")
                    }
                    .help("Also show system activity and short-lived blockers that can’t keep your Mac awake on their own")
                }
            }
        }
    }

    @ViewBuilder
    private var now: some View {
        if monitor.blockers.isEmpty && visibleBackground.isEmpty && !monitor.isUnavailable {
            ContentUnavailableView(
                "Your Mac can sleep",
                systemImage: "lightbulb",
                description: Text("Nothing is keeping it awake. Apps that prevent sleep will show up here.")
            )
        } else {
            VStack(spacing: 0) {
                StatusHeader(monitor: monitor, symbolSize: 30)
                    .padding()
                Divider()
                List {
                    if !monitor.blockers.isEmpty {
                        Section("Keeping your Mac awake") {
                            ForEach(monitor.blockers) { BlockerRow(blocker: $0) }
                        }
                    }
                    if !visibleBackground.isEmpty {
                        Section("Background activity") {
                            ForEach(visibleBackground) { BlockerRow(blocker: $0) }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}

private struct BlockerRow: View {
    let blocker: Blocker

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            OwnerIcon(owner: blocker.owner, size: 36)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(blocker.owner.name)
                        .font(.headline)
                    if blocker.owner.isSystem {
                        Text("macOS")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.quaternary, in: .capsule)
                            .help("Part of macOS")
                    }
                }
                ForEach(blocker.assertions) { AssertionLine(assertion: $0) }
                if !blocker.intermediaries.isEmpty {
                    Text("via \(blocker.intermediaries.formatted(.list(type: .and)))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 12)

            if let since = blocker.since {
                ElapsedText(since: since, prefix: "for ")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Menu {
                OwnerActions(owner: blocker.owner)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.vertical, 6)
        .contextMenu { OwnerActions(owner: blocker.owner) }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if blocker.owner.canQuit {
                Button("Quit", systemImage: "xmark.circle") { blocker.owner.quit() }
                    .tint(.red)
            }
        }
    }
}

private struct AssertionLine: View {
    let assertion: SleepAssertion

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Label(assertion.kind.label, systemImage: assertion.kind.symbol)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(assertion.kind.tint)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(assertion.kind.tint.opacity(0.12), in: .capsule)
                Text(assertion.name)
                    .font(.callout)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
            if let details = assertion.details, details != assertion.name {
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            if let expiresAt = assertion.expiresAt, expiresAt > .now {
                Text("Ends in \(expiresAt, style: .relative)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .help(assertion.rawName == assertion.name ? assertion.type : "\(assertion.type)\n\(assertion.rawName)")
    }
}
