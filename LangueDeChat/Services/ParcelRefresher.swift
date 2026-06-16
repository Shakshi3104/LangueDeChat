import Foundation
import SwiftData
import TsuiseKit

@MainActor
final class ParcelRefresher {
    static let shared = ParcelRefresher()
    private init() {}

    func refresh(_ parcel: TrackedParcel) async throws {
        let info = try await TsuiseKit.fetch(
            carrier: parcel.carrier,
            trackingNumber: parcel.trackingNumber
        )
        parcel.updateCache(with: info)
    }

    func refreshAll(in context: ModelContext) async {
        let descriptor = FetchDescriptor<TrackedParcel>()
        guard let parcels = try? context.fetch(descriptor) else { return }
        await withTaskGroup(of: Void.self) { group in
            for parcel in parcels {
                group.addTask { @MainActor in
                    try? await self.refresh(parcel)
                }
            }
        }
        try? context.save()
    }
}
