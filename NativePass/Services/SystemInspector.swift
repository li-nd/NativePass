import Foundation

struct SystemInspector: Sendable {
    func buildQuickReport(
        environment: PassEnvironment,
        registry: CapabilityRegistry,
        entryCount: Int?
    ) -> SystemReport {
        var warnings: [String] = []
        if !environment.isPassAvailable { warnings.append(String(localized: "pass binary not found")) }
        if !environment.isStoreInitialized { warnings.append(String(localized: "Password store is not initialized")) }
        if environment.gpgVersion == nil { warnings.append(String(localized: "Could not detect GPG version")) }
        if environment.pinentryProgram == nil {
            warnings.append(String(localized: "pinentry-program not configured in gpg-agent.conf"))
        }

        return SystemReport(
            generatedAt: Date(),
            passAvailable: environment.isPassAvailable,
            passVersion: environment.passVersion,
            passPath: environment.passBinary?.path,
            storePath: environment.storeDirectory.path,
            storeInitialized: environment.isStoreInitialized,
            entryCount: entryCount,
            isGitRepository: environment.isGitRepository,
            gpgBinary: environment.gpgBinary,
            gpgVersion: environment.gpgVersion,
            gpgIDs: environment.gpgIDs,
            pinentryProgram: environment.pinentryProgram,
            plugins: registry.plugins,
            environmentSnapshot: environment.environmentSnapshot(),
            warnings: warnings
        )
    }

    func inspect(
        environment: PassEnvironment,
        cli: PassCLI,
        registry: CapabilityRegistry,
        filesystemEntryCount: Int
    ) async -> SystemReport {
        var warnings: [String] = []
        var passVersion = environment.passVersion
        var entryCount = filesystemEntryCount

        if !environment.isPassAvailable {
            warnings.append(String(localized: "pass binary not found"))
        } else if passVersion == nil {
            do {
                passVersion = try await cli.version(timeout: 5)
            } catch {
                warnings.append(String(localized: "Could not read pass version: \(error.localizedDescription)"))
            }
        }

        if !environment.isStoreInitialized {
            warnings.append(String(localized: "Password store is not initialized"))
        } else if environment.isPassAvailable {
            do {
                let entries = try await cli.listEntries()
                entryCount = entries.count
            } catch {
                warnings.append(String(localized: "Could not list entries via pass: \(error.localizedDescription)"))
            }
        }

        if environment.gpgVersion == nil {
            warnings.append(String(localized: "Could not detect GPG version"))
        }

        if environment.pinentryProgram == nil {
            warnings.append(String(localized: "pinentry-program not configured in gpg-agent.conf"))
        }

        for plugin in registry.plugins where !plugin.missingDependencies.isEmpty {
            warnings.append(String(localized: "\(plugin.displayName): missing \(plugin.missingDependencies.joined(separator: ", "))"))
        }

        return SystemReport(
            generatedAt: Date(),
            passAvailable: environment.isPassAvailable,
            passVersion: passVersion,
            passPath: environment.passBinary?.path,
            storePath: environment.storeDirectory.path,
            storeInitialized: environment.isStoreInitialized,
            entryCount: entryCount,
            isGitRepository: environment.isGitRepository,
            gpgBinary: environment.gpgBinary,
            gpgVersion: environment.gpgVersion,
            gpgIDs: environment.gpgIDs,
            pinentryProgram: environment.pinentryProgram,
            plugins: registry.plugins,
            environmentSnapshot: environment.environmentSnapshot(),
            warnings: warnings
        )
    }
}
