import Foundation

enum SettingsTab: String, Hashable, CaseIterable, Identifiable {
    case general
    case store
    case quickAccess
    case security
    case sync
    case diagnostics

    var id: String { rawValue }
}
