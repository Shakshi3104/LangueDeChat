import ActivityKit
import Foundation

struct ParcelActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: String
        var isDelivered: Bool
        var progressStep: Int
        var lastUpdated: Date
    }

    var trackingNumber: String
    var carrierName: String
    var parcelTitle: String
}
