import Foundation
import SwiftData

/// The persistent parcel record.
///
/// Every stored property is a plain value type — no `TsuiseKit` types cross the
/// persistence boundary (`carrierRaw` is a raw string, `cachedInfoData` is a JSON
/// blob). That's deliberate: this file is compiled into **both** the app and the
/// share extension so the two targets can share one SwiftData store in the App
/// Group, and the extension must not have to link TsuiseKit. Everything that
/// interprets a parcel (the `carrier` enum, cached events, delivery state) lives
/// in `TrackedParcel+Tracking.swift`, which is app-only.
///
/// This file is duplicated verbatim in the app and the extension because each
/// synchronized folder belongs to a single target; keep the two copies in sync.
@Model
final class TrackedParcel {
    var id: UUID = UUID()
    var trackingNumber: String = ""
    // Raw value of `TsuiseKit.Carrier`; kept as a String so the schema is
    // TsuiseKit-free. "japanpost" is `Carrier.japanPost.rawValue`.
    var carrierRaw: String = "japanpost"
    var nickname: String?
    var notes: String?
    var orderURL: String?
    var addedAt: Date = Date()
    var lastRefreshedAt: Date?

    // Cache the latest TrackingInfo as JSON so events don't need their own model.
    var cachedInfoData: Data?

    init(
        trackingNumber: String,
        carrierRaw: String,
        nickname: String? = nil,
        notes: String? = nil,
        orderURL: String? = nil
    ) {
        self.id = UUID()
        self.trackingNumber = trackingNumber
        self.carrierRaw = carrierRaw
        self.nickname = nickname
        self.notes = notes
        self.orderURL = orderURL
        self.addedAt = Date()
    }
}
