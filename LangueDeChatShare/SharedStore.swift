import Foundation
import SwiftData

/// The single SwiftData store shared by the app and the share extension, living
/// in the App Group container. Replacing the old hand-off queue: the extension
/// inserts a `TrackedParcel` straight into this store, and the app's `@Query`
/// picks it up the next time it reads — no queue, no drain, no foreground
/// trigger, no cfprefsd caching to race against.
///
/// This file is duplicated verbatim in the app and the extension because each
/// synchronized folder belongs to a single target; keep the two copies in sync.
enum SharedStore {
    static let appGroupID = "group.com.shakshi.LangueDeChat"
    private static let fileName = "LangueDeChat.store"

    /// The App Group store URL, or nil if the container isn't available (which
    /// would mean the App Group entitlement isn't active for this process).
    static var storeURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appending(path: fileName)
    }

    /// Build a container backed by the App Group store. Falls back to the default
    /// location if the container is unavailable, so the app still runs (in that
    /// degraded case the app and extension simply don't share, as before).
    static func makeContainer() -> ModelContainer {
        if let storeURL {
            let config = ModelConfiguration(url: storeURL)
            if let container = try? ModelContainer(for: TrackedParcel.self, configurations: config) {
                return container
            }
        }
        return try! ModelContainer(for: TrackedParcel.self)
    }

    /// One-time move of a pre-existing store (SwiftData's default location, used
    /// before the store was shared) into the App Group container, so existing
    /// parcels survive the switch. No-op once the shared store exists, or if
    /// there's nothing to migrate. Call before `makeContainer()`.
    ///
    /// This copies rows through live SwiftData containers rather than copying the
    /// `.store` files: an app that was force-quit leaves recent writes in an
    /// un-checkpointed `-wal`, and a raw file copy silently drops them. Opening
    /// the old store replays that WAL, so every parcel comes across.
    static func migrateExistingStoreIfNeeded() {
        guard let storeURL, !FileManager.default.fileExists(atPath: storeURL.path) else { return }

        let legacyURL = URL.applicationSupportDirectory.appending(path: "default.store")
        guard FileManager.default.fileExists(atPath: legacyURL.path) else { return }

        guard let old = try? ModelContainer(
                for: TrackedParcel.self,
                configurations: ModelConfiguration(url: legacyURL)),
              let new = try? ModelContainer(
                for: TrackedParcel.self,
                configurations: ModelConfiguration(url: storeURL))
        else { return }

        let oldContext = ModelContext(old)
        let newContext = ModelContext(new)
        let parcels = (try? oldContext.fetch(FetchDescriptor<TrackedParcel>())) ?? []
        for p in parcels {
            let copy = TrackedParcel(
                trackingNumber: p.trackingNumber,
                carrierRaw: p.carrierRaw,
                nickname: p.nickname,
                notes: p.notes,
                orderURL: p.orderURL
            )
            copy.id = p.id
            copy.addedAt = p.addedAt
            copy.lastRefreshedAt = p.lastRefreshedAt
            copy.cachedInfoData = p.cachedInfoData
            newContext.insert(copy)
        }
        try? newContext.save()
    }

    /// Insert a parcel from the share extension straight into the shared store.
    /// Returns `false` without inserting if an exact duplicate (same carrier +
    /// tracking number) is already tracked, so the caller can tell the user
    /// instead of silently doing nothing. Uses the TsuiseKit-free initializer so
    /// the extension links nothing extra, and its own `ModelContext` so it isn't
    /// tied to the main actor.
    @discardableResult
    static func insertParcel(carrierRaw: String, trackingNumber: String, nickname: String?) -> Bool {
        let context = ModelContext(makeContainer())

        guard !isTracked(carrierRaw: carrierRaw, trackingNumber: trackingNumber, in: context) else {
            return false
        }

        context.insert(TrackedParcel(
            trackingNumber: trackingNumber,
            carrierRaw: carrierRaw,
            nickname: nickname
        ))
        try? context.save()
        return true
    }

    /// Whether a parcel with this exact carrier + tracking number already exists.
    static func isTracked(carrierRaw: String, trackingNumber: String) -> Bool {
        isTracked(carrierRaw: carrierRaw, trackingNumber: trackingNumber, in: ModelContext(makeContainer()))
    }

    private static func isTracked(carrierRaw: String, trackingNumber: String, in context: ModelContext) -> Bool {
        let key = "\(carrierRaw)|\(trackingNumber)"
        let existing = (try? context.fetch(FetchDescriptor<TrackedParcel>())) ?? []
        return existing.contains { "\($0.carrierRaw)|\($0.trackingNumber)" == key }
    }
}
