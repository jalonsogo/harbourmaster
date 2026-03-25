// DockerScanner.swift
// HarbourMaster
//
// Queries the Docker CLI to map host ports → running container info.

import Foundation

struct DockerContainer: Equatable, Hashable {
    let id: String
    let name: String
    let image: String
    let hostPort: Int
    let containerPort: Int
    let proto: String
    let composeProject: String?
    let composeService: String?
    let isPaused: Bool
    var containerCPU: String?
    var containerMem: String?

    var displayName: String { composeService ?? name }
}

enum DockerScanner {

    static let dockerCommands: Set<String> = ["com.docke", "docker-pro", "docker"]

    // MARK: - Scan running containers

    static func scan() -> [Int: DockerContainer] {
        let output = runDocker(["ps", "--format", "{{.ID}}|{{.Names}}|{{.Image}}|{{.Ports}}|{{.Labels}}|{{.Status}}"])
        guard !output.isEmpty else { return [:] }
        return parse(output: output)
    }

    // MARK: - Container stats

    /// Fetches CPU and memory stats for a list of container IDs (non-streaming).
    /// Returns a dictionary mapping container ID prefix → (cpu string, mem string).
    static func fetchStats(ids: [String]) -> [String: (cpu: String, mem: String)] {
        guard !ids.isEmpty else { return [:] }
        var args = ["stats", "--no-stream", "--format", "{{.ID}}|{{.CPUPerc}}|{{.MemUsage}}"]
        args.append(contentsOf: ids)
        let output = runDocker(args)
        guard !output.isEmpty else { return [:] }

        var result: [String: (cpu: String, mem: String)] = [:]
        for line in output.components(separatedBy: "\n") {
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 3 else { continue }
            let id  = parts[0].trimmingCharacters(in: .whitespaces)
            let cpu = parts[1].trimmingCharacters(in: .whitespaces)
            // MemUsage is like "128MiB / 2GiB" — keep only the used part
            let memFull = parts[2].trimmingCharacters(in: .whitespaces)
            let mem = memFull.components(separatedBy: " / ").first ?? memFull
            guard !id.isEmpty else { continue }
            result[id] = (cpu: cpu, mem: mem)
        }
        return result
    }

    // MARK: - Container actions

    @discardableResult
    static func stop(_ container: DockerContainer) -> Bool    { run("stop",    container.name) }
    @discardableResult
    static func pause(_ container: DockerContainer) -> Bool   { run("pause",   container.name) }
    @discardableResult
    static func unpause(_ container: DockerContainer) -> Bool { run("unpause", container.name) }
    @discardableResult
    static func restart(_ container: DockerContainer) -> Bool { run("restart", container.name) }

    // MARK: - Log command string (for terminal)

    static func logsCommand(for container: DockerContainer) -> String {
        let docker = dockerPath() ?? "docker"
        return "\(docker) logs -f \(container.name)"
    }

    static func composeLogsCommand(for container: DockerContainer) -> String? {
        guard let project = container.composeProject else { return nil }
        let docker = dockerPath() ?? "docker"
        return "\(docker) compose -p \(project) logs -f"
    }

    // MARK: - Private helpers

    private static func run(_ command: String, _ name: String) -> Bool {
        guard let path = dockerPath() else { return false }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = [command, name]
        p.standardOutput = Pipe()
        p.standardError = Pipe()
        try? p.run()
        p.waitUntilExit()
        return p.terminationStatus == 0
    }

    static func dockerPath() -> String? {
        ["/usr/local/bin/docker", "/opt/homebrew/bin/docker", "/usr/bin/docker"]
            .first(where: { FileManager.default.fileExists(atPath: $0) })
    }

    private static func runDocker(_ arguments: [String]) -> String {
        guard let path = dockerPath() else { return "" }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = arguments
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do { try p.run(); p.waitUntilExit() } catch { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func parse(output: String) -> [Int: DockerContainer] {
        var result: [Int: DockerContainer] = [:]

        for line in output.components(separatedBy: "\n") {
            let parts = line.components(separatedBy: "|")
            guard parts.count == 6 else { continue }

            let id     = parts[0].trimmingCharacters(in: .whitespaces)
            let name   = parts[1].trimmingCharacters(in: .whitespaces)
            let image  = parts[2].trimmingCharacters(in: .whitespaces)
            let ports  = parts[3].trimmingCharacters(in: .whitespaces)
            let labels = parts[4].trimmingCharacters(in: .whitespaces)
            let status = parts[5].trimmingCharacters(in: .whitespaces)

            let isPaused = status.lowercased().contains("paused")

            func label(_ key: String) -> String? {
                labels.components(separatedBy: ",")
                    .first(where: { $0.hasPrefix("\(key)=") })
                    .flatMap { $0.components(separatedBy: "=").dropFirst().first }
                    .map { $0.trimmingCharacters(in: .whitespaces) }
            }
            let composeProject = label("com.docker.compose.project")
            let composeService = label("com.docker.compose.service")

            for mapping in ports.components(separatedBy: ", ") {
                guard let arrowRange = mapping.range(of: "->"),
                      let colonRange = mapping.range(of: ":", options: .backwards, range: mapping.startIndex..<arrowRange.lowerBound),
                      let slashRange = mapping.range(of: "/", options: .backwards)
                else { continue }

                let hostPortStr      = String(mapping[colonRange.upperBound..<arrowRange.lowerBound])
                let containerPortStr = String(mapping[arrowRange.upperBound..<slashRange.lowerBound])
                let proto            = String(mapping[slashRange.upperBound...])

                guard let hostPort      = Int(hostPortStr),
                      let containerPort = Int(containerPortStr),
                      result[hostPort] == nil else { continue }

                result[hostPort] = DockerContainer(
                    id: id, name: name, image: image,
                    hostPort: hostPort, containerPort: containerPort, proto: proto,
                    composeProject: composeProject, composeService: composeService,
                    isPaused: isPaused,
                    containerCPU: nil, containerMem: nil
                )
            }
        }
        return result
    }
}
