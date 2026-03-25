// PortInfo.swift
// HarbourMaster
//
// Data model representing a single TCP port in LISTEN state.

import Foundation

struct PortInfo: Equatable, Hashable {
    let port: Int
    let processName: String
    let pid: Int
    let cwd: String?
    let cpuPercent: Double?
    let memoryMB: Double?
    let dockerContainer: DockerContainer?

    /// Known macOS system process names (COMMAND column prefix from lsof).
    static let systemProcesses: Set<String> = [
        "ControlCe",  // AirPlay Receiver (ports 5000, 7000)
        "rapportd",   // Handoff / Universal Clipboard
        "sharingd",   // File Sharing
        "screenshar", // Screen Sharing (VNC)
        "ARDAgent",   // Apple Remote Desktop
        "UserNotif",  // User Notification Center
        "SystemUIS",  // System UI Server
        "loginwind",  // Login Window
        "Finder",     // Finder
        "configd",    // System Configuration daemon
        "apsd",       // Apple Push Service daemon
        "symptomsd",  // Network symptom daemon
        "lsd",        // Launch Services daemon
        "distnoted",  // Distributed Notifications daemon
        "AirPlayXPC", // AirPlay XPC service
    ]

    /// Process name prefixes treated as dev runtimes regardless of port number.
    static let devRuntimes: Set<String> = [
        "node", "bun",                          // JS runtimes
        "Python", "python", "python3",          // Python
        "ruby", "puma", "unicorn", "rails",     // Ruby
        "java", "kotlin",                       // JVM
        "go", "air",                            // Go (air = live reload)
        "rust", "cargo",                        // Rust
        "php", "php-fpm",                       // PHP
        "deno",                                 // Deno
        "elixir", "beam.smp",                   // Elixir/Erlang
        "uvicorn", "gunicorn", "hypercorn",     // Python ASGI/WSGI servers
        "flask", "django",                      // Python frameworks (sometimes show as process name)
        "vite", "webpack", "next",              // JS bundlers/frameworks
        "netlify", "vercel",                    // Local dev CLIs
    ]

    /// True if this port is on a well-known dev port number OR run by a known dev runtime.
    var isDevPort: Bool {
        let s = AppSettings.shared
        return s.customDevPorts.contains(port)
            || s.customDevPortRanges.contains(where: { $0.contains(port) })
            || PortInfo.devRuntimes.contains(processName)
    }

    /// True if this process is a known macOS system service.
    var isSystemProcess: Bool {
        PortInfo.systemProcesses.contains(processName)
    }

    /// True if this port is held by the Docker userland proxy.
    var isDockerPort: Bool {
        DockerScanner.dockerCommands.contains(processName)
    }

    /// Human-readable display label used in menu items (no emoji — icon set via NSMenuItem.image).
    var displayTitle: String {
        if let c = dockerContainer {
            return "\(port)  \(c.displayName)"
        }
        return "\(port)  \(processName)  (PID \(pid))"
    }
}
