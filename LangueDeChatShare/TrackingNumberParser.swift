import Foundation

/// Extracts a carrier + tracking number from shared email text.
///
/// Kept dependency-free (Foundation only) so the share extension links nothing
/// but the system frameworks. Carrier is emitted as a raw string that matches
/// `TsuiseKit.Carrier`'s raw values (`yamato` / `sagawa` / `japanpost`); the app
/// maps it back with `Carrier(rawValue:)`.
enum TrackingNumberParser {
    struct Result {
        /// Raw value matching `TsuiseKit.Carrier`, or nil when undetermined.
        var carrier: String?
        /// Tracking number, separators stripped.
        var trackingNumber: String
    }

    // Carrier raw values — must stay in sync with TsuiseKit.Carrier.
    private static let yamato = "yamato"
    private static let sagawa = "sagawa"
    private static let japanPost = "japanpost"

    /// Keyword / URL signals that identify a carrier, richest-signal-first.
    private static let carrierSignals: [(carrier: String, needles: [String])] = [
        (yamato, ["kuronekoyamato.co.jp", "クロネコ", "ヤマト運輸", "ヤマト", "宅急便"]),
        (sagawa, ["sagawa-exp.co.jp", "佐川急便", "佐川", "飛脚"]),
        (japanPost, ["post.japanpost.jp", "japanpost.jp", "日本郵便", "ゆうパック",
                     "ゆうパケット", "レターパック", "クリックポスト"]),
    ]

    /// Labels that typically precede a tracking number in a shipping email.
    private static let numberLabels = [
        "お問い合わせ伝票番号", "問い合わせ伝票番号", "お問い合わせ番号",
        "追跡番号", "伝票番号", "送り状番号", "お荷物番号", "配達番号",
    ]

    // Japan Post international form, e.g. RR123456789JP — unambiguous.
    private static let intlPattern = "[A-Za-z]{2}[0-9]{9}[A-Za-z]{2}"
    // Domestic 12-digit number, optionally grouped 1234-5678-9012 / 1234 5678 9012.
    private static let grouped12Pattern = "[0-9]{4}[-\\s]?[0-9]{4}[-\\s]?[0-9]{4}"
    // Looser fallback: a run of 10–13 digits (allowing internal separators).
    private static let loosePattern = "[0-9]{10,13}"

    /// Parse shared text into a carrier + tracking number, or nil if none found.
    static func parse(_ text: String) -> Result? {
        guard !text.isEmpty else { return nil }

        // 1. Japan Post international number wins outright — it names its carrier.
        if let intl = firstMatch(of: intlPattern, in: text) {
            return Result(carrier: japanPost, trackingNumber: normalize(intl))
        }

        let carrier = detectCarrier(in: text)

        // 2. Prefer a number that follows a known label (most reliable position).
        if let labeled = numberNearLabel(in: text) {
            return Result(carrier: carrier, trackingNumber: normalize(labeled))
        }
        // 3. Otherwise a grouped 12-digit number anywhere.
        if let grouped = firstMatch(of: grouped12Pattern, in: text) {
            return Result(carrier: carrier, trackingNumber: normalize(grouped))
        }
        // 4. Last resort: any 10–13 digit run.
        if let loose = firstMatch(of: loosePattern, in: text) {
            return Result(carrier: carrier, trackingNumber: normalize(loose))
        }
        return nil
    }

    // MARK: - Helpers

    private static func detectCarrier(in text: String) -> String? {
        for signal in carrierSignals where signal.needles.contains(where: text.contains) {
            return signal.carrier
        }
        return nil
    }

    /// Finds the first number that appears shortly after any label keyword.
    private static func numberNearLabel(in text: String) -> String? {
        let ns = text as NSString
        for label in numberLabels {
            let labelRange = ns.range(of: label)
            guard labelRange.location != NSNotFound else { continue }
            let start = labelRange.location + labelRange.length
            let searchRange = NSRange(location: start, length: ns.length - start)
            // Look within a small window after the label so we don't grab an
            // unrelated number further down the message.
            let window = NSRange(location: start, length: min(60, searchRange.length))
            if let intl = firstMatch(of: intlPattern, in: ns, range: window) { return intl }
            if let grouped = firstMatch(of: grouped12Pattern, in: ns, range: window) { return grouped }
            if let loose = firstMatch(of: loosePattern, in: ns, range: window) { return loose }
        }
        return nil
    }

    private static func firstMatch(of pattern: String, in text: String) -> String? {
        let ns = text as NSString
        return firstMatch(of: pattern, in: ns, range: NSRange(location: 0, length: ns.length))
    }

    private static func firstMatch(of pattern: String, in ns: NSString, range: NSRange) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: ns as String, range: range) else { return nil }
        return ns.substring(with: match.range)
    }

    /// Strip separators so `1234-5678-9012` becomes `123456789012`.
    private static func normalize(_ raw: String) -> String {
        raw.filter { !$0.isWhitespace && $0 != "-" }
    }
}
