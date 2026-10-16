import CryptoKit
import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum DeviceKind: String, Codable {
    case phone, pad, mac
}

struct Device: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var kind: DeviceKind
}

/// What every device in the ring agrees on: who is in it, and the lock they share.
/// Each half is last-writer-wins on its own timestamp, so copies can merge in any order.
struct RingDoc: Codable, Equatable {
    var members: [Device]
    var membersChanged: Date
    /// The shared lock. `nil` after a newer change means someone unwound it.
    var session: Session?
    var sessionChanged: Date
    var sessionBy: UUID?

    func merged(with other: RingDoc) -> RingDoc {
        var r = self
        if other.membersChanged > membersChanged {
            r.members = other.members
            r.membersChanged = other.membersChanged
        }
        if other.sessionChanged > sessionChanged {
            r.session = other.session
            r.sessionChanged = other.sessionChanged
            r.sessionBy = other.sessionBy
        }
        return r
    }

    func member(_ id: UUID?) -> Device? { members.first { $0.id == id } }
}

/// Everything a device needs to be in a ring. Handed over, sealed, at pairing.
struct RingBundle: Codable {
    var id: UUID
    var secret: Data
    var doc: RingDoc
}

/// This device's ring, kept in the app group so the tunnel can read it too.
enum Ring {
    private static var d: UserDefaults { Shared.defaults }

    static var me: Device {
        let id: UUID
        if let s = d.string(forKey: "ring.me"), let u = UUID(uuidString: s) {
            id = u
        } else {
            id = UUID()
            d.set(id.uuidString, forKey: "ring.me")
        }
        return Device(id: id, name: deviceName, kind: deviceKind)
    }

    static var bundle: RingBundle? {
        get {
            guard let data = d.data(forKey: "ring.bundle") else { return nil }
            return try? JSONDecoder().decode(RingBundle.self, from: data)
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                d.set(data, forKey: "ring.bundle")
            } else {
                d.removeObject(forKey: "ring.bundle")
            }
        }
    }

    /// The ring with the given doc merged in. Returns the result.
    @discardableResult
    static func merge(_ doc: RingDoc) -> RingDoc? {
        guard var b = bundle else { return nil }
        b.doc = b.doc.merged(with: doc)
        bundle = b
        return b.doc
    }

    /// Other devices in the ring.
    static var others: [Device] {
        let me = me.id
        return (bundle?.doc.members ?? []).filter { $0.id != me }
    }

    private static var deviceKind: DeviceKind {
        #if os(macOS)
        return .mac
        #else
        return UIDevice.current.userInterfaceIdiom == .pad ? .pad : .phone
        #endif
    }

    private static var deviceName: String {
        #if os(macOS)
        return macModelName
        #else
        return UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        #endif
    }

    #if os(macOS)
    /// "MacBook Pro", "Mac mini"... from the model identifier, without the owner's name.
    private static var macModelName: String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var buf = [CChar](repeating: 0, count: max(size, 1))
        sysctlbyname("hw.model", &buf, &size, nil, 0)
        let model = String(cString: buf)
        if model.hasPrefix("MacBookAir") { return "MacBook Air" }
        if model.hasPrefix("MacBookPro") { return "MacBook Pro" }
        if model.hasPrefix("Macmini") { return "Mac mini" }
        if model.hasPrefix("iMac") { return "iMac" }
        if model.hasPrefix("MacPro") { return "Mac Pro" }
        // Apple silicon reports "Mac14,2" and the like; the host name says what it is.
        let host = Host.current().localizedName ?? "Mac"
        for kind in ["MacBook Air", "MacBook Pro", "Mac mini", "Mac Studio", "iMac", "Mac Pro"] where host.contains(kind) {
            return kind
        }
        return "Mac"
    }
    #endif
}

/// Crypto for pairing and for messages between ring members.
enum RingCrypto {
    /// The key both sides derive at pairing, and the 4 digits the person compares.
    static func pairing(mine: Curve25519.KeyAgreement.PrivateKey, theirs: Data) throws -> (key: SymmetricKey, code: String) {
        let peer = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: theirs)
        let shared = try mine.sharedSecretFromKeyAgreement(with: peer)
        let pubs = [mine.publicKey.rawRepresentation, theirs].sorted { $0.lexicographicallyPrecedes($1) }
        let transcript = pubs[0] + pubs[1]
        let key = shared.hkdfDerivedSymmetricKey(using: SHA256.self, salt: Data("twist.pair".utf8), sharedInfo: transcript, outputByteCount: 32)
        // The code covers the shared secret too, so a relay in the middle shows different digits.
        let digest = Data(SHA256.hash(data: transcript + key.withUnsafeBytes { Data($0) }))
        let n = digest.prefix(4).reduce(UInt32(0)) { $0 << 8 | UInt32($1) } % 10_000
        return (key, String(format: "%04d", n))
    }

    static func seal<T: Encodable>(_ value: T, key: SymmetricKey) throws -> Data {
        try ChaChaPoly.seal(JSONEncoder().encode(value), using: key).combined
    }

    static func open<T: Decodable>(_ type: T.Type, _ data: Data, key: SymmetricKey) throws -> T {
        try JSONDecoder().decode(type, from: ChaChaPoly.open(ChaChaPoly.SealedBox(combined: data), using: key))
    }

    static func tag(_ payload: Data, secret: Data) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: payload, using: SymmetricKey(data: secret)))
    }

    static func verify(_ payload: Data, tag: Data, secret: Data) -> Bool {
        HMAC<SHA256>.isValidAuthenticationCode(tag, authenticating: payload, using: SymmetricKey(data: secret))
    }

    static func newSecret() -> Data {
        SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
    }
}
