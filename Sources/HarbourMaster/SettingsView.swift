// SettingsView.swift
// HarbourMaster

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {

            // ── Startup ──────────────────────────────────────────────────────
            Section {
                Toggle(isOn: $settings.launchAtLogin) {
                    Label("Launch HarbourMaster at login", systemImage: "power")
                }
            } header: {
                Text("Startup")
            }

            // ── Browser ──────────────────────────────────────────────────────
            Section {
                Picker(selection: $settings.browserChoice) {
                    ForEach(BrowserChoice.allCases.filter { $0.isAvailable }) { browser in
                        Text(browser.displayName).tag(browser)
                    }
                } label: {
                    Label("Open links in", systemImage: "globe")
                }
                .pickerStyle(.menu)
            } header: {
                Text("Browser")
            }

            // ── Terminal ─────────────────────────────────────────────────────
            Section {
                Picker(selection: $settings.terminalChoice) {
                    ForEach(TerminalChoice.allCases.filter { $0.isAvailable }) { terminal in
                        Text(terminal.displayName).tag(terminal)
                    }
                } label: {
                    Label("Open folders in", systemImage: "terminal")
                }
                .pickerStyle(.menu)
            } header: {
                Text("Terminal")
            }

            // ── Docker ───────────────────────────────────────────────────────
            Section {
                Toggle(isOn: $settings.showDockerSection) {
                    Label("Show Docker section in menu", systemImage: "shippingbox")
                }

                Picker(selection: $settings.containerManager) {
                    ForEach(ContainerManager.allCases.filter { $0.isAvailable }) { manager in
                        Text(manager.displayName).tag(manager)
                    }
                } label: {
                    Label("Container manager", systemImage: "cube.box")
                }
                .pickerStyle(.menu)
                .disabled(!settings.showDockerSection)

                if settings.containerManager.resolved == .none && settings.showDockerSection {
                    Label("No supported container manager found. Clicking containers will open in the browser.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Docker")
            }

            // ── Legend ───────────────────────────────────────────────────────
            Section {
                LegendRow(symbol: "circle.fill",      color: .green,  title: "Dev Port",               subtitle: "Recognised dev server on a well-known port (e.g. 3000, 8080, 5173)")
                LegendRow(symbol: "circle.fill",      color: .blue,   title: "User Port",              subtitle: "Other process running under your account")
                LegendRow(symbol: "shippingbox.fill", color: .green,  title: "Docker Container (running)", subtitle: "Container is active and serving traffic")
                LegendRow(symbol: "shippingbox.fill", color: Color(nsColor: .secondaryLabelColor), title: "Docker Container (paused)", subtitle: "Container is paused")
                LegendRow(symbol: "shield.fill",      color: .orange, title: "System Service",         subtitle: "Known macOS system process (e.g. AirPlay, Handoff)")
            } header: {
                Text("Legend")
            }

        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize()
    }
}

// MARK: - Legend row

private struct LegendRow: View {
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
                Text(title)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
