import Foundation
import TsuiseKit

/// Values pulled from a `languedechat://add` deep link to pre-fill AddParcelView.
/// Identifiable so it can drive a `.sheet(item:)`.
struct AddParcelPrefill: Identifiable {
    let id = UUID()
    var carrier: Carrier?
    var trackingNumber: String
}

/// Parses the `languedechat://` deep links opened by the share extension.
enum DeepLink {
    /// `languedechat://add?number=123456789012&carrier=yamato`
    /// Returns nil unless the URL is a well-formed add link with a number.
    static func parseAdd(_ url: URL) -> AddParcelPrefill? {
        guard url.scheme == "languedechat", url.host == "add" else { return nil }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let number = items.first { $0.name == "number" }?
            .value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !number.isEmpty else { return nil }
        let carrier = items.first { $0.name == "carrier" }?.value
            .flatMap(Carrier.init(rawValue:))
        return AddParcelPrefill(carrier: carrier, trackingNumber: number)
    }
}
