import Foundation

enum QuickAccessPickerItemID: Hashable, Sendable {
    case password
    case username
    case otp
    case url
    case custom(String)
    case fullEntry
}

struct QuickAccessFieldChoice: Identifiable, Hashable, Sendable {
    let id: QuickAccessPickerItemID
    let label: String
    /// Pre-resolved value; `nil` for OTP (resolved at confirm time for freshness).
    let value: String?

    /// Short right-hand preview (8 characters + ellipsis when truncated).
    var preview: String {
        QuickAccessFieldResolver.preview(for: value)
    }
}

enum QuickAccessFieldResolver {
    private static let usernameKeys = ["username", "login", "user"]
    static let previewLength = 8

    /// Order: Full entry → Password → Username → OTP → remaining fields.
    static func choices(from entry: PassEntry) -> [QuickAccessFieldChoice] {
        var choices: [QuickAccessFieldChoice] = [
            QuickAccessFieldChoice(
                id: .fullEntry,
                label: String(localized: "Full entry"),
                value: entry.rawContent
            ),
            QuickAccessFieldChoice(
                id: .password,
                label: String(localized: "Password"),
                value: entry.password
            )
        ]

        var consumedKeys = Set<String>()

        if let username = username(from: entry) {
            choices.append(
                QuickAccessFieldChoice(
                    id: .username,
                    label: String(localized: "Username"),
                    value: username.value
                )
            )
            consumedKeys.insert(username.key.lowercased())
        }

        if entry.hasOTPMarker {
            choices.append(
                QuickAccessFieldChoice(
                    id: .otp,
                    label: String(localized: "OTP"),
                    value: nil
                )
            )
        }

        if let url = url(from: entry) {
            choices.append(
                QuickAccessFieldChoice(
                    id: .url,
                    label: String(localized: "URL"),
                    value: url.value
                )
            )
            consumedKeys.insert(url.key.lowercased())
        }

        let extras: [QuickAccessFieldChoice] = entry.fields.enumerated().compactMap { index, field in
            let key = field.key.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = field.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, !value.isEmpty else { return nil }
            guard !consumedKeys.contains(key.lowercased()) else { return nil }
            return QuickAccessFieldChoice(
                id: .custom("\(field.id)#\(index)"),
                label: key,
                value: value
            )
        }
        choices.append(contentsOf: extras)

        return choices
    }

    static func preview(for value: String?) -> String {
        guard let value else { return String(repeating: "·", count: previewLength) }
        let collapsed = value
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else { return String(repeating: "·", count: previewLength) }
        if collapsed.count <= previewLength {
            return collapsed
        }
        return String(collapsed.prefix(previewLength)) + "…"
    }

    /// Raw entry without `otpauth://` lines — safer for Auto-Type into forms.
    static func typingContent(from entry: PassEntry) -> String {
        entry.rawContent
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.hasPrefix("otpauth://") }
            .joined(separator: "\n")
    }

    static func username(from entry: PassEntry) -> (key: String, value: String)? {
        for key in usernameKeys {
            if let field = entry.fields.first(where: { $0.key.lowercased() == key }) {
                let value = field.value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty {
                    return (field.key, value)
                }
            }
        }
        return nil
    }

    static func url(from entry: PassEntry) -> (key: String, value: String)? {
        if let field = entry.fields.first(where: { PassWebURL.isWebFieldKey($0.key) }) {
            let value = field.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                return (field.key, value)
            }
        }
        return nil
    }

    static func usernameValue(from entry: PassEntry) -> String? {
        username(from: entry)?.value
    }

    static func urlValue(from entry: PassEntry) -> String? {
        url(from: entry)?.value
    }
}
