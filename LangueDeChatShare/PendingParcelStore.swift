import Foundation
import os

/// A parcel handed off from the share extension, waiting for the main app to
/// import it. Kept intentionally tiny — just what the app needs to create a
/// `TrackedParcel` and fetch it. Carrier is a raw string matching
/// `TsuiseKit.Carrier`'s raw value.
struct PendingParcel: Codable {
    var carrier: String
    var trackingNumber: String
    var nickname: String?
}

/// Shared App Group hand-off queue between the share extension (writer) and the
/// main app (reader).
///
/// The queue is a JSON **file** inside the App Group container — not
/// `UserDefaults`. The extension calls `completeRequest` the instant `append`
/// returns, tearing its process down; a `UserDefaults`/cfprefsd write is async
/// and was being lost in that window, and the reader could also serve a stale
/// cfprefsd cache. An atomic file write lands on disk synchronously before the
/// process dies, and a filesystem read is always fresh across processes.
///
/// This file is duplicated verbatim in the app and the extension because each
/// synchronized folder belongs to a single target; keep the two copies in sync.
enum PendingParcelStore {
    static let appGroupID = "group.com.shakshi.LangueDeChat"
    private static let fileName = "pending-parcels.json"
    /// Legacy `UserDefaults` key — still drained once so parcels queued by an
    /// older build aren't stranded after the user updates.
    private static let legacyKey = "pendingParcels"

    private static let log = Logger(
        subsystem: "com.shakshi.LangueDeChat",
        category: "PendingParcelStore"
    )

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
    }

    /// Append a parcel to the queue for the app to pick up.
    static func append(_ parcel: PendingParcel) {
        guard let fileURL else {
            // A nil container means the App Group entitlement isn't actually
            // active for this process — the parcel can't cross the boundary.
            log.error("append: App Group container unavailable for \(appGroupID, privacy: .public); parcel dropped")
            return
        }
        var list = loadFile()
        list.append(parcel)
        do {
            let data = try JSONEncoder().encode(list)
            try data.write(to: fileURL, options: .atomic)
            log.info("append: queued \(list.count) parcel(s) at \(fileURL.path, privacy: .public)")
        } catch {
            log.error("append: write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Return all queued parcels and clear the queue.
    static func drain() -> [PendingParcel] {
        var result = loadFile()
        result.append(contentsOf: loadLegacyDefaults())

        if let fileURL, FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }
        clearLegacyDefaults()

        log.info("drain: returning \(result.count) pending parcel(s)")
        return result
    }

    private static func loadFile() -> [PendingParcel] {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([PendingParcel].self, from: data)) ?? []
    }

    private static func loadLegacyDefaults() -> [PendingParcel] {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: legacyKey),
              let list = try? JSONDecoder().decode([PendingParcel].self, from: data) else { return [] }
        return list
    }

    private static func clearLegacyDefaults() {
        UserDefaults(suiteName: appGroupID)?.removeObject(forKey: legacyKey)
    }
}
