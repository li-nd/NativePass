import Foundation

enum PassCapability: String, CaseIterable, Hashable, Sendable {
    case otpGenerate
    case otpInsert
    case otpURI
    case passwordImport
    case passwordUpdate
}
