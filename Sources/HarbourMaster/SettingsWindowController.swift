// SettingsWindowController.swift
// HarbourMaster

import AppKit
import SwiftUI

// MARK: - Tab state

final class SettingsTabState: ObservableObject {
    @Published var selected: SettingsTab = .general
}

enum SettingsTab: String, CaseIterable {
    case general  = "General"
    case docker   = "Docker"
    case devPorts = "Dev Ports"
    case legend   = "Legend"

    var icon: String {
        switch self {
        case .general:  return "gearshape"
        case .docker:   return "shippingbox"
        case .devPorts: return "network"
        case .legend:   return "info.circle"
        }
    }

    var toolbarID: NSToolbarItem.Identifier { .init(rawValue) }
}

// MARK: - Window controller

final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    let tabState = SettingsTabState()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 400),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "HarbourMaster"
        window.center()
        window.setFrameAutosaveName("HarbourMasterSettings")

        super.init(window: window)

        // Toolbar
        let toolbar = NSToolbar(identifier: "SettingsToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.selectedItemIdentifier = SettingsTab.general.toolbarID
        window.toolbar = toolbar
        window.toolbarStyle = .preference   // ← System Settings look

        updateContent()
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func updateContent() {
        let view = SettingsContentView()
            .environmentObject(tabState)
        window?.contentView = NSHostingView(rootView: view)
    }
}

// MARK: - NSToolbarDelegate

extension SettingsWindowController: NSToolbarDelegate {

    func toolbar(_ toolbar: NSToolbar,
                 itemForItemIdentifier id: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar: Bool) -> NSToolbarItem? {
        guard let tab = SettingsTab.allCases.first(where: { $0.toolbarID == id }) else { return nil }

        let item = NSToolbarItem(itemIdentifier: id)
        item.label = tab.rawValue
        item.image = NSImage(systemSymbolName: tab.icon, accessibilityDescription: tab.rawValue)
        item.target = self
        item.action = #selector(switchTab(_:))
        return item
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        SettingsTab.allCases.map(\.toolbarID)
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        SettingsTab.allCases.map(\.toolbarID)
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        SettingsTab.allCases.map(\.toolbarID)
    }

    @objc private func switchTab(_ sender: NSToolbarItem) {
        guard let tab = SettingsTab.allCases.first(where: { $0.toolbarID == sender.itemIdentifier }) else { return }
        tabState.selected = tab
        window?.toolbar?.selectedItemIdentifier = tab.toolbarID
        window?.title = "HarbourMaster – \(tab.rawValue)"
    }
}
