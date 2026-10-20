//
//  AssertionMonitor.swift
//  Sandman
//
//  Created by Jakub Řičař on 20.10.2026.
//

import Foundation
import Observation

/// An app or process together with the assertions it currently holds.
struct Blocker: Identifiable, Equatable {
    let owner: ProcessIdentity
    var assertions: [SleepAssertion]

    var id: String { owner.id }
    var kind: SleepAssertion.Kind { assertions.map(\.kind).min() ?? .background }
    var since: Date? { assertions.compactMap(\.startedAt).min() }

    /// Unique reasons, oldest first, e.g. "Playing audio".
    var reasons: [String] {
        var seen = Set<String>()
        return assertions.map(\.name).filter { seen.insert($0).inserted }
    }

    /// Daemons holding an assertion for the owner, e.g. coreaudiod for an app playing audio.
    var intermediaries: [String] {
        Set(assertions.filter { $0.onBehalfOfPID != nil }.map(\.processName)).sorted()
    }
}

/// Polls powerd and groups its assertions by the app responsible for them.
///
/// powerd only posts change notifications to clients registered through private API,
/// so this polls instead. One read costs about 0.1 ms.
@Observable
final class AssertionMonitor {
    /// Apps and processes currently keeping the Mac or its display awake.
    private(set) var blockers: [Blocker] = []
    /// Assertions that don't block idle sleep on their own, and blockers that haven't lasted long enough to matter.
    private(set) var background: [Blocker] = []
    /// True when powerd couldn't be queried.
    private(set) var isUnavailable = false

    var keepsDisplayOn: Bool { blockers.contains { $0.kind == .display } }

    /// Apps take sleep assertions for a few seconds at a time while they finish work (WhatsApp syncing,
    /// widgets refreshing). Those can't keep the Mac awake — the shortest sleep timer is a minute —
    /// so an owner only counts as a blocker once it has been blocking continuously for this long.
    static let minimumBlockingDuration: TimeInterval = 10

    @ObservationIgnored private var identities: [pid_t: ProcessIdentity] = [:]
    /// When each owner was first seen blocking, across back-to-back assertions.
    @ObservationIgnored private var blockingSince: [String: Date] = [:]
    @ObservationIgnored private var pollTask: Task<Void, Never>?

    init(interval: Duration = .seconds(2)) {
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.refresh()
                try? await Task.sleep(for: interval)
            }
        }
    }

    func refresh() {
        guard let assertions = SleepAssertion.readAll() else {
            if !isUnavailable { isUnavailable = true }
            return
        }
        if isUnavailable { isUnavailable = false }

        var resolved: [pid_t: ProcessIdentity] = [:]
        var blocking: [String: Blocker] = [:]
        var other: [String: Blocker] = [:]

        for assertion in assertions.sorted(by: { ($0.startedAt ?? .distantPast) < ($1.startedAt ?? .distantPast) }) {
            let ownerPID = assertion.onBehalfOfPID ?? assertion.pid
            // Only the assertion's own process name is known; an on-behalf owner is resolved from its pid.
            let owner = resolved[ownerPID] ?? identities[ownerPID]
                ?? ProcessIdentity(pid: ownerPID, processName: assertion.onBehalfOfPID == nil ? assertion.processName : nil)
            resolved[ownerPID] = owner

            if assertion.kind == .background {
                other[owner.id, default: Blocker(owner: owner, assertions: [])].assertions.append(assertion)
            } else {
                blocking[owner.id, default: Blocker(owner: owner, assertions: [])].assertions.append(assertion)
            }
        }
        identities = resolved

        let now = Date.now
        var stillBlockingSince: [String: Date] = [:]
        for (id, blocker) in blocking {
            let since = min(blockingSince[id] ?? now, blocker.since ?? now)
            stillBlockingSince[id] = since
            if now.timeIntervalSince(since) < Self.minimumBlockingDuration {
                other[id, default: Blocker(owner: blocker.owner, assertions: [])].assertions += blocker.assertions
                blocking[id] = nil
            }
        }
        blockingSince = stillBlockingSince

        let newBlockers = Self.ordered(blocking.values)
        let newBackground = Self.ordered(other.values)
        if blockers != newBlockers { blockers = newBlockers }
        if background != newBackground { background = newBackground }
    }

    /// Apps first, then macOS processes, each alphabetically so rows don't jump around.
    private static func ordered(_ blockers: some Sequence<Blocker>) -> [Blocker] {
        blockers.sorted {
            ($0.owner.isSystem ? 1 : 0, $0.owner.name.localizedLowercase)
                < ($1.owner.isSystem ? 1 : 0, $1.owner.name.localizedLowercase)
        }
    }
}
