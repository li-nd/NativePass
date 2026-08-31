import Foundation
import Observation

@Observable
final class ShortcutStore {
    private static let quickAccessKey = "shortcut.quickAccess"

    var quickAccess: ShortcutBinding {
        didSet {
            guard quickAccess != oldValue else { return }
            persistQuickAccess()
            NotificationCenter.default.post(name: .nativePassQuickAccessShortcutDidChange, object: nil)
        }
    }

    init() {
        quickAccess = Self.loadQuickAccess()
    }

    func resetQuickAccess() {
        quickAccess = .quickAccessDefault
    }

    private func persistQuickAccess() {
        guard let data = try? JSONEncoder().encode(quickAccess) else { return }
        UserDefaults.standard.set(data, forKey: Self.quickAccessKey)
    }

    private static func loadQuickAccess() -> ShortcutBinding {
        guard
            let data = UserDefaults.standard.data(forKey: quickAccessKey),
            let binding = try? JSONDecoder().decode(ShortcutBinding.self, from: data)
        else {
            return .quickAccessDefault
        }
        return binding
    }
}
