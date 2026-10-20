//
//  AbsenceRecorder.swift
//  Sandman
//
//  Created by Jakub Řičař on 20.10.2026.
//

import AppKit
import CoreGraphics
import Observation

/// Notices when you're away from the Mac and records what kept it awake meanwhile.
///
/// An absence starts at your last keyboard or mouse input, once you've been idle for a minute
/// or the Mac goes to sleep, and ends at your next input. Only absences of 15 minutes or more
/// are kept, one entry each, for 30 days, so history stays small.
@Observable
final class AbsenceRecorder {
    static let minimumAbsence: TimeInterval = 15 * 60
    static let idleThreshold: TimeInterval = 60
    static let retention: TimeInterval = 30 * 24 * 60 * 60
    static let pollInterval: TimeInterval = 5

    /// Newest first.
    private(set) var history: [Absence] = []

    @ObservationIgnored private let blockers: () -> [Blocker]
    @ObservationIgnored private let idleTime: () -> TimeInterval
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let fileURL: URL?
    @ObservationIgnored private var current: Absence?
    /// Set between the system's will-sleep and did-wake notifications. Background wakes happen
    /// in between without a did-wake, and must not end the absence.
    @ObservationIgnored private var sleepStart: Date?
    @ObservationIgnored private var lastWake: Date?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var pollTask: Task<Void, Never>?

    init(
        blockers: @escaping () -> [Blocker],
        fileURL: URL? = AbsenceRecorder.defaultFileURL,
        idleTime: @escaping () -> TimeInterval = AbsenceRecorder.systemIdleTime,
        now: @escaping () -> Date = { .now },
        watchesSystem: Bool = true
    ) {
        self.blockers = blockers
        self.fileURL = fileURL
        self.idleTime = idleTime
        self.now = now
        history = load()
        guard watchesSystem else { return }

        let center = NSWorkspace.shared.notificationCenter
        observers = [
            center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.systemWillSleep() }
            },
            center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.systemDidWake() }
            },
        ]
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.tick()
                try? await Task.sleep(for: .seconds(Self.pollInterval))
            }
        }
    }

    func tick() {
        guard sleepStart == nil else { return }
        let now = now()
        let idle = idleTime()

        if var absence = current {
            if idle < Self.idleThreshold {
                current = nil
                finish(absence, end: now.addingTimeInterval(-idle))
            } else {
                record(into: &absence, at: now)
                current = absence
            }
        } else if idle >= Self.idleThreshold {
            var absence = Absence(start: now.addingTimeInterval(-idle), end: now)
            record(into: &absence, at: now)
            current = absence
        }
    }

    func systemWillSleep() {
        let now = now()
        // Closing the lid counts as leaving, even if you typed a second ago.
        var absence = current ?? Absence(start: now.addingTimeInterval(-idleTime()), end: now)
        record(into: &absence, at: now)
        current = absence
        sleepStart = now
    }

    func systemDidWake() {
        let now = now()
        if let sleepStart, var absence = current {
            absence.sleeps.append(DateInterval(start: sleepStart, end: now))
            absence.end = now
            current = absence
        }
        sleepStart = nil
        lastWake = now
    }

    private func record(into absence: inout Absence, at now: Date) {
        absence.end = now
        for blocker in blockers() {
            // A blocker that was already there before the Mac slept only counts again from the wake.
            let from = [blocker.since ?? now, absence.start, lastWake ?? .distantPast].max()!
            if let index = absence.culprits.firstIndex(where: { $0.id == blocker.id }) {
                absence.culprits[index].extend(from: from, to: now, maxGap: Self.pollInterval * 2 + 1)
                absence.culprits[index].update(from: blocker)
            } else {
                absence.culprits.append(Absence.Culprit(blocker: blocker, interval: DateInterval(start: min(from, now), end: now)))
            }
        }
    }

    private func finish(_ absence: Absence, end: Date) {
        var absence = absence
        absence.end = max(end, absence.start)
        absence.clipToBounds()
        guard absence.duration >= Self.minimumAbsence else { return }

        history.insert(absence, at: 0)
        let cutoff = now().addingTimeInterval(-Self.retention)
        history.removeAll { $0.end < cutoff }
        save()

        let (id, start, end) = (absence.id, absence.start, absence.end)
        Task {
            let wakes = await Task.detached(priority: .utility) { PowerLog.wakes(from: start, to: end) }.value
            guard let index = history.firstIndex(where: { $0.id == id }) else { return }
            history[index].wakes = wakes
            save()
        }
    }

    // MARK: Storage

    static var defaultFileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appending(path: Bundle.main.bundleIdentifier ?? "Sandman")
            .appending(path: "history.json")
    }

    private func load() -> [Absence] {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([Absence].self, from: data)) ?? []
    }

    private func save() {
        guard let fileURL, let data = try? JSONEncoder().encode(history) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: Idle time

    /// Seconds since the last keyboard, mouse or trackpad input. Needs no permission.
    nonisolated static func systemIdleTime() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }
}
