import ActivityKit
import Foundation

// Mirror of LangueDeChat/Models/ParcelActivityAttributes.swift — keep in sync.
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
