//
//  Absence.swift
//  Sandman
//
//  Created by Jakub Řičař on 20.10.2026.
//

import Foundation

/// One time you were away from the Mac (no keyboard or mouse input for 15 minutes or more),
/// and what the Mac did meanwhile.
struct Absence: Codable, Identifiable, Equatable {
    /// An app or process that kept the Mac awake during the absence.
    struct Culprit: Codable, Identifiable, Equatable {
        /// Same as `ProcessIdentity.id`: the bundle path for apps.
        let id: String
        var name: String
        var path: String?
        var keepsDisplayOn: Bool
        var reasons: [String]
        var intervals: [DateInterval]

        var duration: TimeInterval { intervals.reduce(0) { $0 + $1.duration } }

        init(blocker: Blocker, interval: DateInterval) {
            id = blocker.id
            name = blocker.owner.name
            path = blocker.owner.path
            keepsDisplayOn = blocker.kind == .display
            reasons = blocker.reasons
            intervals = [interval]
        }

        /// Continues the last interval if it ended within `maxGap`, otherwise starts a new one.
        mutating func extend(from start: Date, to end: Date, maxGap: TimeInterval) {
            if let last = intervals.last, end.timeIntervalSince(last.end) <= maxGap {
                intervals[intervals.count - 1] = DateInterval(start: last.start, end: end)
            } else {
                let start = max(start, intervals.last?.end ?? start)
                intervals.append(DateInterval(start: min(start, end), end: end))
            }
        }

        mutating func update(from blocker: Blocker) {
            keepsDisplayOn = keepsDisplayOn || blocker.kind == .display
            reasons += blocker.reasons.filter { !reasons.contains($0) }
        }
    }

    var id = UUID()
    /// Your last input before you left.
    var start: Date
    /// Your first input after you came back.
    var end: Date
    /// When the Mac was asleep. Brief background wake-ups inside these are in `wakes`.
    var sleeps: [DateInterval] = []
    var culprits: [Culprit] = []
    /// Read from the macOS power log once the absence ends.
    var wakes: [PowerLog.Wake] = []

    var duration: TimeInterval { end.timeIntervalSince(start) }
    var asleep: TimeInterval { sleeps.reduce(0) { $0 + $1.duration } }
    var awake: TimeInterval { max(0, duration - asleep) }

    /// Wake-ups macOS did on its own, not the one you caused by coming back.
    var backgroundWakes: [PowerLog.Wake] { wakes.filter { $0.cause != .user } }

    /// Trims sleeps and culprit intervals to the absence itself.
    mutating func clipToBounds() {
        let bounds = DateInterval(start: start, end: max(start, end))
        sleeps = sleeps.compactMap { $0.intersection(with: bounds) }.filter { $0.duration > 0 }
        for index in culprits.indices {
            culprits[index].intervals = culprits[index].intervals
                .compactMap { $0.intersection(with: bounds) }
                .filter { $0.duration > 0 }
        }
        culprits.removeAll { $0.intervals.isEmpty }
    }
}
