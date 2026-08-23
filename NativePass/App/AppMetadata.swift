import AppKit
import Foundation

enum AppMetadata {
    static let applicationName = "NativePass"
    static let authorName = "Markus Lind"
    static let repositoryURL = URL(string: "https://github.com/li-nd/NativePass")!

    static var copyright: String {
        "Copyright © \(Calendar.current.component(.year, from: Date())) \(authorName)"
    }

    static func showAboutPanel() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: aboutPanelOptions)
    }

    private static var aboutPanelOptions: [NSApplication.AboutPanelOptionKey: Any] {
        var options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: applicationName,
            .applicationIcon: applicationIcon,
            .credits: credits,
        ]

        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            options[.applicationVersion] = version
        }
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            options[.version] = build
        }

        return options
    }

    private static var applicationIcon: NSImage {
        // Prefer the asset-catalog icon. NSApp.applicationIconImage often returns
        // the generic Xcode placeholder when launching from the debugger.
        if let icon = NSImage(named: "AppIcon"), icon.size.width > 0 {
            return icon
        }
        if let icon = Bundle.main.image(forResource: "AppIcon"), icon.size.width > 0 {
            return icon
        }
        return NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
    }

    private static var credits: NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let body = NSMutableAttributedString(
            string: String(localized: "Created by \(authorName)") + "\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraph,
            ]
        )

        body.append(NSAttributedString(
            string: repositoryURL.absoluteString,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .link: repositoryURL,
                .foregroundColor: NSColor.linkColor,
                .paragraphStyle: paragraph,
            ]
        ))

        return body
    }
}
