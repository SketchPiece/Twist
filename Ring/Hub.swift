import CryptoKit
import Foundation
import Observation

/// The device's side of the ring: pairing, and getting the shared lock to the others
/// over the local network (instant) and through iCloud (everywhere else).
@MainActor @Observable
final class Hub {
    static let shared = Hub()

    /// Adding a device, as seen from the one that started it.
    enum Pairing: Equatable {
        case connecting(Device)
        case code(String, Device)
        case done(Device)
        case failed(String)
    }

    /// Someone nearby wants to join this device, waiting for Join.
    struct Request: Equatable {
        var device: Device
        var code: String
        var joining = false
    }

    let me = Ring.me
    private(set) var doc: RingDoc? = Ring.bundle?.doc
    private(set) var nearby: [Peer] = []
    var pairing: Pairing?
    private(set) var request: Request?

    /// A doc from another device changed the shared lock or the members.
    @ObservationIgnored var onDoc: (RingDoc) -> Void = { _ in }
    /// Whether this device can take a pairing request right now (not while locked).
    @ObservationIgnored var acceptsPairing: () -> Bool = { true }

    @ObservationIgnored private let link = Link()
    @ObservationIgnored private var pipe: Pipe?
    @ObservationIgnored private var pairKey: SymmetricKey?
    @ObservationIgnored private var seen: [String: Double] = Shared.defaults.dictionary(forKey: "ring.seen") as? [String: Double] ?? [:]
    @ObservationIgnored private var poll: Timer?

    init() {
        link.onPeers = { [weak self] in self?.peersChanged($0) }
        link.onIncoming = { [weak self] in self?.incoming($0) }
    }

    // MARK: - What the screens read

    var inRing: Bool { (doc?.members.count ?? 0) > 1 }
    /// Everyone in the ring, this device first.
    var members: [Device] {
        guard let doc, doc.members.count > 1 else { return [me] }
        return [me] + doc.members.filter { $0.id != me.id }
    }
    var others: [Device] { members.filter { $0.id != me.id } }
    /// Devices nearby that are not in the ring yet.
    var strangers: [Peer] {
        let ids = Set(members.map(\.id))
        return nearby.filter { !ids.contains($0.id) }
    }

    func isNearby(_ id: UUID) -> Bool { nearby.contains { $0.id == id } }

    func status(of d: Device) -> String {
        if d.id == me.id { return d.kind == .mac ? "This Mac" : "This \(d.name)" }
        if isNearby(d.id) { return "Nearby · ready" }
        if let t = seen[d.id.uuidString] {
            return "Not nearby · seen " + Date(timeIntervalSince1970: t).formatted(.relative(presentation: .named))
        }
        return "Not nearby · through iCloud"
    }

    /// "iPhone, MacBook Pro and iPad"
    func names(_ devices: [Device]) -> String {
        devices.map(\.name).formatted(.list(type: .and))
    }

    // MARK: - Running

    /// Advertise and look for devices on the local network.
    func start() {
        link.start(me: me, ring: Ring.bundle?.id)
    }

    func stop() {
        link.stop()
    }

    /// Ask iCloud every `seconds` too, for when pushes don't arrive.
    func startPolling(every seconds: TimeInterval) {
        poll?.invalidate()
        poll = Timer.scheduledTimer(withTimeInterval: seconds, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { Task { await self?.pull() } }
        }
    }

    /// Fetch the ring from iCloud and take anything newer.
    func pull() async {
        guard let ring = Ring.bundle?.id else { return }
        do {
            if let remote = try await Cloud.fetch(ring: ring) { receive(remote) }
        } catch {
            print("Cloud fetch failed: \(error)")
        }
    }

    // MARK: - The shared lock

    /// Tell the ring that this device locked (`session`) or unwound (`nil`).
    /// Sends over Wi-Fi at once and waits up to a few seconds for iCloud.
    func publish(session: Session?) async {
        guard var b = Ring.bundle else { return }
        b.doc.session = session
        b.doc.sessionChanged = Date()
        b.doc.sessionBy = me.id
        Ring.bundle = b
        doc = b.doc
        broadcast(b)
        let ring = b.id, doc = b.doc
        // Waits a few seconds at most, but the save keeps going (and retrying) after that:
        // a slow iCloud must not lose an unwind.
        let save = Task { await Self.save(ring: ring, doc: doc) }
        await withTaskGroup(of: Void.self) { g in
            g.addTask { await save.value }
            g.addTask { try? await Task.sleep(for: .seconds(4)) }
            await g.next()
            g.cancelAll()
        }
    }

    /// Saves to iCloud, trying again for a while if it fails. Merging makes repeats harmless.
    private static func save(ring: UUID, doc: RingDoc) async {
        for delay in [0, 5, 15, 30, 60, 120] {
            try? await Task.sleep(for: .seconds(delay))
            do {
                try await Cloud.save(ring: ring, doc: doc)
                return
            } catch {
                print("Cloud save failed: \(error)")
            }
        }
    }

    func remove(_ device: Device) {
        guard var b = Ring.bundle, device.id != me.id else { return }
        b.doc.members.removeAll { $0.id == device.id }
        b.doc.membersChanged = Date()
        Ring.bundle = b
        doc = b.doc
        // The removed device hears it too, and leaves.
        broadcast(b, extra: [device.id])
        Task { try? await Cloud.save(ring: b.id, doc: b.doc) }
    }

    private func receive(_ remote: RingDoc) {
        guard let before = Ring.bundle?.doc, let after = Ring.merge(remote) else { return }
        // Also when the stored doc already had it (the tunnel merges into it too) but this
        // process hasn't acted on it yet.
        guard after != before || after != doc else { return }
        if !after.members.contains(where: { $0.id == me.id }) {
            // Removed on another device.
            Ring.bundle = nil
            doc = nil
            link.start(me: me, ring: nil)
            return
        }
        doc = after
        onDoc(after)
    }

    /// Sends the doc to ring members nearby (or only to `to`, if given).
    private func broadcast(_ b: RingBundle, extra: Set<UUID> = [], to: Set<UUID>? = nil) {
        guard let payload = try? JSONEncoder().encode(b.doc) else { return }
        let tag = RingCrypto.tag(payload, secret: b.secret)
        var ids = Set(b.doc.members.map(\.id)).union(extra)
        if let to { ids.formIntersection(to) }
        for peer in nearby where ids.contains(peer.id) {
            let p = Pipe(to: peer.endpoint)
            p.start()
            p.send(.doc(ring: b.id, payload: payload, tag: tag)) { p.close() }
        }
    }

    // MARK: - Pairing: the device that adds

    func add(_ peer: Peer) {
        cancelPairing()
        let key = Curve25519.KeyAgreement.PrivateKey()
        let p = Pipe(to: peer.endpoint)
        pipe = p
        pairing = .connecting(peer.device)
        var other = peer.device

        p.onMessage = { [weak self] w in
            guard let self, self.pipe === p else { return }
            switch w {
            case let .hello(device, pub):
                other = device
                guard let (k, code) = try? RingCrypto.pairing(mine: key, theirs: pub) else { return self.fail("That didn't work. Try again.") }
                self.pairKey = k
                self.pairing = .code(code, device)
            case let .accept(sealed):
                guard let k = self.pairKey else { return }
                let theirs = sealed.flatMap { try? RingCrypto.open(RingBundle.self, $0, key: k) }
                let final = Self.combine(mine: Ring.bundle, theirs: theirs, adding: other, me: self.me)
                guard let out = try? RingCrypto.seal(final, key: k) else { return }
                p.send(.bundle(out)) { p.close() }
                self.adopt(final)
                self.pipe = nil
                self.pairing = .done(other)
            case .reject:
                self.fail("\(other.name) said not now.")
            default:
                break
            }
        }
        p.onClose = { [weak self] in
            guard let self, self.pipe === p else { return }
            self.fail("Lost \(other.name). Keep both on the same Wi-Fi and try again.")
        }
        p.start()
        p.send(.hello(me, pub: key.publicKey.rawRepresentation))
    }

    func cancelPairing() {
        let p = pipe
        pipe = nil
        pairKey = nil
        p?.close()
        pairing = nil
    }

    private func fail(_ message: String) {
        let p = pipe
        pipe = nil
        p?.close()
        pairing = .failed(message)
    }

    /// The ring both devices end up in: the adder's if it has one, else the other's, else a new one.
    private static func combine(mine: RingBundle?, theirs: RingBundle?, adding other: Device, me: Device) -> RingBundle {
        var b = mine ?? theirs ?? RingBundle(
            id: UUID(), secret: RingCrypto.newSecret(),
            doc: RingDoc(members: [], membersChanged: .distantPast, session: nil, sessionChanged: .distantPast, sessionBy: nil)
        )
        var members = b.doc.members.filter { $0.id != me.id && $0.id != other.id }
        members.insert(contentsOf: [me, other], at: 0)
        b.doc.members = members
        b.doc.membersChanged = Date()
        return b
    }

    private func adopt(_ b: RingBundle) {
        let old = Ring.bundle?.doc
        Ring.bundle = b
        doc = b.doc
        link.start(me: me, ring: b.id)
        broadcast(b)
        Task { try? await Cloud.save(ring: b.id, doc: b.doc) }
        if b.doc != old { onDoc(b.doc) }
    }

    // MARK: - Pairing: the device being added, and messages from the ring

    private func incoming(_ p: Pipe) {
        p.onMessage = { [weak self] w in
            guard let self else { return }
            switch w {
            case let .hello(device, pub):
                self.requested(by: device, pub: pub, on: p)
            case let .bundle(sealed):
                guard self.pipe === p, let k = self.pairKey,
                      let b = try? RingCrypto.open(RingBundle.self, sealed, key: k),
                      b.doc.members.contains(where: { $0.id == self.me.id }) else { return }
                self.pipe = nil
                self.pairKey = nil
                self.request = nil
                self.adopt(b)
                p.close()
            case let .doc(ring, payload, tag):
                defer { p.close() }
                guard let b = Ring.bundle, b.id == ring,
                      RingCrypto.verify(payload, tag: tag, secret: b.secret),
                      let doc = try? JSONDecoder().decode(RingDoc.self, from: payload) else { return }
                self.receive(doc)
            default:
                break
            }
        }
        p.onClose = { [weak self] in
            guard let self, self.pipe === p else { return }
            self.pipe = nil
            self.pairKey = nil
            self.request = nil
        }
    }

    private func requested(by device: Device, pub: Data, on p: Pipe) {
        guard acceptsPairing(), pipe == nil else {
            p.send(.reject) { p.close() }
            return
        }
        let key = Curve25519.KeyAgreement.PrivateKey()
        guard let (k, code) = try? RingCrypto.pairing(mine: key, theirs: pub) else { return p.close() }
        pipe = p
        pairKey = k
        request = Request(device: device, code: code)
        p.send(.hello(me, pub: key.publicKey.rawRepresentation))
    }

    func accept() {
        guard let p = pipe, let k = pairKey, request != nil else { return }
        request?.joining = true
        let sealed = Ring.bundle.flatMap { try? RingCrypto.seal($0, key: k) }
        p.send(.accept(sealed))
    }

    func decline() {
        let p = pipe
        pipe = nil
        pairKey = nil
        request = nil
        p?.send(.reject) { p?.close() }
    }

    // MARK: -

    private func peersChanged(_ peers: [Peer]) {
        let before = Set(nearby.map(\.id))
        nearby = peers
        // A ring member just showed up (an iPhone opened Twist, a Mac woke): swap docs, so
        // a lock or an unwind it missed while away reaches it now, both ways.
        let arrived = Set(peers.map(\.id)).subtracting(before)
        if !arrived.isEmpty, let b = Ring.bundle { broadcast(b, to: arrived) }
        let now = Date().timeIntervalSince1970
        for p in peers { seen[p.id.uuidString] = now }
        Shared.defaults.set(seen, forKey: "ring.seen")
    }
}
