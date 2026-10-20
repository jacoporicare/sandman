//
//  PowerLog.swift
//  Sandman
//
//  Created by Jakub Řičař on 20.10.2026.
//

import Foundation

/// Reads wake-ups from the macOS power log (`pmset -g log`), which keeps about a week of history.
///
/// The log's wording isn't documented and may change. Anything Sandman can't parse is skipped,
/// and an absence without wake-ups is still a complete report.
nonisolated enum PowerLog {
    nonisolated enum Cause: String, Codable, Sendable {
        /// You woke it: power button, lid, keyboard or trackpad.
        case user
        /// Wi-Fi traffic the Mac had to handle, such as TCP keep-alives.
        case network
        /// macOS's scheduled maintenance wakes.
        case maintenance
        /// Power Nap and other scheduled background work.
        case backgroundTasks
        /// A notification arrived.
        case notification
        /// A charger or USB device was plugged in.
        case accessory
        case other

        var label: String {
            switch self {
            case .user: "you"
            case .network: "network activity"
            case .maintenance: "scheduled maintenance"
            case .backgroundTasks: "background tasks"
            case .notification: "notifications"
            case .accessory: "a charger or USB device"
            case .other: "other reasons"
            }
        }
    }

    nonisolated struct Wake: Codable, Equatable, Sendable {
        var date: Date
        var duration: TimeInterval
        /// A background wake with the display off ("DarkWake"), as opposed to a full wake.
        var isDark: Bool
        var cause: Cause
        /// The log's "due to …" text, for the curious.
        var detail: String
    }

    /// Wake-ups between `start` and `end`. Runs `pmset`, so call it off the main thread.
    static func wakes(from start: Date, to end: Date) -> [Wake] {
        guard let log = read() else { return [] }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"

        // "2026-10-20 13:37:32 +0200 DarkWake            \tDarkWake from Deep Idle [CDNP] : due to … Using BATT (Charge:80%) 5 secs"
        return log.split(separator: "\n").compactMap { line -> Wake? in
            guard line.contains("Wake"), let tab = line.firstIndex(of: "\t") else { return nil }
            let header = line[..<tab].split(separator: " ")
            guard header.count == 4, header[3] == "Wake" || header[3] == "DarkWake",
                  let date = formatter.date(from: header[0...2].joined(separator: " ")),
                  date >= start, date <= end
            else { return nil }

            let message = String(line[line.index(after: tab)...])
            let detail = Self.reason(in: message)
            return Wake(
                date: date,
                duration: Self.seconds(in: message),
                isDark: header[3] == "DarkWake",
                cause: Self.cause(of: detail),
                detail: detail
            )
        }
    }

    private static func read() -> String? {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/pmset")
        process.arguments = ["-g", "log"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }

    /// The text between "due to " and " Using", without register values like "(0x70070000)".
    private static func reason(in message: String) -> String {
        guard let dueTo = message.range(of: "due to ") else { return message }
        var reason = String(message[dueTo.upperBound...])
        if let using = reason.range(of: " Using ") { reason = String(reason[..<using.lowerBound]) }
        return reason.replacing(#/\(0x[0-9a-fA-F]+\)/#, with: "").trimmingCharacters(in: .whitespaces)
    }

    /// The trailing "5 secs" is how long the wake lasted.
    private static func seconds(in message: String) -> TimeInterval {
        guard let match = message.firstMatch(of: #/(\d+) secs\s*$/#) else { return 0 }
        return TimeInterval(match.1) ?? 0
    }

    private static func cause(of reason: String) -> Cause {
        let reason = reason.lowercased()
        if ["useractivity", "pwrbtn", "lid", "keyboard", "hid activity"].contains(where: reason.contains) { return .user }
        if reason.contains("maintenance") { return .maintenance }
        if reason.contains("sleepservice") { return .backgroundTasks }
        if ["wifibt", "arpt", "e_tko", "e_rx", "wlan", "network"].contains(where: reason.contains) { return .network }
        if ["_plug", "externalpowerchange"].contains(where: reason.contains) { return .accessory }
        if reason.contains("notification") { return .notification }
        return .other
    }
}
