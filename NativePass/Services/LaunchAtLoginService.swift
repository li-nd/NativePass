import Foundation
import ServiceManagement

enum LaunchAtLoginService {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    static var requiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) throws -> SMAppService.Status {
        let service = SMAppService.mainApp
        if enabled {
            if service.status == .enabled { return service.status }
            try service.register()
        } else {
            if service.status == .notRegistered { return service.status }
            try service.unregister()
        }
        return service.status
    }

    static func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
