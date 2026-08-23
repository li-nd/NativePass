import Foundation
import Observation

struct EntryMetadata: Sendable {
    var hasOTP: Bool
    var username: String?
    var url: String?
}

@Observable
final class EntryMetadataCache {
    private var cache: [String: EntryMetadata] = [:]

    func metadata(for entry: String) -> EntryMetadata? {
        cache[entry]
    }

    func update(from entry: PassEntry) {
        let username = entry.fields.first { $0.key.lowercased() == "username" }?.value
        let url = entry.fields.first { $0.key.lowercased() == "url" }?.value
        cache[entry.name] = EntryMetadata(
            hasOTP: entry.hasOTPMarker,
            username: username,
            url: url
        )
    }

    func clear() {
        cache.removeAll()
    }
}
