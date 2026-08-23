import Foundation

struct PassStoreService: Sendable {
    let cli: PassCLI
    let storeDirectory: URL

    func listEntries() async throws -> [String] {
        try await cli.listEntries()
    }

    func listEntriesFast() -> [String] {
        PassStoreScanner.listEntries(in: storeDirectory)
    }

    func show(_ name: String) async throws -> String {
        try await cli.show(name)
    }

    func parseEntry(name: String, content: String) -> PassEntry {
        PassEntryParser.parse(name: name, content: content)
    }

    func loadEntry(_ name: String) async throws -> PassEntry {
        let content = try await show(name)
        return parseEntry(name: name, content: content)
    }

    func saveEntry(_ name: String, content: String, force: Bool = true) async throws {
        try await cli.insertMultiline(name, content: content, force: force)
    }

    func saveEntry(_ entry: PassEntry, force: Bool = true) async throws {
        let content = PassEntrySerializer.serialize(entry: entry)
        try await saveEntry(entry.name, content: content, force: force)
    }

    func generateEntry(
        name: String,
        length: Int = AppPreferences.defaultPasswordLength,
        noSymbols: Bool = false,
        force: Bool = true
    ) async throws -> String {
        try await cli.generate(name, length: length, noSymbols: noSymbols, force: force)
    }

    func removeEntry(_ name: String) async throws {
        try await cli.remove(name)
    }

    func renameEntry(from oldName: String, to newName: String) async throws {
        try await cli.move(from: oldName, to: newName)
    }
}
