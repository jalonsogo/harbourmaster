// PortScanner.swift
// HarbourMaster
//
// Runs `lsof -iTCP -sTCP:LISTEN -n -P` and parses the output into PortInfo values.

import Foundation

enum PortScanner {

    // MARK: - Public API

    /// Synchronously scans all TCP LISTEN ports and resolves each process's working directory.
    /// Returns an array sorted first by isDevPort (dev ports first), then by port number.
    static func scan() -> [PortInfo] {
        let output = runLsof()
        var ports = parse(output: output)
        let pids = ports.map { $0.pid }
        let cwds        = resolveCWDs(pids: pids)
        let resources   = resolveResources(pids: pids)
        let dockerPorts = DockerScanner.scan()
        ports = ports.map {
            PortInfo(
                port: $0.port,
                processName: $0.processName,
                pid: $0.pid,
                cwd: cwds[$0.pid],
                cpuPercent: resources[$0.pid]?.cpu,
                memoryMB:   resources[$0.pid]?.mem,
                dockerContainer: dockerPorts[$0.port]
            )
        }
        return ports.sorted {
            if $0.isDevPort != $1.isDevPort { return $0.isDevPort }
            return $0.port < $1.port
        }
    }

    // MARK: - Private helpers

    private static func runLsof() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-iTCP", "-sTCP:LISTEN", "-n", "-P"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe() // suppress stderr noise

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func parse(output: String) -> [PortInfo] {
        var seen = Set<String>() // dedup key: "\(port)-\(pid)"
        var results: [PortInfo] = []

        let lines = output.components(separatedBy: "\n")

        // Skip the header line (first non-empty line starting with "COMMAND")
        for line in lines.dropFirst() {
            guard !line.isEmpty else { continue }

            // lsof columns (whitespace-separated, variable number of spaces):
            // COMMAND  PID  USER  FD  TYPE  DEVICE  SIZE/OFF  NODE  NAME
            // We only need COMMAND(0), PID(1), and the last field of NAME.
            let columns = line.split(separator: " ", omittingEmptySubsequences: true)
            guard columns.count >= 9 else { continue }

            let command = String(columns[0])
            guard let pid = Int(columns[1]) else { continue }

            // NAME is the second-to-last column, e.g. "*:3000", "127.0.0.1:8080"
            // The last column is always "(LISTEN)" which we skip.
            let name = String(columns[columns.count - 2])

            // Extract port: everything after the last ":"
            guard let colonRange = name.range(of: ":", options: .backwards),
                  let port = Int(name[colonRange.upperBound...]) else { continue }

            let dedupKey = "\(port)-\(pid)"
            guard !seen.contains(dedupKey) else { continue }
            seen.insert(dedupKey)

            results.append(PortInfo(port: port, processName: command, pid: pid, cwd: nil, cpuPercent: nil, memoryMB: nil, dockerContainer: nil))
        }

        return results
    }

    /// Resolves current working directories for a list of PIDs in a single lsof call.
    /// Returns a dictionary mapping PID → cwd path.
    static func resolveCWDs(pids: [Int]) -> [Int: String] {
        guard !pids.isEmpty else { return [:] }

        let uniquePids = Array(Set(pids))
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-d", "cwd", "-Fn", "-a", "-p", uniquePids.map(String.init).joined(separator: ",")]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return [:]
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        // Output format per process:
        //   p<pid>
        //   n<cwd path>
        var result: [Int: String] = [:]
        var currentPid: Int?
        for line in output.components(separatedBy: "\n") {
            if line.hasPrefix("p"), let pid = Int(line.dropFirst()) {
                currentPid = pid
            } else if line.hasPrefix("n"), let pid = currentPid {
                result[pid] = String(line.dropFirst())
                currentPid = nil
            }
        }
        return result
    }

    /// Fetches CPU % and RSS memory (MB) for a list of PIDs in a single `ps` call.
    /// Returns a dictionary mapping PID → (cpu, mem).
    static func resolveResources(pids: [Int]) -> [Int: (cpu: Double, mem: Double)] {
        guard !pids.isEmpty else { return [:] }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        // -o pid=,pcpu=,rss= suppresses headers; rss is in KB on macOS
        process.arguments = ["-p", pids.map(String.init).joined(separator: ","), "-o", "pid=,pcpu=,rss="]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return [:]
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        var result: [Int: (cpu: Double, mem: Double)] = [:]
        for line in output.components(separatedBy: "\n") {
            let cols = line.split(separator: " ", omittingEmptySubsequences: true)
            guard cols.count >= 3,
                  let pid = Int(cols[0]),
                  let cpu = Double(cols[1]),
                  let rssKB = Double(cols[2]) else { continue }
            result[pid] = (cpu: cpu, mem: rssKB / 1024)
        }
        return result
    }
}
