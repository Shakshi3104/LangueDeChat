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

        if !isFirstFetch && parcel.currentStatus != oldStatus {
            NotificationManager.shared.notifyStatusChange(
                parcelTitle: parcel.titleText,
                newStatus: parcel.currentStatus
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
