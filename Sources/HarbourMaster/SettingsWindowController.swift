// SettingsWindowController.swift
// HarbourMaster

import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {

    static let shared = SettingsWindowController()

    private init() {
        let hostingView = NSHostingView(rootView: SettingsView())

        let window = NSPanel(
            contentRect: .zero,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "HarbourMaster Settings"
        window.contentView = hostingView
        window.center()
        window.setFrameAutosaveName("HarbourMasterSettings")
        window.isMovableByWindowBackground = true
        window.level = .floating

        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
