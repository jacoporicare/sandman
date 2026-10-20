//
//  SleepAssertion.swift
//  Sandman
//
//  Created by Jakub Řičař on 20.10.2026.
//

import CoreAudio
import Foundation
import IOKit.pwr_mgt

/// One power assertion as reported by powerd — the same data `pmset -g assertions` prints.
struct SleepAssertion: Identifiable, Equatable {
    enum Kind: Int, Comparable {
        /// Keeps the display on, and with it the whole Mac.
        case display
        /// Keeps the Mac awake; the display may still turn off.
        case system
        /// System bookkeeping that doesn't block idle sleep on its own.
        case background

        static func < (lhs: Kind, rhs: Kind) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    let id: Int
    let pid: pid_t
    let processName: String
    /// Set when a daemon holds the assertion for another process, e.g. coreaudiod for a music player.
    let onBehalfOfPID: pid_t?
    let type: String
    let kind: Kind
    /// A readable reason, e.g. "Playing audio on MacBook Pro Speakers".
    let name: String
    /// The name exactly as the process gave it.
    let rawName: String
    let details: String?
    let startedAt: Date?
    let expiresAt: Date?

    /// Reads every active assertion from powerd, or returns nil when powerd can't be queried.
    static func readAll() -> [SleepAssertion]? {
        var unmanaged: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&unmanaged) == kIOReturnSuccess else { return nil }
        let byPID = unmanaged?.takeRetainedValue() as? [NSNumber: [[String: Any]]] ?? [:]

        return byPID.flatMap { pid, assertions in
            assertions.compactMap { SleepAssertion(pid: pid.int32Value, dictionary: $0) }
        }
    }

    init?(pid: pid_t, dictionary d: [String: Any]) {
        // A level of 0 means the assertion still exists but is currently released.
        guard (d["AssertLevel"] as? Int ?? 0) > 0 else { return nil }

        self.pid = pid
        processName = d["Process Name"] as? String ?? "Process \(pid)"
        // AssertionTrueType normalises legacy names like NoIdleSleepAssertion.
        type = d["AssertionTrueType"] as? String ?? d["AssertType"] as? String ?? "Unknown"
        rawName = Self.nonEmpty(d["AssertName"]) ?? Self.nonEmpty(d["HumanReadableReason"]) ?? type
        name = Self.readableName(rawName, resources: d["ResourcesUsed"] as? [String] ?? [])
        details = Self.nonEmpty(d["Details"]) ?? Self.nonEmpty(d["AssertionOnBehalfOfPIDReason"])
        startedAt = d["AssertStartWhen"] as? Date
        id = d["GlobalUniqueID"] as? Int ?? d["AssertionId"] as? Int ?? "\(pid)-\(type)-\(name)".hashValue

        let behalf = d["AssertionOnBehalfOfPID"] as? Int32 ?? 0
        onBehalfOfPID = behalf > 0 && behalf != pid ? behalf : nil

        if let updated = d["AssertTimeoutUpdateTime"] as? Date,
           let left = d["AssertTimeoutTimeLeft"] as? Double, left > 0 {
            expiresAt = updated.addingTimeInterval(left)
        } else {
            expiresAt = nil
        }

        kind = Self.kind(type: type, processName: processName, name: rawName)
    }

    private static func readableName(_ raw: String, resources: [String]) -> String {
        if raw.hasPrefix("com.apple.audio.") { return audioName(resources: resources) }

        // runningboardd: "app<application.net.whatsapp.WhatsApp.…>…:Shared Background Assertion 3474 for
        // net.whatsapp.WhatsApp(FinishTask)" — an app finishing work after you switched away from it.
        if raw.hasPrefix("app<"), let colon = raw.firstIndex(of: ":") {
            if raw.hasSuffix("(FinishTask)") { return "Finishing a background task" }
            return String(raw[raw.index(after: colon)...])
        }
        return raw
    }

    /// coreaudiod names its assertions after a device UID ("com.apple.audio.BuiltInSpeakerDevice.context.
    /// preventuseridlesleep") and lists what it uses in ResourcesUsed, e.g. ["audio-out", "BuiltInSpeakerDevice"].
    private static func audioName(resources: [String]) -> String {
        let isInput = resources.contains("audio-in")
        let device = resources
            .filter { $0 != "audio-in" && $0 != "audio-out" }
            .compactMap { AudioDeviceNames.name(uid: $0) }
            .first
        switch (isInput, device) {
        case (true, let device?): return "Using audio input from \(device)"
        case (true, nil): return "Using audio input"
        case (false, let device?): return "Playing audio on \(device)"
        case (false, nil): return "Playing audio"
        }
    }

    private static func kind(type: String, processName: String, name: String) -> Kind {
        // powerd mirrors "the display is on" into a system-sleep assertion. The real cause is
        // whatever keeps the display on (you, or a display assertion), so it isn't a blocker itself.
        if processName == "powerd", name.hasPrefix("Powerd - Prevent sleep while display is on") {
            return .background
        }
        switch type {
        case "PreventUserIdleDisplaySleep", "NoDisplaySleepAssertion", "InternalPreventDisplaySleep":
            return .display
        case "PreventUserIdleSystemSleep", "NoIdleSleepAssertion", "PreventSystemSleep",
             "DenySystemSleep", "InternalPreventSleep":
            return .system
        default:
            return .background
        }
    }

    private static func nonEmpty(_ value: Any?) -> String? {
        guard let string = value as? String, !string.isEmpty else { return nil }
        return string
    }
}

/// Looks up audio device names by UID, e.g. "BuiltInSpeakerDevice" → "MacBook Pro Speakers".
private enum AudioDeviceNames {
    private static var cache: [String: String?] = [:]

    static func name(uid: String) -> String? {
        if let cached = cache[uid] { return cached }
        let name = lookup(uid: uid)
        cache[uid] = name
        return name
    }

    private static func lookup(uid: String) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslateUIDToDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let cfUID = uid as CFString
        var deviceID = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = withUnsafePointer(to: cfUID) { uidPointer in
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject), &address,
                UInt32(MemoryLayout<CFString>.size), uidPointer, &size, &deviceID
            )
        }
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }

        address.mSelector = kAudioObjectPropertyName
        var name: Unmanaged<CFString>?
        size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &name) == noErr else { return nil }
        return name?.takeRetainedValue() as String?
    }
}
