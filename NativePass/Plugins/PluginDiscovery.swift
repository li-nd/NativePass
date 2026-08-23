import Foundation

struct PluginDiscovery: Sendable {
    struct ExtensionFile: Sendable {
        let command: String
        let path: URL
        let source: PluginSource
    }

    func discoverExtensionFiles(environment: PassEnvironment) -> [ExtensionFile] {
        var files: [String: ExtensionFile] = [:]
        let userDir = environment.userExtensionDirectory.resolvingSymlinksInPath()

        for directory in environment.extensionDirectories {
            let resolved = directory.resolvingSymlinksInPath()
            let isUser = resolved.path == userDir.path
            let source: PluginSource = isUser
                ? .user(directory: directory)
                : .system(directory: directory)
            // User dirs win over system when the same command exists in both.
            if isUser {
                merge(files: scanDirectory(directory, source: source), into: &files, overwrite: true)
            } else {
                merge(files: scanDirectory(directory, source: source), into: &files, overwrite: false)
            }
        }

        return files.values.sorted { $0.command < $1.command }
    }

    func probe(
        command: String,
        environment: PassEnvironment,
        cli: PassCLI
    ) async -> PluginActivationState {
        do {
            let versionResult = try await cli.run([command, "version"], timeout: 5)
            if versionResult.exitCode == 0 {
                let version = versionResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                return .active(version: version.isEmpty ? nil : version)
            }
        } catch {
            // fall through to help probe
        }

        do {
            let helpResult = try await cli.run([command, "--help"], timeout: 5)
            if helpResult.exitCode == 0 {
                return .active(version: nil)
            }
            let stderr = helpResult.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            let reason = stderr.isEmpty ? String(localized: "Extension command failed.") : stderr
            return .foundButInactive(reason: reason)
        } catch let error as PassError {
            return .foundButInactive(reason: error.localizedDescription)
        } catch {
            return .foundButInactive(reason: error.localizedDescription)
        }
    }

    func checkDependencies(_ names: [String]) -> [String] {
        names.filter { !isExecutableOnPath($0) }
    }

    func buildPluginList(
        environment: PassEnvironment,
        cli: PassCLI
    ) async -> [PassPluginInfo] {
        let extensionFiles = discoverExtensionFiles(environment: environment)

        return await withTaskGroup(of: PassPluginInfo.self) { group in
            for file in extensionFiles {
                group.addTask {
                    await self.makePluginInfo(for: file, environment: environment, cli: cli, probeCLI: true)
                }
            }
            var plugins: [PassPluginInfo] = []
            for await plugin in group {
                plugins.append(plugin)
            }
            return plugins.sorted { $0.command < $1.command }
        }
    }

    func buildPluginListFast(environment: PassEnvironment) -> [PassPluginInfo] {
        discoverExtensionFiles(environment: environment)
            .map { makePluginInfoSync(for: $0, probeCLI: false) }
            .sorted { $0.command < $1.command }
    }

    // MARK: - Private

    private func makePluginInfo(
        for file: ExtensionFile,
        environment: PassEnvironment,
        cli: PassCLI,
        probeCLI: Bool
    ) async -> PassPluginInfo {
        let known = KnownPlugins.knownPlugin(for: file.command)
        var state: PluginActivationState = .installed
        var missingDeps: [String] = []

        if probeCLI {
            state = await probe(command: file.command, environment: environment, cli: cli)
        }

        // Extension file is on disk — treat failed CLI probe as degraded, not missing.
        if case .foundButInactive(let reason) = state {
            state = .degraded(version: nil, warnings: [reason])
        }

        if let known {
            missingDeps = resolveMissingDependencies(for: known)
            if !missingDeps.isEmpty {
                switch state {
                case .active(let version):
                    state = .degraded(version: version, warnings: missingDeps.map { String(localized: "\($0) not found") })
                case .installed:
                    state = .degraded(version: nil, warnings: missingDeps.map { String(localized: "\($0) not found") })
                case .degraded(let version, let warnings):
                    state = .degraded(
                        version: version,
                        warnings: warnings + missingDeps.map { String(localized: "\($0) not found") }
                    )
                default:
                    break
                }
            }
        }

        return PassPluginInfo(
            id: file.command,
            command: file.command,
            displayName: known?.displayName ?? file.command,
            homepage: known?.homepage,
            filePath: file.path,
            source: file.source,
            state: state,
            capabilities: known?.capabilities ?? [],
            missingDependencies: missingDeps,
            isKnown: known != nil
        )
    }

    private func makePluginInfoSync(for file: ExtensionFile, probeCLI: Bool) -> PassPluginInfo {
        let known = KnownPlugins.knownPlugin(for: file.command)
        var missingDeps: [String] = []
        if let known {
            missingDeps = resolveMissingDependencies(for: known)
        }

        let state: PluginActivationState = missingDeps.isEmpty
            ? .installed
            : .degraded(version: nil, warnings: missingDeps.map { String(localized: "\($0) not found") })

        return PassPluginInfo(
            id: file.command,
            command: file.command,
            displayName: known?.displayName ?? file.command,
            homepage: known?.homepage,
            filePath: file.path,
            source: file.source,
            state: state,
            capabilities: known?.capabilities ?? [],
            missingDependencies: missingDeps,
            isKnown: known != nil
        )
    }

    private func resolveMissingDependencies(for known: KnownPlugin) -> [String] {
        // oathtool / otptool are alternatives for pass-otp.
        if known.command == "otp" {
            let hasOTPTool = isExecutableOnPath("oathtool") || isExecutableOnPath("otptool")
            var missing: [String] = []
            if !hasOTPTool {
                missing.append("oathtool")
            }
            if !isExecutableOnPath("qrencode") {
                missing.append("qrencode")
            }
            return missing
        }
        return checkDependencies(known.optionalDependencies)
    }

    private func scanDirectory(_ directory: URL, source: PluginSource) -> [ExtensionFile] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isExecutableKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.compactMap { url -> ExtensionFile? in
            guard url.pathExtension == "bash" else { return nil }
            guard FileManager.default.isExecutableFile(atPath: url.path) else { return nil }
            let command = url.deletingPathExtension().lastPathComponent
            return ExtensionFile(command: command, path: url, source: source)
        }
    }

    private func merge(files: [ExtensionFile], into dict: inout [String: ExtensionFile], overwrite: Bool) {
        for file in files {
            if overwrite || dict[file.command] == nil {
                dict[file.command] = file
            }
        }
    }

    private func isExecutableOnPath(_ name: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
