//
//  ProcessIdentity.swift
//  Sandman
//
//  Created by Jakub Řičař on 20.10.2026.
//

import AppKit
import UniformTypeIdentifiers

/// The app or process behind an assertion, resolved to something a person would recognise.
/// Helper processes (Chrome Helper, Electron renderers, …) are folded into their parent app.
struct ProcessIdentity: Equatable {
    /// Bundle path for apps, so all of an app's helpers group together; `pid:<n>` otherwise.
    let id: String
    let pid: pid_t
    let name: String
    /// The outermost `.app` bundle for apps, the executable otherwise.
    let path: String?
    let bundleIdentifier: String?
    let isApp: Bool
    /// Part of macOS itself (daemons, command-line tools), as opposed to an app you installed or opened.
    let isSystem: Bool
    /// Runs as you, and wasn't started by launchd as a macOS service (launchd would just restart it,
    /// and some of them, like loginwindow, end your session when killed).
    private let isUserProcess: Bool
    let icon: NSImage

    init(pid: pid_t, processName: String?) {
        self.pid = pid
        let executable = Self.executablePath(of: pid)

        if let executable, let appSuffix = executable.range(of: ".app/") {
            let bundlePath = String(executable[..<appSuffix.lowerBound]) + ".app"
            id = bundlePath
            name = FileManager.default.displayName(atPath: bundlePath)
            path = bundlePath
            bundleIdentifier = Bundle(path: bundlePath)?.bundleIdentifier
            isApp = true
        } else {
            id = "pid:\(pid)"
            name = processName ?? executable.map { URL(filePath: $0).lastPathComponent } ?? "Process \(pid)"
            path = executable
            bundleIdentifier = nil
            isApp = false
        }

        let isSystem = path.map(Self.isSystemPath) ?? false
        self.isSystem = isSystem
        isUserProcess = Self.bsdInfo(of: pid).map { $0.pbi_uid == getuid() && !(isSystem && $0.pbi_ppid == 1) } ?? false
        icon = path.map { NSWorkspace.shared.icon(forFile: $0) } ?? NSWorkspace.shared.icon(for: .unixExecutable)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.path == rhs.path
    }

    /// Whether Sandman offers to quit this app or process.
    var canQuit: Bool {
        isApp ? runningApplication != nil : isUserProcess
    }

    /// Asks the app to quit, or sends a plain process SIGTERM.
    func quit() {
        if isApp { runningApplication?.terminate() } else { send(SIGTERM) }
    }

    func forceQuit() {
        if isApp { runningApplication?.forceTerminate() } else { send(SIGKILL) }
    }

    private var runningApplication: NSRunningApplication? {
        guard isApp, !isSystem, let bundleIdentifier else { return nil }
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .first { $0 != .current }
    }

    private func send(_ signal: Int32) {
        // The pid may have been reused since it was resolved; only signal the same executable.
        guard isUserProcess, let path, Self.executablePath(of: pid) == path else { return }
        kill(pid, signal)
    }

    nonisolated private static func executablePath(of pid: pid_t) -> String? {
        var buffer = [UInt8](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(decoding: buffer.prefix(Int(length)), as: UTF8.self)
    }

    nonisolated private static func bsdInfo(of pid: pid_t) -> proc_bsdinfo? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        return info
    }

    nonisolated private static func isSystemPath(_ path: String) -> Bool {
        // Apple's own apps (Music, Safari, …) live under /System but are still apps you use.
        if path.contains("/System/Applications/") || path.hasPrefix("/usr/local/") { return false }
        return ["/System/", "/usr/", "/bin/", "/sbin/", "/Library/Apple/"].contains { path.hasPrefix($0) }
    }
}
