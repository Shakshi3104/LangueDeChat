import Foundation
import SwiftData
import TsuiseKit

@Model
final class TrackedParcel {
    var id: UUID = UUID()
    var trackingNumber: String = ""
    var carrierRaw: String = Carrier.japanPost.rawValue
    var nickname: String?
    var notes: String?
    var orderURL: String?
    var addedAt: Date = Date()
    var lastRefreshedAt: Date?

    // Cache the latest TrackingInfo as JSON so events don't need their own model.
    var cachedInfoData: Data?

    init(
        trackingNumber: String,
        carrier: Carrier,
        nickname: String? = nil,
        notes: String? = nil,
        orderURL: String? = nil
    ) {
        self.id = UUID()
        self.trackingNumber = trackingNumber
        self.carrierRaw = carrier.rawValue
        self.nickname = nickname
        self.notes = notes
        self.orderURL = orderURL
        self.addedAt = Date()
    }
}

extension TrackedParcel {
    var carrier: Carrier {
        Carrier(rawValue: carrierRaw) ?? .japanPost
    }

    var cachedInfo: TrackingInfo? {
        guard let data = cachedInfoData else { return nil }
        return try? JSONDecoder().decode(TrackingInfo.self, from: data)
    }

    func updateCache(with info: TrackingInfo) {
        cachedInfoData = try? JSONEncoder().encode(info)
        lastRefreshedAt = Date()
    }

    var titleText: String {
        nickname ?? carrier.displayName
    }

    var dateText: String {
        Self.listDateFormatter.string(from: cachedInfo?.events.last?.date ?? addedAt)
    }

    var displayName: String {
        nickname ?? "\(dateText), \(carrier.displayName)"
    }

    var currentStatus: String {
        cachedInfo?.currentStatus ?? "Pending"
    }

    /// Whether the parcel's latest status indicates final delivery.
    /// Carriers phrase this differently — 配達完了 (Yamato/Sagawa) and
    /// お届け済 / 配達済 / お届け完了 (Japan Post variants) all qualify.
    var isDelivered: Bool {
        Self.deliveryMarkers.contains { currentStatus.contains($0) }
    }

    /// When the parcel was actually delivered, derived from the cached events.
    /// Returns nil if no delivered event is found.
    var deliveredAt: Date? {
        guard isDelivered else { return nil }
        return cachedInfo?.events.first { event in
            Self.deliveryMarkers.contains { event.status.contains($0) }
        }?.date
    }

    var orderURLValue: URL? {
        guard let s = orderURL, !s.isEmpty else { return nil }
        return URL(string: s)
    }

    private static let deliveryMarkers = ["配達完了", "お届け済", "お届け完了", "配達済"]

    private static let listDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        f.dateFormat = "yyyy/MM/dd"
        return f
    }()
}
