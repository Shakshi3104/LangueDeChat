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

enum DeliveryStage: Int, CaseIterable {
    case received = 0
    case inTransit = 1
    case atHub = 2
    case outForDelivery = 3
    case delivered = 4
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
    /// Carriers phrase this differently — 配達完了 (Yamato/Sagawa),
    /// お届け済 / 配達済 / お届け完了 (Japan Post variants), and
    /// 引渡完了 (Sagawa hand-off, e.g. after a 受取先変更) all qualify.
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

    /// Delivery stage index (0–4) for Live Activity progress bar.
    /// 0: Received  1: In Transit  2: At Hub  3: Out for Delivery  4: Delivered
    var progressStep: DeliveryStage {
        let s = currentStatus
        if isDelivered { return .delivered }
        if ["持ち出し中", "配達中"].contains(where: { s.contains($0) }) { return .outForDelivery }
        // Includes failed attempts (ご不在/持戻), holds (保管中),
        // reschedules (日時変更/依頼受付), and investigation (調査中).
        if ["到着", "支店", "営業所", "作業店", "センター", "配達店",
            "保管中", "持戻", "ご不在", "日時変更", "依頼受付", "調査中",
            "受取場所"].contains(where: { s.contains($0) }) { return .atHub }
        if ["輸送中", "幹線", "発送", "積み込み"].contains(where: { s.contains($0) }) { return .inTransit }
        return .received
    }

    private static let deliveryMarkers = ["配達完了", "お届け済", "お届け完了", "配達済", "引渡完了"]

    private static let listDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        f.dateFormat = "yyyy/MM/dd"
        return f
    }()
}
