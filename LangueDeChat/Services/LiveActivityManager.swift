import ActivityKit
import Foundation
import TsuiseKit

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {}

    func start(for parcel: TrackedParcel) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = ParcelActivityAttributes(
            trackingNumber: parcel.trackingNumber,
            carrierName: parcel.carrier.displayName,
            parcelTitle: parcel.titleText
        )
        let state = ParcelActivityAttributes.ContentState(
            status: parcel.currentStatus,
            isDelivered: parcel.isDelivered,
            progressStep: parcel.progressStep.rawValue,
            lastUpdated: Date()
        )
        _ = try? Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: nil)
        )
    }

    func update(_ parcel: TrackedParcel) async {
        for activity in Activity<ParcelActivityAttributes>.activities {
            guard activity.attributes.trackingNumber == parcel.trackingNumber else { continue }
            await sync(activity, to: parcel)
        }
    }

    /// Syncs every running Live Activity to the current *cached* parcel state
    /// without hitting the network. Ends activities for delivered parcels
    /// (and orphaned ones whose parcel was removed) and refreshes in-progress
    /// ones. Call this on foreground so a stale activity is corrected even when
    /// the refresh that observed delivery ran in the background and its
    /// `end`/`update` never took effect (iOS throttles background updates).
    func reconcile(with parcels: [TrackedParcel]) async {
        let byTracking = Dictionary(
            parcels.map { ($0.trackingNumber, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for activity in Activity<ParcelActivityAttributes>.activities {
            // Only touch live activities so we don't reset the dismissal
            // timer on ones already ended.
            guard activity.activityState == .active else { continue }

            guard let parcel = byTracking[activity.attributes.trackingNumber] else {
                await activity.end(nil, dismissalPolicy: .immediate)
                continue
            }

            await sync(activity, to: parcel)
        }
    }

    /// Pushes `parcel`'s current cached state onto `activity`: delivered parcels
    /// end the activity (with a 1h dismissal window) and in-progress ones update
    /// in place. Shared by `update(_:)` (after a fetch) and `reconcile(with:)`
    /// (from cache on foreground) so the two paths can't drift apart.
    private func sync(_ activity: Activity<ParcelActivityAttributes>, to parcel: TrackedParcel) async {
        let state = ParcelActivityAttributes.ContentState(
            status: parcel.currentStatus,
            isDelivered: parcel.isDelivered,
            progressStep: parcel.progressStep.rawValue,
            lastUpdated: parcel.lastRefreshedAt ?? Date()
        )
        let content = ActivityContent(state: state, staleDate: nil)

        if parcel.isDelivered {
            await activity.end(content, dismissalPolicy: .after(Date().addingTimeInterval(3600)))
        } else {
            await activity.update(content)
        }
    }
}
