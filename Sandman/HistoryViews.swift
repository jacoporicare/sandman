//
//  HistoryViews.swift
//  Sandman
//
//  Created by Jakub Řičař on 20.10.2026.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

private let awakeColor = Color.orange
private let asleepColor = Color.indigo

/// "While you were away" in the menu bar dropdown, for the most recent absence.
struct AbsenceCard: View {
    let absence: Absence
    let onDismiss: () -> Void
    let onShowHistory: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("While you were away")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Dismiss")
            }
            AbsenceSummary(absence: absence, isDetailed: false)
            Button("Show History", action: onShowHistory)
                .buttonStyle(.link)
                .font(.caption)
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 8))
    }
}

/// Every recorded absence, grouped by the day you came back.
struct HistoryView: View {
    let recorder: AbsenceRecorder

    private var days: [(day: Date, absences: [Absence])] {
        Dictionary(grouping: recorder.history) { Calendar.current.startOfDay(for: $0.end) }
            .map { (day: $0.key, absences: $0.value) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        if recorder.history.isEmpty {
            ContentUnavailableView(
                "No history yet",
                systemImage: "clock",
                description: Text("When you're away from your Mac for 15 minutes or more, Sandman notes what kept it awake. History is kept for 30 days.")
            )
        } else {
            List {
                ForEach(days, id: \.day) { day in
                    Section(Self.title(for: day.day)) {
                        ForEach(day.absences) { absence in
                            AbsenceSummary(absence: absence, isDetailed: true)
                                .padding(.vertical, 8)
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    private static func title(for day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}

/// What happened during one absence: when, how long the Mac slept, and who kept it awake.
/// The detailed version draws one timeline lane per app.
struct AbsenceSummary: View {
    let absence: Absence
    let isDetailed: Bool

    private var culprits: [Absence.Culprit] { absence.culprits.sorted { $0.duration > $1.duration } }
    private var bounds: DateInterval { DateInterval(start: absence.start, end: absence.end) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(timeRange)
                    .font(isDetailed ? .headline : .callout.weight(.medium))
                Spacer()
                Text(formatDuration(absence.duration))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if isDetailed {
                lanes
            } else {
                TimelineBar(bounds: bounds, segments: absence.sleeps, segmentColor: asleepColor, background: awakeColor.opacity(0.75))
                    .frame(height: 8)
            }

            HStack(spacing: 12) {
                legend("Awake", absence.awake, awakeColor)
                legend("Asleep", absence.asleep, asleepColor)
            }
            .font(.caption)

            if !isDetailed {
                ForEach(culprits) { CulpritRow(culprit: $0) }
            }
            if culprits.isEmpty && absence.awake >= 60 {
                Text("No app was keeping it awake. It stayed awake until its sleep timer ran out.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            wakes
        }
    }

    /// "Your Mac" on top, then one lane per app on the same time axis.
    private var lanes: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
            GridRow {
                Label {
                    Text("Your Mac")
                } icon: {
                    Image(systemName: "laptopcomputer")
                }
                .frame(width: 140, alignment: .leading)
                TimelineBar(bounds: bounds, segments: absence.sleeps, segmentColor: asleepColor, background: awakeColor.opacity(0.75))
                    .frame(height: 10)
                Text(formatDuration(absence.awake))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .gridColumnAlignment(.trailing)
            }
            ForEach(culprits) { culprit in
                GridRow {
                    Label {
                        Text(culprit.name).lineLimit(1)
                    } icon: {
                        CulpritIcon(path: culprit.path)
                    }
                    .frame(width: 140, alignment: .leading)
                    .help(culprit.reasons.joined(separator: "\n"))
                    TimelineBar(bounds: bounds, segments: culprit.intervals, segmentColor: culprit.keepsDisplayOn ? .blue : awakeColor, background: Color.secondary.opacity(0.15))
                        .frame(height: 10)
                    Text(formatDuration(culprit.duration))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .font(.callout)
    }

    @ViewBuilder
    private var wakes: some View {
        let wakes = absence.backgroundWakes
        if !wakes.isEmpty {
            let causes = Dictionary(grouping: wakes, by: \.cause)
                .sorted { $0.value.count > $1.value.count }
            if isDetailed {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(causes, id: \.key) { cause, wakes in
                        Text("Woke \(Self.times(wakes.count)) for \(cause.label) · \(formatDuration(wakes.reduce(0) { $0 + $1.duration }))")
                            .help(Set(wakes.map(\.detail)).sorted().joined(separator: "\n"))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Text("Woke \(Self.times(wakes.count)) in the background (\(causes.map(\.key.label).formatted(.list(type: .and))))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var timeRange: String {
        let start = absence.start.formatted(date: .omitted, time: .shortened)
        let end = Calendar.current.isDate(absence.start, inSameDayAs: absence.end)
            ? absence.end.formatted(date: .omitted, time: .shortened)
            : absence.end.formatted(.dateTime.weekday(.abbreviated).hour().minute())
        return "\(start) – \(end)"
    }

    private func legend(_ title: String, _ duration: TimeInterval, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text("\(title) \(formatDuration(duration))")
                .foregroundStyle(.secondary)
        }
    }

    private static func times(_ count: Int) -> String {
        count == 1 ? "once" : "\(count)×"
    }
}

private struct CulpritRow: View {
    let culprit: Absence.Culprit

    var body: some View {
        HStack(spacing: 8) {
            CulpritIcon(path: culprit.path)
            VStack(alignment: .leading, spacing: 0) {
                Text(culprit.name)
                    .lineLimit(1)
                if let reason = culprit.reasons.first {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Text(formatDuration(culprit.duration))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

private struct CulpritIcon: View {
    let path: String?

    var body: some View {
        Image(nsImage: path.map { NSWorkspace.shared.icon(forFile: $0) } ?? NSWorkspace.shared.icon(for: .unixExecutable))
            .resizable()
            .frame(width: 18, height: 18)
    }
}

/// A horizontal bar over `bounds` with `segments` painted in.
private struct TimelineBar: View {
    let bounds: DateInterval
    let segments: [DateInterval]
    let segmentColor: Color
    let background: Color

    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / max(bounds.duration, 1)
            ZStack(alignment: .leading) {
                Rectangle().fill(background)
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    Rectangle()
                        .fill(segmentColor)
                        .frame(width: max(2, segment.duration * scale))
                        .offset(x: segment.start.timeIntervalSince(bounds.start) * scale)
                }
            }
            .clipShape(.capsule)
        }
    }
}
