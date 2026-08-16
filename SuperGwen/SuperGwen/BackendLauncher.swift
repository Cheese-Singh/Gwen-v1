//
//  BackendLauncher.swift
//  SuperGwen
//
//  Created by Ekamveer Singh on 15/08/2026.
//

import Foundation
internal import Combine

enum BackendLaunchError: LocalizedError {
    case configNotFound(String)
    case configMissingKey(String)
    case processLaunchFailed(String)

    var errorDescription: String? {
        switch self {
        case .configNotFound(let path):
            return "backend.config not found at \(path). Copy backend.config.example to backend.config and fill in your paths."
        case .configMissingKey(let key):
            return "backend.config is missing required key: \(key)"
        case .processLaunchFailed(let reason):
            return "Failed to launch backend process: \(reason)"
        }
    }
}

struct BackendConfig {
    let projectDir: String
    let venvPython: String

    static func parse(contents: String) throws -> BackendConfig {
        var values: [String: String] = [:]
        for rawLine in contents.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#"), let eqIndex = line.firstIndex(of: "=") else { continue }
            let key = String(line[line.startIndex..<eqIndex]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: eqIndex)...]).trimmingCharacters(in: .whitespaces)
            values[key] = value
        }

        guard let projectDir = values["BACKEND_PROJECT_DIR"], !projectDir.isEmpty else {
            throw BackendLaunchError.configMissingKey("BACKEND_PROJECT_DIR")
        }
        let configuredPython = values["VENV_PYTHON"]?.trimmingCharacters(in: .whitespaces)
        let venvDir = values["VENV_DIR"]?.trimmingCharacters(in: .whitespaces)
        let derivedPython = venvDir.map { URL(fileURLWithPath: $0).appendingPathComponent("bin/python").path }
        let venvPython = [derivedPython, configuredPython]
            .compactMap { $0 }
            .first { !$0.isEmpty }

        guard let venvPython else {
            throw BackendLaunchError.configMissingKey("VENV_PYTHON or VENV_DIR")
        }
        return BackendConfig(projectDir: projectDir, venvPython: venvPython)
    }

    static func defaultConfigURL() -> URL {
        guard let url = Bundle.main.url(forResource: "backend", withExtension: "config") else {
            fatalError("backend.config not found in app bundle")
        }
        return url
    }

    static func load(from url: URL = defaultConfigURL()) throws -> BackendConfig {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            throw BackendLaunchError.configNotFound(url.path)
        }
        return try parse(contents: contents)
    }
}

enum BackendStatus: Equatable {
    case notStarted
    case launching
    case waitingForHealth
    case ready
    case failed(String)

    static func == (lhs: BackendStatus, rhs: BackendStatus) -> Bool {
        switch (lhs, rhs) {
        case (.notStarted, .notStarted), (.launching, .launching),
             (.waitingForHealth, .waitingForHealth), (.ready, .ready):
            return true
        case (.failed(let a), .failed(let b)):
            return a == b
        default:
            return false
        }
    }
}

@Observable
final class BackendLauncher {

    var status: BackendStatus = .notStarted

    private var process: Process?
    private var healthCheckTask: Task<Void, Never>?

    private let healthURL: URL
    private let healthPollInterval: TimeInterval = 0.75
    private let healthTimeout: TimeInterval = 120

    init(healthURL: URL = URL(string: "http://127.0.0.1:8000/health")!) {
        self.healthURL = healthURL
    }

    func launch() {
        guard process == nil else { return }

        status = .launching

        let config: BackendConfig
        do {
            config = try BackendConfig.load()
        } catch {
            status = .failed(error.localizedDescription)
            print("[BackendLauncher] config error: \(error.localizedDescription)")
            return
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: config.venvPython)
        task.arguments = ["-m", "uvicorn", "SuperGwenBackend:app", "--host", "127.0.0.1", "--port", "8000"]
        task.currentDirectoryURL = URL(fileURLWithPath: config.projectDir)

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe
        attachLogForwarding(pipe: stdoutPipe, label: "backend")
        attachLogForwarding(pipe: stderrPipe, label: "backend:err")

        task.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                guard let self else { return }
                if case .ready = self.status {
                    self.status = .failed("Backend process exited unexpectedly (code \(proc.terminationStatus)).")
                } else if case .failed = self.status {
                    // already recorded a more specific failure
                } else {
                    self.status = .failed("Backend process exited during startup (code \(proc.terminationStatus)).")
                }
            }
        }

        do {
            print("[BackendLauncher] executableURL: \(task.executableURL?.path ?? "nil")")
            print("[BackendLauncher] currentDirectory: \(task.currentDirectoryURL?.path ?? "nil")")
            print("[BackendLauncher] exists: \(FileManager.default.fileExists(atPath: task.executableURL?.path ?? ""))")
            try task.run()
        } catch {
            status = .failed("Couldn't launch python: \(error.localizedDescription)")
            return
        }

        process = task
        status = .waitingForHealth
        pollHealth()
    }

    func shutdown() {
        healthCheckTask?.cancel()
        healthCheckTask = nil
        guard let process, process.isRunning else { return }
        process.terminate()
        self.process = nil
        status = .notStarted
    }

    private func pollHealth() {
        healthCheckTask?.cancel()
        healthCheckTask = Task { [weak self] in
            guard let self else { return }
            let deadline = Date().addingTimeInterval(self.healthTimeout)

            while !Task.isCancelled && Date() < deadline {
                if await self.isHealthy() {
                    await MainActor.run { self.status = .ready }
                    return
                }
                try? await Task.sleep(nanoseconds: UInt64(self.healthPollInterval * 1_000_000_000))
            }

            if !Task.isCancelled {
                await MainActor.run {
                    self.status = .failed("Backend didn't become ready within \(Int(self.healthTimeout))s.")
                }
            }
        }
    }

    private func isHealthy() async -> Bool {
        var request = URLRequest(url: healthURL)
        request.timeoutInterval = 2
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return response is HTTPURLResponse
        } catch {
            return false
        }
    }

    private func attachLogForwarding(pipe: Pipe, label: String) {
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            for line in text.split(separator: "\n") {
                print("[\(label)] \(line)")
            }
        }
    }
}
