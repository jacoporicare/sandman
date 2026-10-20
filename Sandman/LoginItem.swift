//
//  LoginItem.swift
//  Sandman
//
//  Created by Jakub Řičař on 20.10.2026.
//

import Foundation
import Observation
import ServiceManagement

/// Whether Sandman opens when you log in, through the system's Login Items.
@Observable
final class LoginItem {
    private(set) var status = SMAppService.mainApp.status
    /// Why the last change failed, if it did.
    private(set) var errorMessage: String?

    var isEnabled: Bool { status == .enabled }
    /// Registered, but switched off in System Settings › General › Login Items.
    var needsApproval: Bool { status == .requiresApproval }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }

    /// You can change this in System Settings at any time, so re-read it before showing it.
    func refresh() {
        let current = SMAppService.mainApp.status
        if current != status { status = current }
    }
}
