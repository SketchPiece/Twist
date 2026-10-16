import NetworkExtension

/// The local blackhole VPN: installed once during onboarding, switched on for a session.
enum VPN {
    private static func manager() async throws -> NETunnelProviderManager {
        let all = try await NETunnelProviderManager.loadAllFromPreferences()
        if let m = all.first { return m }
        let m = NETunnelProviderManager()
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = Shared.tunnelBundleID
        proto.serverAddress = "Twist"
        m.protocolConfiguration = proto
        m.localizedDescription = "Twist"
        return m
    }

    static var isInstalled: Bool {
        get async { ((try? await NETunnelProviderManager.loadAllFromPreferences()) ?? []).isEmpty == false }
    }

    /// Shows the system "Add VPN Configuration" prompt the first time.
    static func install() async throws {
        let m = try await manager()
        m.isEnabled = true
        m.isOnDemandEnabled = false
        try await m.saveToPreferences()
    }

    /// Turn on, and keep it on: on-demand brings it back if it drops.
    static func start() async throws {
        let m = try await manager()
        m.isEnabled = true
        let rule = NEOnDemandRuleConnect()
        rule.interfaceTypeMatch = .any
        m.onDemandRules = [rule]
        m.isOnDemandEnabled = true
        try await m.saveToPreferences()
        try await m.loadFromPreferences()
        try m.connection.startVPNTunnel()
    }

    /// Start it again if a lock is on but the tunnel is not.
    static func ensureRunning() async {
        guard let m = try? await manager() else { return }
        switch m.connection.status {
        case .connected, .connecting, .reasserting: return
        default: try? await start()
        }
    }

    static func stop() async {
        guard let m = try? await manager() else { return }
        if m.isOnDemandEnabled {
            m.isOnDemandEnabled = false
            try? await m.saveToPreferences()
        }
        if m.connection.status != .disconnected && m.connection.status != .invalid {
            m.connection.stopVPNTunnel()
        }
    }
}
