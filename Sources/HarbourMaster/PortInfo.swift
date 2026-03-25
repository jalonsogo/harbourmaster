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

    static let devPorts: Set<Int> = [
        3000, 3001, 5173, 8080, 8000, 4000, 4200, 5001, 8888, 9000
    ]

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

    /// True if this port belongs to the curated list of common dev ports.
    var isDevPort: Bool {
        PortInfo.devPorts.contains(port)
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
