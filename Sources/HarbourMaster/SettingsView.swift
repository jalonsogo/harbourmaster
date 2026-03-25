// SettingsView.swift
// HarbourMaster

import SwiftUI

// MARK: - Root content switcher

struct SettingsContentView: View {
    @EnvironmentObject var tabState: SettingsTabState

    var body: some View {
        Group {
            switch tabState.selected {
            case .general:  GeneralTab()
            case .docker:   DockerTab()
            case .devPorts: DevPortsTab()
            case .legend:   LegendTab()
            }
        }
        .frame(width: 480)
        .fixedSize()
    }
}

// MARK: - General

struct GeneralTab: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("Startup") {
                Toggle(isOn: $settings.launchAtLogin) {
                    Label("Launch at login", systemImage: "power")
                }
            }
            Section("Browser") {
                Picker(selection: $settings.browserChoice) {
                    ForEach(BrowserChoice.allCases.filter { $0.isAvailable }) {
                        Text($0.displayName).tag($0)
                    }
                } label: {
                    Label("Open links in", systemImage: "globe")
                }
                .pickerStyle(.menu)
            }
            Section("Terminal") {
                Picker(selection: $settings.terminalChoice) {
                    ForEach(TerminalChoice.allCases.filter { $0.isAvailable }) {
                        Text($0.displayName).tag($0)
                    }
                } label: {
                    Label("Open folders in", systemImage: "terminal")
                }
                .pickerStyle(.menu)
            }
            Section("Notifications") {
                Toggle(isOn: $settings.notificationsEnabled) {
                    Label("Notify when ports open or close", systemImage: "bell")
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Docker

struct DockerTab: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("Visibility") {
                Toggle(isOn: $settings.showDockerSection) {
                    Label("Show Docker section in menu", systemImage: "shippingbox")
                }
            }
            Section("Container Manager") {
                Picker(selection: $settings.containerManager) {
                    ForEach(ContainerManager.allCases.filter { $0.isAvailable }) {
                        Text($0.displayName).tag($0)
                    }
                } label: {
                    Label("Open containers in", systemImage: "cube.box")
                }
                .pickerStyle(.menu)
                .disabled(!settings.showDockerSection)

                if settings.showDockerSection && settings.containerManager.resolved == .none {
                    Label("No supported container manager found. Clicking containers will open in the browser.",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Dev Ports

struct DevPortsTab: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var newPortText = ""
    @State private var errorMessage: String? = nil
    @State private var warningMessage: String? = nil

    var sortedPorts: [Int] { settings.customDevPorts.sorted() }

    var body: some View {
        Form {
            // ── Individual ports ─────────────────────────────────────────────
            if !sortedPorts.isEmpty {
                Section("Individual Ports") {
                    ForEach(sortedPorts, id: \.self) { port in
                        HStack {
                            Text("\(port)")
                                .font(.system(.body, design: .monospaced))
                            // Warn if this port is also covered by a range
                            if settings.customDevPortRanges.contains(where: { $0.contains(port) }) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                                    .help("Already covered by a range — individual entry is redundant")
                            }
                            Spacer()
                            Button { settings.customDevPorts.remove(port) } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // ── Ranges ───────────────────────────────────────────────────────
            if !settings.customDevPortRanges.isEmpty {
                Section("Ranges") {
                    ForEach(settings.customDevPortRanges) { range in
                        HStack {
                            Image(systemName: "arrow.left.and.right")
                                .foregroundStyle(.secondary)
                                .frame(width: 16)
                            Text(range.displayString)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button {
                                settings.customDevPortRanges.removeAll { $0.id == range.id }
                            } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // ── Add ──────────────────────────────────────────────────────────
            Section {
                HStack(spacing: 8) {
                    TextField("3000  or  3000-3400", text: $newPortText)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 160)
                        .overlay(errorMessage != nil
                            ? RoundedRectangle(cornerRadius: 5).stroke(Color.red, lineWidth: 1) : nil)
                        .onSubmit { addEntry() }
                    Button("Add", action: addEntry)
                        .disabled(newPortText.isEmpty)
                }
                if let err = errorMessage {
                    Label(err, systemImage: "xmark.circle.fill")
                        .font(.caption).foregroundStyle(.red)
                }
                if let warn = warningMessage {
                    Label(warn, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.orange)
                }
            } footer: {
                Text("Processes running known runtimes (node, python, bun, go, …) are always shown as dev ports regardless of this list.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func addEntry() {
        errorMessage = nil
        warningMessage = nil
        let trimmed = newPortText.trimmingCharacters(in: .whitespaces)

        // Try range first (contains "-")
        if trimmed.contains("-") || trimmed.contains("–") {
            guard let range = DevPortRange.parse(trimmed) else {
                errorMessage = "Invalid range. Use format 3000-3400."
                return
            }
            guard !settings.customDevPortRanges.contains(where: { $0.lower == range.lower && $0.upper == range.upper }) else {
                errorMessage = "This range is already in the list."
                return
            }

            // Warn about individual ports subsumed by this range
            let subsumed = settings.customDevPorts.filter { range.contains($0) }.sorted()
            if !subsumed.isEmpty {
                let ports = subsumed.map(String.init).joined(separator: ", ")
                warningMessage = "Port\(subsumed.count > 1 ? "s" : "") \(ports) \(subsumed.count > 1 ? "are" : "is") already in your list and will be covered by this range."
            }

            // Warn about overlapping ranges
            let overlapping = settings.rangesOverlapping(range)
            if !overlapping.isEmpty {
                let names = overlapping.map(\.displayString).joined(separator: ", ")
                let overlap = "Range overlaps with existing \(names)."
                warningMessage = warningMessage.map { $0 + " " + overlap } ?? overlap
            }

            settings.customDevPortRanges.append(range)
            newPortText = ""

        } else {
            // Single port
            guard let port = Int(trimmed), port > 0, port <= 65535 else {
                errorMessage = "Invalid port number (1–65535)."
                return
            }
            guard !settings.customDevPorts.contains(port) else {
                errorMessage = "Port \(port) is already in the list."
                return
            }

            // Warn if a range already covers it
            if let covering = settings.customDevPortRanges.first(where: { $0.contains(port) }) {
                warningMessage = "Port \(port) is already covered by range \(covering.displayString). Adding it individually is redundant."
            }

            settings.customDevPorts.insert(port)
            newPortText = ""
        }
    }
}

// MARK: - Legend

struct LegendTab: View {
    var body: some View {
        Form {
            Section {
                LegendRow(symbol: "circle.fill",      color: .green,
                          title: "Dev Port",
                          subtitle: "Known runtime (node, python, bun, go…) or a port in your Dev Ports list")
                LegendRow(symbol: "circle.fill",      color: .blue,
                          title: "User Port",
                          subtitle: "Other process running under your account")
                LegendRow(symbol: "shippingbox.fill", color: .green,
                          title: "Docker Container (running)",
                          subtitle: "Container is active and serving traffic")
                LegendRow(symbol: "shippingbox.fill", color: Color(nsColor: .secondaryLabelColor),
                          title: "Docker Container (paused)",
                          subtitle: "Container is paused")
                LegendRow(symbol: "shield.fill",      color: .orange,
                          title: "System Service",
                          subtitle: "Known macOS system process (e.g. AirPlay, Handoff)")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Legend row

struct LegendRow: View {
    let symbol: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 20, alignment: .center)
                .font(.system(size: 14))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
