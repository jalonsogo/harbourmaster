// AppDelegate.swift
// HarbourMaster
//
// Sets up the NSStatusItem and builds the port menu.

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    // MARK: - Properties

    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var lastPorts: [PortInfo] = []
    private var previousPortSet: Set<Int> = []
    private var pollingTimer: DispatchSourceTimer?

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = menuBarIcon()
            button.toolTip = "HarbourMaster – TCP port monitor"
        }

        menu.delegate = self
        statusItem.menu = menu


        // Initial scan in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = PortScanner.scan()
            DispatchQueue.main.async {
                self?.lastPorts = result.ports
                self?.previousPortSet = Set(result.ports.map { $0.port })
                self?.buildMenu(ports: result.ports)
                self?.updateStatusBarIcon(ports: result.ports)
                self?.startPolling()
            }
        }
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        // Show cached results immediately
        buildMenu(ports: lastPorts)
        // Scan in background, then refresh
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = PortScanner.scan()
            DispatchQueue.main.async {
                self?.lastPorts = result.ports
                self?.buildMenu(ports: result.ports)
                self?.checkForPortChanges(newPorts: result.ports)
                self?.updateStatusBarIcon(ports: result.ports)
            }
        }
    }

    // MARK: - Notifications

    private func checkForPortChanges(newPorts: [PortInfo]) {
        guard AppSettings.shared.notificationsEnabled else { return }
        let newPortSet = Set(newPorts.map { $0.port })

        let opened = newPortSet.subtracting(previousPortSet)
        let closed  = previousPortSet.subtracting(newPortSet)

        for port in opened {
            let name = newPorts.first(where: { $0.port == port })?.processName ?? "process"
            HUDNotification.show(title: "\(name) started on :\(port)",
                                 body: "A new service is listening on localhost:\(port)",
                                 opened: true)
        }
        for port in closed {
            HUDNotification.show(title: ":\(port) closed",
                                 body: "The service on localhost:\(port) stopped listening",
                                 opened: false)
        }

        previousPortSet = newPortSet
    }


    // MARK: - Background polling

    private func startPolling() {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .background))
        timer.schedule(deadline: .now() + 5, repeating: 5)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let result = PortScanner.scan()
            DispatchQueue.main.async {
                self.lastPorts = result.ports
                self.checkForPortChanges(newPorts: result.ports)
                self.updateStatusBarIcon(ports: result.ports)
            }
        }
        timer.resume()
        pollingTimer = timer
    }

    // MARK: - Status bar icon

    private func menuBarIcon() -> NSImage {
        if let img = NSImage(named: "MenuBaricon") {
            img.size = NSSize(width: 18, height: 18)
            img.isTemplate = true
            return img
        }
        let img = NSImage(systemSymbolName: "network", accessibilityDescription: "HarbourMaster") ?? NSImage()
        img.isTemplate = true
        return img
    }

    private func updateStatusBarIcon(ports: [PortInfo]) {
        statusItem.button?.image = menuBarIcon()
    }

    // MARK: - Menu building

    private func buildMenu(ports: [PortInfo]) {
        menu.removeAllItems()

        // ── Header ──────────────────────────────────────────────────────────
        let titleItem = NSMenuItem(title: "HarbourMaster", action: nil, keyEquivalent: "")
        titleItem.image = sfSymbol("anchor")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())

        if ports.isEmpty {
            let emptyItem = NSMenuItem(title: "No ports in use", action: nil, keyEquivalent: "")
            emptyItem.image = sfSymbol("checkmark.circle")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            let systemPorts = ports.filter { $0.isSystemProcess }
            let dockerPorts = ports.filter { !$0.isSystemProcess && $0.dockerContainer != nil }
            let userPorts   = ports.filter { !$0.isSystemProcess && $0.dockerContainer == nil }

            let devPorts   = userPorts.filter { $0.isDevPort }
            let otherPorts = userPorts.filter { !$0.isDevPort }

            // ── Dev Ports ────────────────────────────────────────────────────
            if !devPorts.isEmpty {
                addSectionHeader("Dev Ports", to: menu)
                devPorts.forEach { addPortItem($0, to: menu) }
            }

            // ── Docker — one line per compose project ────────────────────────
            if !dockerPorts.isEmpty && AppSettings.shared.showDockerSection {
                if !devPorts.isEmpty { menu.addItem(.separator()) }
                addSectionHeader("Docker", to: menu)

                // Build ordered project map
                var projectMap: [(key: String, ports: [PortInfo])] = []
                var seen = Set<String>()
                for p in dockerPorts {
                    let key = p.dockerContainer?.composeProject ?? ""
                    if !seen.contains(key) { seen.insert(key); projectMap.append((key, [])) }
                }
                projectMap = projectMap.map { entry in
                    (key: entry.key, ports: dockerPorts.filter {
                        ($0.dockerContainer?.composeProject ?? "") == entry.key
                    })
                }

                for entry in projectMap {
                    if entry.key.isEmpty {
                        // Standalone containers — inline, no submenu wrapper
                        entry.ports.forEach { addPortItem($0, to: menu) }
                    } else {
                        // Compose project → one submenu item, chevron on right
                        let projectItem = NSMenuItem(
                            title: "\(entry.key)  (\(entry.ports.count))",
                            action: nil,
                            keyEquivalent: ""
                        )
                        projectItem.image = sfSymbol("square.stack")
                        let projectSubmenu = NSMenu()
                        entry.ports.forEach { addPortItem($0, to: projectSubmenu) }
                        projectItem.submenu = projectSubmenu
                        menu.addItem(projectItem)
                    }
                }

            }

            // ── Other (submenu with System + Other groups) ───────────────────
            if !otherPorts.isEmpty || !systemPorts.isEmpty {
                if !devPorts.isEmpty || !dockerPorts.isEmpty { menu.addItem(.separator()) }

                let total = otherPorts.count + systemPorts.count
                let otherItem = NSMenuItem(title: "Other (\(total))", action: nil, keyEquivalent: "")
                otherItem.image = sfSymbol("network")

                let otherSubmenu = NSMenu()

                if !systemPorts.isEmpty {
                    addSectionHeader("System", to: otherSubmenu)
                    systemPorts.forEach { addPortItem($0, to: otherSubmenu) }
                }

                if !otherPorts.isEmpty {
                    if !systemPorts.isEmpty { otherSubmenu.addItem(.separator()) }
                    addSectionHeader("Other", to: otherSubmenu)
                    otherPorts.forEach { addPortItem($0, to: otherSubmenu) }
                }

                otherItem.submenu = otherSubmenu
                menu.addItem(otherItem)
            }
        }

        // ── Bottom controls ──────────────────────────────────────────────────
        menu.addItem(.separator())

        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshMenu), keyEquivalent: "r")
        refreshItem.image = sfSymbol("arrow.clockwise")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.image = sfSymbol("gearshape")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit HarbourMaster", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.image = sfSymbol("power")
        menu.addItem(quitItem)
    }

    // MARK: - Menu item helpers

    private func addSectionHeader(_ title: String, to targetMenu: NSMenu) {
        let header = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        header.isEnabled = false
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        header.attributedTitle = NSAttributedString(string: title, attributes: attrs)
        targetMenu.addItem(header)
    }

    /// Compose project sub-header — slightly indented, monospaced, with a stack icon.
    private func addProjectHeader(_ project: String, to targetMenu: NSMenu) {
        let header = NSMenuItem(title: project, action: nil, keyEquivalent: "")
        header.image = sfSymbol("square.stack")
        header.isEnabled = false
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        header.attributedTitle = NSAttributedString(string: project, attributes: attrs)
        targetMenu.addItem(header)
    }

    private func addPortItem(_ info: PortInfo, to targetMenu: NSMenu) {
        let item = NSMenuItem(title: info.displayTitle, action: nil, keyEquivalent: "")
        if info.isSystemProcess {
            item.image = sfSymbol("shield.fill", color: .systemOrange)
        } else if info.isDockerPort {
            let dockerColor: NSColor = (info.dockerContainer?.isPaused == true) ? .secondaryLabelColor : .systemGreen
            item.image = sfSymbol("shippingbox.fill", color: dockerColor)
        } else {
            item.image = sfSymbol("circle.fill", color: info.isDevPort ? .systemGreen : .systemBlue)
        }

        let sub = NSMenu()

        // ── Open in Browser — always first ───────────────────────────────────
        let browserItem = NSMenuItem(title: "Open http://localhost:\(info.port)", action: #selector(openInBrowser(_:)), keyEquivalent: "")
        browserItem.image = sfSymbol("globe")
        browserItem.target = self
        browserItem.representedObject = info
        sub.addItem(browserItem)

        // ── Copy URL ─────────────────────────────────────────────────────────
        let copyURLItem = NSMenuItem(title: "Copy URL", action: #selector(copyURL(_:)), keyEquivalent: "")
        copyURLItem.image = sfSymbol("doc.on.clipboard")
        copyURLItem.target = self
        copyURLItem.representedObject = info
        sub.addItem(copyURLItem)
        sub.addItem(.separator())

        // ── Resource usage ───────────────────────────────────────────────────
        // For Docker containers, prefer container-level stats
        if let c = info.dockerContainer, let cpu = c.containerCPU, let mem = c.containerMem {
            let resItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            resItem.image = sfSymbol("cpu")
            resItem.isEnabled = false
            resItem.attributedTitle = labeledString(label: "Resources", value: "CPU \(cpu)   RAM \(mem)")
            sub.addItem(resItem)
            sub.addItem(.separator())
        } else if let cpu = info.cpuPercent, let mem = info.memoryMB {
            let resItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            resItem.image = sfSymbol("cpu")
            resItem.isEnabled = false
            resItem.attributedTitle = labeledString(label: "Resources", value: "CPU \(String(format: "%.1f", cpu))%   RAM \(String(format: "%.1f", mem)) MB")
            sub.addItem(resItem)
            sub.addItem(.separator())
        }

        // ── Docker container info — click any row to copy its value ──────────
        if let c = info.dockerContainer {
            func copyItem(label: String, value: String, symbol: String) -> NSMenuItem {
                let item = NSMenuItem(title: value, action: #selector(copyStringValue(_:)), keyEquivalent: "")
                item.image = sfSymbol(symbol)
                item.target = self
                item.representedObject = value
                item.attributedTitle = labeledString(label: label, value: value)
                return item
            }

            sub.addItem(copyItem(label: "Container", value: c.name,  symbol: "cube"))
            sub.addItem(copyItem(label: "Image",     value: c.image, symbol: "photo.stack"))
            if let project = c.composeProject {
                sub.addItem(copyItem(label: "Project", value: project, symbol: "square.stack"))
            }
            sub.addItem(copyItem(label: "Port", value: "\(c.hostPort) → \(c.containerPort)/\(c.proto)", symbol: "arrow.right.circle"))

            // Open in container manager
            let ddItem = NSMenuItem(title: "Open in Docker Desktop", action: #selector(openInDockerDesktop(_:)), keyEquivalent: "")
            ddItem.image = sfSymbol("arrow.up.forward.app")
            ddItem.target = self
            ddItem.representedObject = info
            sub.addItem(ddItem)

            sub.addItem(.separator())
        }

        // ── Folder actions (only if cwd is available) ────────────────────────
        if let cwd = info.cwd {
            let pathAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ]

            let finderItem = NSMenuItem(title: cwd, action: #selector(revealInFinder(_:)), keyEquivalent: "")
            finderItem.image = sfSymbol("folder")
            finderItem.target = self
            finderItem.representedObject = info
            finderItem.attributedTitle = NSAttributedString(string: cwd, attributes: pathAttrs)
            sub.addItem(finderItem)

            let termItem = NSMenuItem(title: "Open in Terminal", action: #selector(openInTerminal(_:)), keyEquivalent: "")
            termItem.image = sfSymbol("terminal")
            termItem.target = self
            termItem.representedObject = info
            sub.addItem(termItem)

            let copyPathItem = NSMenuItem(title: "Copy Path", action: #selector(copyPath(_:)), keyEquivalent: "")
            copyPathItem.image = sfSymbol("doc.on.doc")
            copyPathItem.target = self
            copyPathItem.representedObject = info
            sub.addItem(copyPathItem)

            sub.addItem(.separator())
        }

        // ── Docker container controls / process kill ─────────────────────────
        if let c = info.dockerContainer {
            let restartItem = NSMenuItem(title: "Restart", action: #selector(dockerRestart(_:)), keyEquivalent: "")
            restartItem.image = sfSymbol("arrow.clockwise")
            restartItem.target = self
            restartItem.representedObject = info
            sub.addItem(restartItem)

            let pauseTitle  = c.isPaused ? "Unpause" : "Pause"
            let pauseSymbol = c.isPaused ? "play" : "pause"
            let pauseAction = c.isPaused ? #selector(dockerUnpause(_:)) : #selector(dockerPause(_:))
            let pauseItem   = NSMenuItem(title: pauseTitle, action: pauseAction, keyEquivalent: "")
            pauseItem.image = sfSymbol(pauseSymbol)
            pauseItem.target = self
            pauseItem.representedObject = info
            sub.addItem(pauseItem)

            let stopItem = NSMenuItem(title: "Stop", action: #selector(dockerStop(_:)), keyEquivalent: "")
            stopItem.image = sfSymbol("stop", color: .systemOrange)
            stopItem.target = self
            stopItem.representedObject = info
            sub.addItem(stopItem)

            sub.addItem(.separator())

            let logsItem = NSMenuItem(title: "View Container Logs", action: #selector(dockerLogs(_:)), keyEquivalent: "")
            logsItem.image = sfSymbol("text.alignleft")
            logsItem.target = self
            logsItem.representedObject = info
            sub.addItem(logsItem)

            if c.composeProject != nil {
                let projectLogsItem = NSMenuItem(title: "View Project Logs", action: #selector(dockerProjectLogs(_:)), keyEquivalent: "")
                projectLogsItem.image = sfSymbol("text.alignleft")
                projectLogsItem.target = self
                projectLogsItem.representedObject = info
                sub.addItem(projectLogsItem)
            }

            // ── Open Shell ───────────────────────────────────────────────────
            let shellItem = NSMenuItem(title: "Open Shell", action: #selector(dockerExec(_:)), keyEquivalent: "")
            shellItem.image = sfSymbol("terminal")
            shellItem.target = self
            shellItem.representedObject = info
            sub.addItem(shellItem)
        } else {
            let killItem = NSMenuItem(title: "Kill Process (PID \(info.pid))", action: #selector(killProcess(_:)), keyEquivalent: "")
            killItem.image = sfSymbol("xmark.circle", color: .systemRed)
            killItem.target = self
            killItem.representedObject = info
            sub.addItem(killItem)
        }

        item.submenu = sub
        targetMenu.addItem(item)
    }

    // MARK: - Actions

    @objc private func refreshMenu() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = PortScanner.scan()
            DispatchQueue.main.async {
                self?.lastPorts = result.ports
                self?.buildMenu(ports: result.ports)
                self?.updateStatusBarIcon(ports: result.ports)
            }
        }
    }

    @objc private func openInDockerDesktop(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? PortInfo,
              let c = info.dockerContainer else { return }
        AppSettings.shared.openContainerInManager(c, fallbackPort: info.port)
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func openInBrowser(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? PortInfo,
              let url = URL(string: "http://localhost:\(info.port)") else { return }
        AppSettings.shared.openURL(url)
    }

    @objc private func copyURL(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? PortInfo else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString("http://localhost:\(info.port)", forType: .string)
    }

    @objc private func revealInFinder(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? PortInfo, let cwd = info.cwd else { return }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: cwd)
    }

    @objc private func openInTerminal(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? PortInfo, let cwd = info.cwd else { return }
        AppSettings.shared.openTerminal(at: cwd)
    }

    @objc private func copyStringValue(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    @objc private func copyPath(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? PortInfo, let cwd = info.cwd else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(cwd, forType: .string)
    }

    // MARK: - Docker actions

    @objc private func dockerStop(_ sender: NSMenuItem) {
        guard let c = (sender.representedObject as? PortInfo)?.dockerContainer else { return }
        DispatchQueue.global().async { DockerScanner.stop(c) }
        scheduleRefresh()
    }

    @objc private func dockerPause(_ sender: NSMenuItem) {
        guard let c = (sender.representedObject as? PortInfo)?.dockerContainer else { return }
        DispatchQueue.global().async { DockerScanner.pause(c) }
        scheduleRefresh()
    }

    @objc private func dockerUnpause(_ sender: NSMenuItem) {
        guard let c = (sender.representedObject as? PortInfo)?.dockerContainer else { return }
        DispatchQueue.global().async { DockerScanner.unpause(c) }
        scheduleRefresh()
    }

    @objc private func dockerRestart(_ sender: NSMenuItem) {
        guard let c = (sender.representedObject as? PortInfo)?.dockerContainer else { return }
        DispatchQueue.global().async { DockerScanner.restart(c) }
        scheduleRefresh()
    }

    @objc private func dockerLogs(_ sender: NSMenuItem) {
        guard let c = (sender.representedObject as? PortInfo)?.dockerContainer else { return }
        AppSettings.shared.runCommandInTerminal(DockerScanner.logsCommand(for: c))
    }

    @objc private func dockerProjectLogs(_ sender: NSMenuItem) {
        guard let c = (sender.representedObject as? PortInfo)?.dockerContainer,
              let cmd = DockerScanner.composeLogsCommand(for: c) else { return }
        AppSettings.shared.runCommandInTerminal(cmd)
    }

    @objc private func dockerExec(_ sender: NSMenuItem) {
        guard let c = (sender.representedObject as? PortInfo)?.dockerContainer else { return }
        AppSettings.shared.runCommandInTerminal("docker exec -it \(c.name) /bin/sh")
    }

    private func scheduleRefresh() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.refreshMenu()
        }
    }

    @objc private func killProcess(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? PortInfo else { return }

        if info.isSystemProcess {
            let alert = NSAlert()
            alert.messageText = "Kill macOS system process?"
            alert.informativeText = "\"\(info.processName)\" (PID \(info.pid)) appears to be a macOS system service. Killing it may disrupt system features like AirPlay, Handoff, or Sharing.\n\nAre you sure?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Kill Anyway")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        kill(pid_t(info.pid), SIGTERM)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refreshMenu()
        }
    }

    // MARK: - SF Symbols helper

    /// Builds an attributed string with a small dimmed label prefix and a normal-weight value.
    /// e.g.  "Container  my-app-web-1"
    private func labeledString(label: String, value: String) -> NSAttributedString {
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor.labelColor
        ]
        let result = NSMutableAttributedString(string: "\(label)  ", attributes: labelAttrs)
        result.append(NSAttributedString(string: value, attributes: valueAttrs))
        return result
    }

    private func sfSymbol(_ name: String, color: NSColor? = nil) -> NSImage? {
        if let color {
            let config = NSImage.SymbolConfiguration(paletteColors: [color])
            return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(config)
        } else {
            let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)
            img?.isTemplate = true
            return img
        }
    }
}
