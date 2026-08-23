import Foundation
import Darwin

actor PassCLI {
    let environment: PassEnvironment

    init(environment: PassEnvironment) {
        self.environment = environment
    }

    func run(
        _ arguments: [String],
        stdin: Data? = nil,
        timeout: TimeInterval = 15
    ) async throws -> PassCLIResult {
        guard let passBinary = environment.passBinary else {
            throw PassError.binaryNotFound("pass")
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try Self.execute(
                        binary: passBinary,
                        arguments: arguments,
                        environment: self.environment.processEnvironment(),
                        stdin: stdin,
                        timeout: timeout
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func runOrThrow(
        _ arguments: [String],
        stdin: Data? = nil,
        timeout: TimeInterval = 15
    ) async throws -> String {
        let result = try await run(arguments, stdin: stdin, timeout: timeout)
        guard result.exitCode == 0 else {
            throw PassError.commandFailed(exitCode: result.exitCode, stderr: result.stderr)
        }
        return result.stdout
    }

    func version(timeout: TimeInterval = 5) async throws -> String {
        let output = try await runOrThrow(["version"], timeout: timeout)
        guard let version = PassVersionParser.parsePassVersion(from: output) else {
            throw PassError.parseFailed("pass version")
        }
        return version
    }

    func listEntries() async throws -> [String] {
        // Newer pass supports --pass-name-list; 1.7.x does not.
        do {
            let output = try await runOrThrow(["ls", "--pass-name-list"], timeout: 10)
            let entries = output
                .split(separator: "\n")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            if !entries.isEmpty {
                return entries
            }
        } catch {
            // Fall through to filesystem scan.
        }
        return PassStoreScanner.listEntries(in: environment.storeDirectory)
    }

    func show(_ name: String) async throws -> String {
        try await runOrThrow(["show", name], timeout: 60)
    }

    func find(_ query: String) async throws -> [String] {
        let output = try await runOrThrow(["find", query], timeout: 15)
        return output
            .split(separator: "\n")
            .map { line in
                String(line)
                    .replacingOccurrences(of: "└── ", with: "")
                    .replacingOccurrences(of: "├── ", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty && !$0.hasPrefix("Search Terms:") }
    }

    func insertMultiline(_ name: String, content: String, force: Bool = true) async throws {
        var args = ["insert", "-m"]
        if force { args.append("-f") }
        args.append(name)
        let data = Data(content.utf8)
        try await runOrThrow(args, stdin: data, timeout: 60)
    }

    func generate(
        _ name: String,
        length: Int = 25,
        noSymbols: Bool = false,
        force: Bool = true
    ) async throws -> String {
        var args = ["generate"]
        if noSymbols { args.append("-n") }
        if force { args.append("-f") }
        args.append(name)
        args.append(String(length))
        let output = try await runOrThrow(args, timeout: 30)
        return Self.parseGeneratedPassword(from: output) ?? output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func remove(_ name: String, recursive: Bool = false) async throws {
        var args = ["rm", "-f"]
        if recursive { args.append("-r") }
        args.append(name)
        try await runOrThrow(args, timeout: 30)
    }

    func move(from oldName: String, to newName: String, force: Bool = true) async throws {
        var args = ["mv"]
        if force { args.append("-f") }
        args.append(oldName)
        args.append(newName)
        try await runOrThrow(args, timeout: 30)
    }

    func git(_ arguments: [String], timeout: TimeInterval = 120) async throws -> String {
        var args = ["git"] + arguments
        return try await runOrThrow(args, timeout: timeout)
    }

    func otpAppend(_ name: String, uri: String, force: Bool = true) async throws {
        var args = ["otp", "append"]
        if force { args.append("-f") }
        args.append(name)
        try await runOrThrow(args, stdin: Data(uri.utf8), timeout: 60)
    }

    // MARK: - Private

    private static func parseGeneratedPassword(from output: String) -> String? {
        // pass prints: "The generated password for entry is:\nPASSWORD"
        let lines = output.split(separator: "\n").map(String.init)
        if let last = lines.last, !last.isEmpty, !last.contains("generated password") {
            return last.trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    private static func execute(
        binary: URL,
        arguments: [String],
        environment: [String: String],
        stdin: Data?,
        timeout: TimeInterval
    ) throws -> PassCLIResult {
        let process = Process()
        process.executableURL = binary
        process.arguments = arguments
        process.environment = environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        if let stdin {
            let stdinPipe = Pipe()
            process.standardInput = stdinPipe
            try process.run()
            stdinPipe.fileHandleForWriting.write(stdin)
            stdinPipe.fileHandleForWriting.closeFile()
        } else if let nullDevice = FileHandle(forReadingAtPath: "/dev/null") {
            process.standardInput = nullDevice
            try process.run()
        } else {
            try process.run()
        }

        let commandLabel = (["pass"] + arguments).joined(separator: " ")
        let exitSemaphore = DispatchSemaphore(value: 0)

        DispatchQueue.global(qos: .utility).async {
            process.waitUntilExit()
            exitSemaphore.signal()
        }

        let waitResult = exitSemaphore.wait(timeout: .now() + timeout)
        if waitResult == .timedOut {
            terminateProcess(process)
            throw PassError.timedOut(command: commandLabel)
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        return PassCLIResult(
            stdout: String(decoding: stdoutData, as: UTF8.self),
            stderr: String(decoding: stderrData, as: UTF8.self),
            exitCode: process.terminationStatus
        )
    }

    private static func terminateProcess(_ process: Process) {
        guard process.isRunning else { return }
        process.terminate()
        usleep(200_000)
        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
        }
    }
}
