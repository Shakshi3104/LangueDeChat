import Foundation

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
/// main app (reader). Only a few bytes of UserDefaults cross the boundary — the
/// SwiftData store stays private to the app.
///
/// This file is duplicated verbatim in the app and the extension because each
/// synchronized folder belongs to a single target; keep the two copies in sync.
enum PendingParcelStore {
    static let appGroupID = "group.com.shakshi.LangueDeChat"
    private static let key = "pendingParcels"

    /// Append a parcel to the queue for the app to pick up.
    static func append(_ parcel: PendingParcel) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        var list = load(from: defaults)
        list.append(parcel)
        if let data = try? JSONEncoder().encode(list) {
            defaults.set(data, forKey: key)
            // Force an immediate flush: the share extension calls
            // `completeRequest` right after this, tearing the process down
            // before the async cfprefsd write would otherwise reach the App
            // Group container — which loses the hand-off.
            defaults.synchronize()
        }
    }

    /// Return all queued parcels and clear the queue.
    static func drain() -> [PendingParcel] {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return [] }
        let list = load(from: defaults)
        if !list.isEmpty { defaults.removeObject(forKey: key) }
        return list
    }

    private static func load(from defaults: UserDefaults) -> [PendingParcel] {
        guard let data = defaults.data(forKey: key),
              let list = try? JSONDecoder().decode([PendingParcel].self, from: data) else { return [] }
        return list
    }
}
