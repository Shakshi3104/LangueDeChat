import Foundation
import SwiftData
import TsuiseKit

@MainActor
final class ParcelRefresher {
    static let shared = ParcelRefresher()
    private init() {}

    func refresh(_ parcel: TrackedParcel) async throws {
        let oldStatus = parcel.currentStatus
        let isFirstFetch = parcel.lastRefreshedAt == nil

        let info = try await TsuiseKit.fetch(
            carrier: parcel.carrier,
            trackingNumber: parcel.trackingNumber
        )
        parcel.updateCache(with: info)

        // Two refreshes of the same parcel can be in flight at once — the list
        // refreshes everything on appear and foreground while the detail view
        // refreshes its own parcel, and each view only guards against its own
        // re-entry. Both then read the same pre-fetch `oldStatus`, so the
        // status-changed test alone announced one transition twice.
        //
        // So the announcement is gated on what was last *notified*, which is
        // persisted on the parcel: whichever refresh lands first claims the
        // status and the other sees it already claimed. Claiming it is a single
        // main-actor step with no `await` in between, so the two can't
        // interleave — and because the record outlives the process, a status
        // announced by the background task isn't announced again on next
        // launch. Still requires an actual change, so the first refresh after
        // this field appears seeds it silently rather than re-announcing.
        let status = parcel.currentStatus
        let alreadyNotified = parcel.lastNotifiedStatus == status
        parcel.lastNotifiedStatus = status

        if !isFirstFetch && status != oldStatus && !alreadyNotified {
            NotificationManager.shared.notifyStatusChange(
                parcelTitle: parcel.titleText,
                newStatus: status
            )
        }
        await LiveActivityManager.shared.update(parcel)
    }

    /// Refresh every tracked parcel, then persist in one save.
    ///
    /// Cancellation-aware on purpose: this also runs from the background
    /// refresh task, whose expiration handler cancels us to wind the work down
    /// before the system suspends the process. Parcels that haven't started
    /// fetching bail out immediately so the save — the one part that takes a
    /// lock on the App Group store — is reached promptly. The save itself runs
    /// even when cancelled: whatever did come back is already written into the
    /// models, and dropping it would lose a full refresh round.
    func refreshAll(in context: ModelContext) async {
        let descriptor = FetchDescriptor<TrackedParcel>()
        guard let parcels = try? context.fetch(descriptor) else { return }
        await withTaskGroup(of: Void.self) { group in
            for parcel in parcels {
                group.addTask { @MainActor in
                    guard !Task.isCancelled else { return }
                    try? await self.refresh(parcel)
                }
            }
        }
        try? context.save()
        BackgroundRefreshManager.scheduleNext()
    }
}
