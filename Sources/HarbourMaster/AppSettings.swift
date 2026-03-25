// AppSettings.swift
// HarbourMaster
//
// Persistent settings backed by UserDefaults.

import AppKit
import ServiceManagement

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // MARK: - Stored properties

    @Published var launchAtLogin: Bool {
        didSet { applyLoginItem() }
    }

    @Published var browserChoice: BrowserChoice {
        didSet { UserDefaults.standard.set(browserChoice.rawValue, forKey: Keys.browser) }
    }

    @Published var terminalChoice: TerminalChoice {
        didSet { UserDefaults.standard.set(terminalChoice.rawValue, forKey: Keys.terminal) }
    }

    @Published var containerManager: ContainerManager {
        didSet { UserDefaults.standard.set(containerManager.rawValue, forKey: Keys.containerManager) }
    }

    @Published var showDockerSection: Bool {
        didSet { UserDefaults.standard.set(showDockerSection, forKey: Keys.showDockerSection) }
    }

    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }

    @Published var customDevPorts: Set<Int> {
        didSet { UserDefaults.standard.set(Array(customDevPorts), forKey: Keys.customDevPorts) }
    }

    @Published var customDevPortRanges: [DevPortRange] {
        didSet {
            let encoded = customDevPortRanges.map { [$0.lower, $0.upper] }
            UserDefaults.standard.set(encoded, forKey: Keys.customDevPortRanges)
        }
    }

    /// Returns ports from the individual list that fall inside any stored range.
    func portsSubsumedByRanges() -> Set<Int> {
        customDevPorts.filter { port in
            customDevPortRanges.contains(where: { $0.contains(port) })
        }
    }

    /// Returns ranges that overlap with a candidate range (excluding itself).
    func rangesOverlapping(_ candidate: DevPortRange) -> [DevPortRange] {
        customDevPortRanges.filter { $0.overlaps(candidate) }
    }

    // MARK: - Init

    private init() {
        let ud = UserDefaults.standard
        browserChoice      = BrowserChoice(rawValue:      ud.string(forKey: Keys.browser)         ?? "") ?? .default
        terminalChoice     = TerminalChoice(rawValue:     ud.string(forKey: Keys.terminal)        ?? "") ?? .default
        containerManager   = ContainerManager(rawValue:   ud.string(forKey: Keys.containerManager) ?? "") ?? .autoDetect
        showDockerSection  = ud.object(forKey: Keys.showDockerSection) as? Bool ?? true
        notificationsEnabled = ud.object(forKey: Keys.notificationsEnabled) as? Bool ?? true
        launchAtLogin      = SMAppService.mainApp.status == .enabled

        if let stored = ud.array(forKey: Keys.customDevPorts) as? [Int] {
            customDevPorts = Set(stored)
        } else {
            customDevPorts = [3000, 3001, 5173, 8080, 8000, 4000, 4200, 5001, 8888, 9000]
        }

        if let stored = ud.array(forKey: Keys.customDevPortRanges) as? [[Int]] {
            customDevPortRanges = stored.compactMap {
                guard $0.count == 2 else { return nil }
                return DevPortRange(lower: $0[0], upper: $0[1])
            }
        } else {
            customDevPortRanges = []
        }
    }

    // MARK: - Login item

    private func applyLoginItem() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Silently revert the toggle if registration fails
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    // MARK: - Actions

    func openURL(_ url: URL) {
        if browserChoice == .default {
            NSWorkspace.shared.open(url)
        } else if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browserChoice.rawValue) {
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: .init(), completionHandler: nil)
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    func runCommandInTerminal(_ command: String) {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let appleScript: String
        switch terminalChoice {
        case .iterm2:
            appleScript = """
            tell application "iTerm2"
                create window with default profile
                tell current session of current window
                    write text "\(escaped)"
                end tell
                activate
            end tell
            """
        default:
            appleScript = """
            tell application "Terminal"
                do script "\(escaped)"
                activate
            end tell
            """
        }

        // Run osascript as a subprocess — more reliable than NSAppleScript
        // inside a menu-bar app which lacks Automation entitlements by default.
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", appleScript]
        p.standardOutput = Pipe()
        p.standardError = Pipe()
        try? p.run()
    }

    func openTerminal(at path: String) {
        let dir = URL(fileURLWithPath: path)
        if terminalChoice == .default {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            p.arguments = ["-a", "Terminal", path]
            try? p.run()
        } else if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminalChoice.rawValue) {
            NSWorkspace.shared.open([dir], withApplicationAt: appURL, configuration: .init(), completionHandler: nil)
        } else {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            p.arguments = ["-a", "Terminal", path]
            try? p.run()
        }
    }

    // MARK: - Container manager deep link

    func openContainerInManager(_ container: DockerContainer, fallbackPort: Int) {
        switch containerManager.resolved {
        case .dockerDesktop:
            let url = URL(string: "docker-desktop://dashboard/containers/\(container.name)")!
            if !NSWorkspace.shared.open(url) { openLocalhost(port: fallbackPort) }
        case .orbStack:
            // OrbStack: open the app — it shows running containers on launch
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: ContainerManager.orbStack.bundleID!) {
                NSWorkspace.shared.open(appURL)
            } else {
                openLocalhost(port: fallbackPort)
            }
        case .none, .autoDetect:
            openLocalhost(port: fallbackPort)
        }
    }

    private func openLocalhost(port: Int) {
        if let url = URL(string: "http://localhost:\(port)") { openURL(url) }
    }

    // MARK: - Keys

    private enum Keys {
        static let browser              = "browserChoice"
        static let terminal             = "terminalChoice"
        static let containerManager     = "containerManager"
        static let showDockerSection    = "showDockerSection"
        static let notificationsEnabled = "notificationsEnabled"
        static let customDevPorts       = "customDevPorts"
        static let customDevPortRanges  = "customDevPortRanges"
    }
}

// MARK: - DevPortRange

struct DevPortRange: Identifiable, Equatable {
    let id = UUID()
    let lower: Int
    let upper: Int

    var displayString: String { "\(lower) – \(upper)" }

    func contains(_ port: Int) -> Bool { port >= lower && port <= upper }

    func overlaps(_ other: DevPortRange) -> Bool {
        lower <= other.upper && other.lower <= upper
    }

    /// Parse from "3000-3400" or "3000–3400"
    static func parse(_ input: String) -> DevPortRange? {
        let parts = input
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: " ", with: "")
            .components(separatedBy: "-")
        guard parts.count == 2,
              let lo = Int(parts[0]), let hi = Int(parts[1]),
              lo > 0, hi <= 65535, lo < hi else { return nil }
        return DevPortRange(lower: lo, upper: hi)
    }
}

// MARK: - Browser

enum BrowserChoice: String, CaseIterable, Identifiable {
    case `default` = "default"
    case safari    = "com.apple.Safari"
    case chrome    = "com.google.Chrome"
    case firefox   = "org.mozilla.firefox"
    case arc       = "company.thebrowser.Browser"
    case brave     = "com.brave.Browser"
    case edge      = "com.microsoft.edgemac"
    case opera     = "com.operasoftware.Opera"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .default: return "Default Browser"
        case .safari:  return "Safari"
        case .chrome:  return "Google Chrome"
        case .firefox: return "Firefox"
        case .arc:     return "Arc"
        case .brave:   return "Brave"
        case .edge:    return "Microsoft Edge"
        case .opera:   return "Opera"
        }
    }

    var isAvailable: Bool {
        self == .default || NSWorkspace.shared.urlForApplication(withBundleIdentifier: rawValue) != nil
    }
}

// MARK: - Container Manager

enum ContainerManager: String, CaseIterable, Identifiable {
    case autoDetect    = "autoDetect"
    case dockerDesktop = "dockerDesktop"
    case orbStack      = "orbStack"
    case none          = "none"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .autoDetect:    return "Auto-detect"
        case .dockerDesktop: return "Docker Desktop"
        case .orbStack:      return "OrbStack"
        case .none:          return "None (browser fallback)"
        }
    }

    var bundleID: String? {
        switch self {
        case .dockerDesktop: return "com.docker.docker"
        case .orbStack:      return "dev.orbstack.OrbStack"
        default:             return nil
        }
    }

    var isAvailable: Bool {
        switch self {
        case .autoDetect, .none: return true
        default: return bundleID.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) } != nil
        }
    }

    /// Resolves autoDetect to a concrete manager based on what is installed.
    var resolved: ContainerManager {
        guard self == .autoDetect else { return self }
        if let id = ContainerManager.dockerDesktop.bundleID,
           NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) != nil { return .dockerDesktop }
        if let id = ContainerManager.orbStack.bundleID,
           NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) != nil { return .orbStack }
        return .none
    }
}
// MARK: - Terminal


enum TerminalChoice: String, CaseIterable, Identifiable {
    case `default`  = "default"
    case terminal   = "com.apple.Terminal"
    case iterm2     = "com.googlecode.iterm2"
    case ghostty    = "com.mitchellh.ghostty"
    case kitty      = "net.kovidgoyal.kitty"
    case warp       = "dev.warp.Warp-Stable"
    case alacritty  = "org.alacritty"
    case hyper      = "co.zeit.hyper"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .default:   return "Default Terminal"
        case .terminal:  return "Terminal"
        case .iterm2:    return "iTerm2"
        case .ghostty:   return "Ghostty"
        case .kitty:     return "Kitty"
        case .warp:      return "Warp"
        case .alacritty: return "Alacritty"
        case .hyper:     return "Hyper"
        }
    }

    var isAvailable: Bool {
        self == .default || NSWorkspace.shared.urlForApplication(withBundleIdentifier: rawValue) != nil
    }
}
