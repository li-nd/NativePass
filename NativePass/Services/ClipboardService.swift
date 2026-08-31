import AppKit
import Foundation

@Observable
final class ClipboardService {
    private var clearTask: Task<Void, Never>?
    private var messageTask: Task<Void, Never>?
    private var lastCopiedText: String?
    private(set) var lastCopyMessage: String?

    var clearTimeout: TimeInterval {
        AppPreferences.clipboardClearTimeout
    }

    func copy(_ text: String, clearAfter: TimeInterval? = nil, showToast: Bool = true) {
        let timeout = clearAfter ?? clearTimeout
        let pasteboard = NSPasteboard.general
        lastCopiedText = text
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        messageTask?.cancel()
        clearTask?.cancel()

        if showToast {
            if timeout > 0 {
                lastCopyMessage = String(localized: "Copied. Clears in \(Int(timeout))s.")
            } else {
                lastCopyMessage = String(localized: "Copied.")
            }
        }

        guard timeout > 0 else { return }

        clearTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(timeout))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                let current = pasteboard.string(forType: .string)
                if current == text {
                    pasteboard.clearContents()
                }
                if showToast {
                    self.lastCopyMessage = nil
                }
            }
        }
    }

    func showMessage(_ message: String, autoDismissAfter: TimeInterval = 3) {
        messageTask?.cancel()
        lastCopyMessage = message

        guard autoDismissAfter > 0 else { return }

        messageTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(autoDismissAfter))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.lastCopyMessage = nil
            }
        }
    }

    func dismissMessage() {
        messageTask?.cancel()
        lastCopyMessage = nil
    }

    func revertSensitiveCopy() {
        clearTask?.cancel()
        messageTask?.cancel()
        clearTask = nil
        lastCopyMessage = nil

        guard let copied = lastCopiedText else { return }

        let pasteboard = NSPasteboard.general
        if pasteboard.string(forType: .string) == copied {
            pasteboard.clearContents()
        }

        lastCopiedText = nil
    }
}
