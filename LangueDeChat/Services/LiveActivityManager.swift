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

            let newState = ParcelActivityAttributes.ContentState(
                status: parcel.currentStatus,
                isDelivered: parcel.isDelivered,
                progressStep: parcel.progressStep.rawValue,
                lastUpdated: Date()
            )
            let content = ActivityContent(state: newState, staleDate: nil)

            if parcel.isDelivered {
                await activity.end(content, dismissalPolicy: .after(Date().addingTimeInterval(3600)))
            } else {
                await activity.update(content)
            }
        }
    }
}
