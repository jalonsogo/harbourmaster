// HUDNotification.swift
// HarbourMaster
//
// Floating toast using native NSVisualEffectView HUD material.

import AppKit

final class HUDNotification {

    static func show(title: String, body: String, opened: Bool) {
        DispatchQueue.main.async { _show(title: title, body: body, opened: opened) }
    }

    private static func _show(title: String, body: String, opened: Bool) {
        let width:  CGFloat = 320
        let height: CGFloat = 68
        let margin: CGFloat = 12

        guard let screen = NSScreen.main else { return }

        // Position below the menu bar, right-aligned
        let menuBarHeight: CGFloat = NSStatusBar.system.thickness + 8
        let x = screen.frame.maxX - width - margin
        let y = screen.frame.maxY - menuBarHeight - height - margin

        let panel = NSPanel(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask:   [.borderless, .nonactivatingPanel],
            backing:     .buffered,
            defer:       false
        )
        panel.backgroundColor    = .clear
        panel.isOpaque           = false
        panel.level              = .screenSaver   // above everything including menu bar
        panel.hasShadow          = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Frosted glass background
        let blur = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        blur.material    = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state       = .active
        blur.wantsLayer  = true
        blur.layer?.cornerRadius = 12
        blur.layer?.masksToBounds = true

        // Icon
        let iconColor: NSColor = opened ? .systemGreen : .tertiaryLabelColor
        let iconConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .bold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [iconColor]))
        let iconImage = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(iconConfig)
        let iconView = NSImageView(frame: NSRect(x: 16, y: (height - 14) / 2, width: 14, height: 14))
        iconView.image = iconImage

        // Title
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font      = .boldSystemFont(ofSize: 13)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.frame = NSRect(x: 38, y: height / 2 + 2, width: width - 50, height: 17)

        // Body
        let bodyLabel = NSTextField(labelWithString: body)
        bodyLabel.font      = .systemFont(ofSize: 11)
        bodyLabel.textColor = .secondaryLabelColor
        bodyLabel.lineBreakMode = .byTruncatingTail
        bodyLabel.frame = NSRect(x: 38, y: height / 2 - 16, width: width - 50, height: 15)

        blur.addSubview(iconView)
        blur.addSubview(titleLabel)
        blur.addSubview(bodyLabel)
        panel.contentView = blur

        panel.alphaValue = 0
        panel.orderFront(nil)

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = 1
        }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration = 0.4
                    panel.animator().alphaValue = 0
                }) {
                    panel.close()
                }
            }
        }
    }
}
