import Foundation

struct SystemReport: Sendable {
    let generatedAt: Date
    let passAvailable: Bool
    let passVersion: String?
    let passPath: String?
    let storePath: String
    let storeInitialized: Bool
    let entryCount: Int?
    let isGitRepository: Bool
    let gpgBinary: String
    let gpgVersion: String?
    let gpgIDs: [String]
    let pinentryProgram: String?
    let plugins: [PassPluginInfo]
    let environmentSnapshot: [String: String]
    let warnings: [String]

    var diagnosticText: String {
        var lines: [String] = []
        lines.append(String(localized: "NativePass Diagnostic Report"))
        lines.append(String(localized: "Generated: \(generatedAt.formatted())"))
        lines.append("")
        lines.append(String(localized: "Pass: \(passAvailable ? String(localized: "found") : String(localized: "not found"))"))
        if let passVersion { lines.append("Version: \(passVersion)") }
        if let passPath { lines.append("Path: \(passPath)") }
        lines.append("Store: \(storePath)")
        lines.append(String(localized: "Store initialized: \(storeInitialized)"))
        if let entryCount { lines.append("Entries: \(entryCount)") }
        lines.append(String(localized: "Git repository: \(isGitRepository)"))
        lines.append("")
        lines.append("GPG: \(gpgBinary)")
        if let gpgVersion { lines.append(String(localized: "GPG version: \(gpgVersion)")) }
        if !gpgIDs.isEmpty { lines.append(String(localized: "GPG IDs: \(gpgIDs.joined(separator: ", "))")) }
        if let pinentryProgram { lines.append("Pinentry: \(pinentryProgram)") }
        lines.append("")
        lines.append(String(localized: "Plugins (\(plugins.count)):"))
        for plugin in plugins {
            lines.append("- \(plugin.displayName) [\(plugin.command)]: \(plugin.stateDescription)")
            if let path = plugin.filePath?.path {
                lines.append("  Path: \(path)")
            }
        }
        if !warnings.isEmpty {
            lines.append("")
            lines.append(String(localized: "Warnings:"))
            warnings.forEach { lines.append("- \($0)") }
        }
        return lines.joined(separator: "\n")
    }
}

extension PassPluginInfo {
    var stateDescription: String {
        switch state {
        case .notFound:
            return String(localized: "not found")
        case .installed:
            return String(localized: "installed")
        case .foundButInactive(let reason):
            return String(localized: "inactive (\(reason))")
        case .active(let version):
            if let version { return String(localized: "active v\(version)") }
            return String(localized: "active")
        case .degraded(let version, let warnings):
            let versionText = version.map { "v\($0) " } ?? ""
            return String(localized: "degraded \(versionText)(\(warnings.joined(separator: ", ")))")
        }
    }
}
