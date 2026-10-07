import Foundation

/// Persists known password-store paths and which one is active.
/// Only paths — no display names or cached key metadata.
enum StoreRegistry {
    private static let pathsKey = "storePaths"
    private static let activeKey = "activeStorePath"
    private static let legacyStoreDirectoryKey = "storeDirectory"
    private static let migratedKey = "storeRegistryMigrated"

    static var defaultStoreURL: URL {
        PassEnvironment.defaultStorePath
    }

    static var paths: [URL] {
        migrateIfNeeded()
        let stored = UserDefaults.standard.stringArray(forKey: pathsKey) ?? []
        let urls = stored.map { normalize(URL(fileURLWithPath: $0, isDirectory: true)) }
        let unique = dedupe(urls)
        if unique.isEmpty {
            let fallback = normalize(defaultStoreURL)
            save(paths: [fallback], active: fallback)
            return [fallback]
        }
        return unique
    }

    static var activeURL: URL {
        migrateIfNeeded()
        let paths = self.paths
        if let activePath = UserDefaults.standard.string(forKey: activeKey) {
            let active = normalize(URL(fileURLWithPath: activePath, isDirectory: true))
            if paths.contains(where: { samePath($0, active) }) {
                return active
            }
        }
        let fallback = ensureDefaultFallback()
        return fallback
    }

    @discardableResult
    static func add(_ url: URL) -> URL {
        migrateIfNeeded()
        let normalized = normalize(url)
        var current = paths
        if !current.contains(where: { samePath($0, normalized) }) {
            current.append(normalized)
            save(paths: current, active: activeURL)
        }
        return normalized
    }

    /// Removes a path from the registry only — does not delete files on disk.
    @discardableResult
    static func remove(_ url: URL) -> URL {
        migrateIfNeeded()
        let normalized = normalize(url)
        var current = paths.filter { !samePath($0, normalized) }
        let wasActive = samePath(activeURL, normalized)
        if current.isEmpty {
            current = [normalize(defaultStoreURL)]
        }
        let newActive: URL
        if wasActive {
            newActive = current.first(where: { samePath($0, defaultStoreURL) }) ?? current[0]
        } else {
            let previous = activeURL
            newActive = current.first(where: { samePath($0, previous) }) ?? current[0]
        }
        save(paths: current, active: newActive)
        return newActive
    }

    static func setActive(_ url: URL) {
        migrateIfNeeded()
        let normalized = add(url)
        UserDefaults.standard.set(normalized.path, forKey: activeKey)
    }

    /// If the active path is missing from disk (or was removed), switch to the default store.
    @discardableResult
    static func ensureDefaultFallback() -> URL {
        migrateIfNeeded()
        let defaultURL = normalize(defaultStoreURL)
        var current = paths
        let active = {
            if let path = UserDefaults.standard.string(forKey: activeKey) {
                return normalize(URL(fileURLWithPath: path, isDirectory: true))
            }
            return defaultURL
        }()

        let activeExists = FileManager.default.fileExists(atPath: active.path)
        let activeInList = current.contains(where: { samePath($0, active) })

        if activeExists, activeInList {
            return active
        }

        if !current.contains(where: { samePath($0, defaultURL) }) {
            current.insert(defaultURL, at: 0)
        }
        save(paths: current, active: defaultURL)
        return defaultURL
    }

    static func displayPath(for url: URL) -> String {
        let path = normalize(url).path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path == home {
            return "~"
        }
        if path.hasPrefix(home + "/") {
            return "~" + String(path.dropFirst(home.count))
        }
        return path
    }

    /// Last path component for compact UI (e.g. `password-store`).
    static func shortDisplayName(for url: URL) -> String {
        let name = normalize(url).lastPathComponent
        return name.isEmpty ? displayPath(for: url) : name
    }

    static func samePath(_ lhs: URL, _ rhs: URL) -> Bool {
        normalize(lhs).path == normalize(rhs).path
    }

    static func normalize(_ url: URL) -> URL {
        let expanded: URL
        if url.path.hasPrefix("~") {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            let suffix = String(url.path.dropFirst())
            expanded = URL(fileURLWithPath: home + suffix, isDirectory: true)
        } else {
            expanded = url
        }
        return expanded.standardizedFileURL.resolvingSymlinksInPath()
    }

    // MARK: - Private

    private static func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migratedKey) else { return }

        var initial: [URL] = []
        if let legacy = UserDefaults.standard.string(forKey: legacyStoreDirectoryKey), !legacy.isEmpty {
            initial.append(normalize(URL(fileURLWithPath: legacy, isDirectory: true)))
        }
        if initial.isEmpty {
            initial.append(normalize(defaultStoreURL))
        } else if !initial.contains(where: { samePath($0, defaultStoreURL) }) {
            // Keep legacy as active; default is not auto-added unless needed later.
        }

        let active = initial[0]
        save(paths: initial, active: active)
        UserDefaults.standard.set(true, forKey: migratedKey)
    }

    private static func save(paths: [URL], active: URL) {
        let unique = dedupe(paths.map(normalize))
        let activeNormalized = normalize(active)
        let ensuredActive = unique.first(where: { samePath($0, activeNormalized) }) ?? unique.first ?? normalize(defaultStoreURL)
        var finalPaths = unique
        if !finalPaths.contains(where: { samePath($0, ensuredActive) }) {
            finalPaths.append(ensuredActive)
        }
        UserDefaults.standard.set(finalPaths.map(\.path), forKey: pathsKey)
        UserDefaults.standard.set(ensuredActive.path, forKey: activeKey)
    }

    private static func dedupe(_ urls: [URL]) -> [URL] {
        var result: [URL] = []
        for url in urls {
            let normalized = normalize(url)
            if !result.contains(where: { samePath($0, normalized) }) {
                result.append(normalized)
            }
        }
        return result
    }
}
