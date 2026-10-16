import Foundation
import Network

/// One message between two devices.
enum Wire: Codable {
    /// Pairing: who I am and my half of the key exchange.
    case hello(Device, pub: Data)
    /// The device being added said Join. Carries its own ring, sealed, if it has one.
    case accept(Data?)
    case reject
    /// The ring both devices end up in, sealed with the pairing key.
    case bundle(Data)
    /// A ring doc, signed with the ring secret.
    case doc(ring: UUID, payload: Data, tag: Data)
}

/// A device on the local network running Twist.
struct Peer: Identifiable, Equatable {
    var device: Device
    var ring: UUID?
    var endpoint: NWEndpoint
    var id: UUID { device.id }
}

/// A TCP connection that carries `Wire` messages, each prefixed with its length.
@MainActor
final class Pipe {
    var onMessage: (Wire) -> Void = { _ in }
    var onClose: () -> Void = {}
    private let conn: NWConnection
    private var closed = false

    init(_ conn: NWConnection) { self.conn = conn }
    convenience init(to endpoint: NWEndpoint) { self.init(NWConnection(to: endpoint, using: .tcp)) }

    func start() {
        conn.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated {
                switch state {
                case .failed, .cancelled: self?.finish()
                default: break
                }
            }
        }
        conn.start(queue: .main)
        read()
    }

    func send(_ w: Wire, then: (() -> Void)? = nil) {
        guard let body = try? JSONEncoder().encode(w) else { return }
        let n = UInt32(body.count)
        let head = Data([UInt8(n >> 24 & 0xFF), UInt8(n >> 16 & 0xFF), UInt8(n >> 8 & 0xFF), UInt8(n & 0xFF)])
        conn.send(content: head + body, completion: .contentProcessed { _ in
            MainActor.assumeIsolated { then?() }
        })
    }

    func close() { conn.cancel() }

    private func finish() {
        guard !closed else { return }
        closed = true
        onClose()
    }

    private func read() {
        conn.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] head, _, _, error in
            MainActor.assumeIsolated {
                guard let self else { return }
                guard error == nil, let head, head.count == 4 else { return self.close() }
                let n = Int(head.reduce(UInt32(0)) { $0 << 8 | UInt32($1) })
                guard n > 0, n < 1 << 20 else { return self.close() }
                self.conn.receive(minimumIncompleteLength: n, maximumLength: n) { body, _, _, error in
                    MainActor.assumeIsolated {
                        guard error == nil, let body, body.count == n,
                              let w = try? JSONDecoder().decode(Wire.self, from: body) else { return self.close() }
                        self.onMessage(w)
                        self.read()
                    }
                }
            }
        }
    }
}

/// Bonjour: advertises this device as `_twist._tcp` and watches for the others.
@MainActor
final class Link {
    static let serviceType = "_twist._tcp"

    var onPeers: ([Peer]) -> Void = { _ in }
    /// A device connected to us. Set the pipe's handlers; it is started right after.
    var onIncoming: (Pipe) -> Void = { _ in }
    private(set) var running = false

    private var listener: NWListener?
    private var browser: NWBrowser?
    private var me: Device?
    private var ring: UUID?

    func start(me: Device, ring: UUID?) {
        self.me = me
        self.ring = ring
        if running {
            listener?.service = service()
            return
        }
        running = true
        listen()
        browse()
    }

    func stop() {
        running = false
        listener?.cancel()
        browser?.cancel()
        listener = nil
        browser = nil
        onPeers([])
    }

    private func service() -> NWListener.Service? {
        guard let me else { return nil }
        var txt = NWTXTRecord()
        txt["id"] = me.id.uuidString
        txt["name"] = me.name
        txt["kind"] = me.kind.rawValue
        if let ring { txt["ring"] = ring.uuidString }
        return NWListener.Service(name: me.id.uuidString, type: Self.serviceType, domain: nil, txtRecord: txt.data)
    }

    private func listen() {
        guard let l = try? NWListener(using: .tcp) else { return }
        l.service = service()
        l.newConnectionHandler = { [weak self] conn in
            MainActor.assumeIsolated {
                let pipe = Pipe(conn)
                self?.onIncoming(pipe)
                pipe.start()
            }
        }
        l.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated {
                guard let self, case .failed = state, self.running else { return }
                // iOS tears listeners down in the background; start over.
                self.listener?.cancel()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    MainActor.assumeIsolated { if self.running { self.listen() } }
                }
            }
        }
        l.start(queue: .main)
        listener = l
    }

    private func browse() {
        let b = NWBrowser(for: .bonjourWithTXTRecord(type: Self.serviceType, domain: nil), using: .tcp)
        b.browseResultsChangedHandler = { [weak self] results, _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let me = self.me?.id
                self.onPeers(results.compactMap(Self.peer).filter { $0.id != me })
            }
        }
        b.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated {
                guard let self, case .failed = state, self.running else { return }
                self.browser?.cancel()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    MainActor.assumeIsolated { if self.running { self.browse() } }
                }
            }
        }
        b.start(queue: .main)
        browser = b
    }

    private static func peer(_ result: NWBrowser.Result) -> Peer? {
        guard case let .bonjour(txt) = result.metadata,
              let id = txt["id"].flatMap(UUID.init(uuidString:)),
              let name = txt["name"],
              let kind = txt["kind"].flatMap(DeviceKind.init(rawValue:)) else { return nil }
        return Peer(device: Device(id: id, name: name, kind: kind), ring: txt["ring"].flatMap(UUID.init(uuidString:)), endpoint: result.endpoint)
    }
}
