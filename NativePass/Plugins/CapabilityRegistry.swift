import Foundation
import Observation

@Observable
final class CapabilityRegistry {
    private(set) var plugins: [PassPluginInfo] = []
    private(set) var lastRefreshed: Date?
    private(set) var isProbing = false

    var hasOTP: Bool { isActive(.otpGenerate) }

    func isActive(_ capability: PassCapability) -> Bool {
        plugins.contains { plugin in
            plugin.capabilities.contains(capability) && plugin.state.isUsable
        }
    }

    /// Fast scan: filesystem only, no CLI probes.
    func refreshFast(environment: PassEnvironment) {
        let discovery = PluginDiscovery()
        plugins = discovery.buildPluginListFast(environment: environment)
        lastRefreshed = Date()
    }

    /// Full probe via pass CLI (can be slow; run in background).
    func refresh(environment: PassEnvironment, cli: PassCLI) async {
        isProbing = true
        defer { isProbing = false }
        let discovery = PluginDiscovery()
        plugins = await discovery.buildPluginList(environment: environment, cli: cli)
        lastRefreshed = Date()
    }
}
