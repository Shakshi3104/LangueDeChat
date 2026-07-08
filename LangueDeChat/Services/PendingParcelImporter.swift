import Foundation
import SwiftData
import TsuiseKit

/// Drains the share-extension hand-off queue and turns each entry into a real
/// `TrackedParcel`: insert, fetch tracking, start its Live Activity. Runs when
/// the app comes to the front, so parcels added from the share sheet appear in
/// the list on the next launch / foreground.
@MainActor
enum PendingParcelImporter {
    /// Import all queued parcels into the given context. Skips duplicates that
    /// already exist (same carrier + tracking number).
    static func importPending(into context: ModelContext) async {
        let pending = PendingParcelStore.drain()
        guard !pending.isEmpty else { return }

        let existing = (try? context.fetch(FetchDescriptor<TrackedParcel>())) ?? []
        let existingKeys = Set(existing.map { "\($0.carrierRaw)|\($0.trackingNumber)" })

        var inserted: [TrackedParcel] = []
        for item in pending {
            let carrier = Carrier(rawValue: item.carrier) ?? .japanPost
            let key = "\(carrier.rawValue)|\(item.trackingNumber)"
            guard !existingKeys.contains(key) else { continue }

            let parcel = TrackedParcel(
                trackingNumber: item.trackingNumber,
                carrier: carrier,
                nickname: item.nickname
            )
            context.insert(parcel)
            inserted.append(parcel)
        }

        guard !inserted.isEmpty else { return }

        // Persist the parcels before any network work. `drain()` has already
        // cleared the queue, so if a slow/hanging fetch were allowed to run
        // first and the app got suspended mid-loop, the parcels would be lost
        // for good. Save now; enrich with tracking data afterwards.
        try? context.save()

        for parcel in inserted {
            try? await ParcelRefresher.shared.refresh(parcel)
            LiveActivityManager.shared.start(for: parcel)
        }
        try? context.save()
    }
}
