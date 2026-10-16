import CloudKit
import Foundation

/// The ring doc in the private iCloud database, so devices that are not near each other
/// still hear about a lock. One record per ring; a zone subscription pushes changes.
enum Cloud {
    static let container = CKContainer(identifier: "iCloud.com.sketchpiece.twist")
    private static var db: CKDatabase { container.privateCloudDatabase }
    private static let zone = CKRecordZone.ID(zoneName: "Ring", ownerName: CKCurrentUserDefaultName)
    private static let readyKey = "cloud.ready"

    /// Creates the zone and the push subscription once per device.
    static func setUp() async {
        guard !Shared.defaults.bool(forKey: readyKey) else { return }
        do {
            _ = try await db.modifyRecordZones(saving: [CKRecordZone(zoneID: zone)], deleting: [])
            let sub = CKRecordZoneSubscription(zoneID: zone, subscriptionID: "ring")
            let info = CKSubscription.NotificationInfo()
            info.shouldSendContentAvailable = true
            sub.notificationInfo = info
            _ = try await db.modifySubscriptions(saving: [sub], deleting: [])
            Shared.defaults.set(true, forKey: readyKey)
        } catch {
            print("Cloud setUp failed: \(error)")
        }
    }

    static func fetch(ring: UUID) async throws -> RingDoc? {
        guard let record = try await record(ring) else { return nil }
        return decode(record)
    }

    /// Merges `doc` into what iCloud has and saves it. Returns the merged doc.
    @discardableResult
    static func save(ring: UUID, doc: RingDoc) async throws -> RingDoc {
        await setUp()
        for attempt in 0..<3 {
            let record = try await record(ring) ?? CKRecord(recordType: "Ring", recordID: id(ring))
            let merged = decode(record).map { $0.merged(with: doc) } ?? doc
            record["doc"] = try JSONEncoder().encode(merged) as CKRecordValue
            do {
                _ = try await db.modifyRecords(saving: [record], deleting: [], savePolicy: .ifServerRecordUnchanged)
                return merged
            } catch let e as CKError where e.code == .serverRecordChanged && attempt < 2 {
                continue
            }
        }
        return doc
    }

    private static func id(_ ring: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: ring.uuidString, zoneID: zone)
    }

    private static func record(_ ring: UUID) async throws -> CKRecord? {
        do {
            return try await db.record(for: id(ring))
        } catch let e as CKError where e.code == .unknownItem || e.code == .zoneNotFound {
            return nil
        }
    }

    private static func decode(_ record: CKRecord) -> RingDoc? {
        guard let data = record["doc"] as? Data else { return nil }
        return try? JSONDecoder().decode(RingDoc.self, from: data)
    }
}
