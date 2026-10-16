import ManagedSettings
import NetworkExtension
import UserNotifications

/// A VPN that goes nowhere. While a session runs, every route points into the
/// tunnel and every packet is dropped. When the session ends the tunnel switches
/// to pass-through (no routes), so on-demand reconnects don't cut the internet
/// before the app gets a chance to turn the VPN off.
///
/// In a ring the tunnel also watches iCloud during a session: the app may not run,
/// and the tunnel's own traffic is not caught by the blackhole.
final class PacketTunnelProvider: NEPacketTunnelProvider {
    private var timer: DispatchSourceTimer?
    private var watch: DispatchSourceTimer?

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        apply { [weak self] error in
            completionHandler(error)
            if error == nil { self?.drain() }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        timer?.cancel()
        watch?.cancel()
        completionHandler()
    }

    /// The app sends "refresh" when a session starts or ends while the tunnel is already up.
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        apply { _ in completionHandler?(nil) }
    }

    /// Block or pass through for the current session, and watch the ring while blocking.
    private func apply(_ done: @escaping (Error?) -> Void) {
        let session = Session.current
        let blocking = session.map { !$0.isOver } ?? false
        setTunnelNetworkSettings(settings(blocking: blocking)) { [weak self] error in
            done(error)
            guard error == nil, let self else { return }
            if blocking, let session {
                self.scheduleEnd(at: session.end)
                self.watchRing()
            } else {
                self.timer?.cancel()
                self.watch?.cancel()
            }
        }
    }

    private func scheduleEnd(at end: Date) {
        timer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + max(0, end.timeIntervalSinceNow))
        t.setEventHandler { [weak self] in
            guard let self else { return }
            self.setTunnelNetworkSettings(self.settings(blocking: false)) { _ in }
        }
        t.resume()
        timer = t
    }

    /// Every 15 s, ask iCloud whether another device unwound or moved the lock.
    private func watchRing() {
        watch?.cancel()
        guard let ring = Ring.bundle?.id else { return }
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + 5, repeating: 15)
        t.setEventHandler { [weak self] in
            Task { await self?.check(ring: ring) }
        }
        t.resume()
        watch = t
    }

    @MainActor
    private func check(ring: UUID) async {
        guard let mine = Session.current, let doc = try? await Cloud.fetch(ring: ring) else { return }
        Ring.merge(doc)
        if let s = doc.session, !s.isOver {
            guard s != mine else { return }
            // Another device started a new lock; follow its end time.
            Session.current = s
            scheduleEnd(at: s.end)
        } else if doc.session == nil, doc.sessionChanged > mine.start {
            // Unwound on another device: open this iPhone.
            watch?.cancel()
            timer?.cancel()
            Session.current = nil
            ManagedSettingsStore(named: .init(Shared.storeName)).clearAllSettings()
            setTunnelNetworkSettings(settings(blocking: false)) { _ in }
            let content = UNMutableNotificationContent()
            content.title = "Open"
            content.body = "Unwound on \(doc.member(doc.sessionBy)?.name ?? "another device"). This iPhone is yours again."
            content.sound = .default
            try? await UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: "twist.ended", content: content, trigger: nil)
            )
        }
    }

    /// Read and drop everything that enters the tunnel.
    private func drain() {
        packetFlow.readPackets { [weak self] _, _ in self?.drain() }
    }

    private static let apple4 = [("17.0.0.0", "255.0.0.0")]
    private static let apple6 = [("2620:149::", 32), ("2403:300::", 32), ("2a01:b740::", 32)]
    private static let resolvers4 = ["1.1.1.1", "8.8.8.8"]

    private func settings(blocking: Bool) -> NEPacketTunnelNetworkSettings {
        let s = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        let v4 = NEIPv4Settings(addresses: ["10.255.0.1"], subnetMasks: ["255.255.255.255"])
        let v6 = NEIPv6Settings(addresses: ["fd00:7769:7374::1"], networkPrefixLengths: [128])
        if blocking {
            v4.includedRoutes = [NEIPv4Route.default()]
            v6.includedRoutes = [NEIPv6Route.default()]
            // Apple's own network stays reachable: iCloud and its pushes are how this
            // iPhone hears that another device unwound, and they run in system daemons
            // that the blackhole would otherwise catch. Names resolve through a public
            // resolver outside the tunnel; everything else still goes nowhere.
            v4.excludedRoutes = Self.apple4.map { NEIPv4Route(destinationAddress: $0.0, subnetMask: $0.1) }
                + Self.resolvers4.map { NEIPv4Route(destinationAddress: $0, subnetMask: "255.255.255.255") }
            v6.excludedRoutes = Self.apple6.map { NEIPv6Route(destinationAddress: $0.0, networkPrefixLength: NSNumber(value: $0.1)) }
            let dns = NEDNSSettings(servers: Self.resolvers4)
            dns.matchDomains = [""]
            s.dnsSettings = dns
        } else {
            v4.includedRoutes = []
            v6.includedRoutes = []
        }
        s.ipv4Settings = v4
        s.ipv6Settings = v6
        s.mtu = 1400
        return s
    }
}
