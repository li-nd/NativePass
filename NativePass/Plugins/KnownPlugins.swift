import Foundation

struct KnownPlugin: Sendable {
    let command: String
    let displayName: String
    let homepage: URL?
    let capabilities: Set<PassCapability>
    let optionalDependencies: [String]
}

enum KnownPlugins {
    static let catalog: [KnownPlugin] = [
        KnownPlugin(
            command: "otp",
            displayName: "pass-otp",
            homepage: URL(string: "https://github.com/tadfisher/pass-otp"),
            capabilities: [.otpGenerate, .otpInsert, .otpURI],
            optionalDependencies: ["oathtool", "otptool", "qrencode"]
        ),
        KnownPlugin(
            command: "import",
            displayName: "pass-import",
            homepage: URL(string: "https://github.com/roddhjarr/pass-import"),
            capabilities: [.passwordImport],
            optionalDependencies: []
        ),
        KnownPlugin(
            command: "update",
            displayName: "pass-update",
            homepage: URL(string: "https://github.com/pyther/pass-update"),
            capabilities: [.passwordUpdate],
            optionalDependencies: []
        ),
    ]

    static func knownPlugin(for command: String) -> KnownPlugin? {
        catalog.first { $0.command == command }
    }
}
