import Foundation

struct Country: Codable, Identifiable, Equatable {
    let id: String // Country code (e.g., "US", "IL")
    let name: String
    let flag: String // Emoji flag

    init(code: String, name: String) {
        self.id = code
        self.name = name
        self.flag = Country.flagEmoji(for: code)
    }

    static func flagEmoji(for countryCode: String) -> String {
        let base: UInt32 = 127397
        var emoji = ""
        for scalar in countryCode.uppercased().unicodeScalars {
            if let scalarValue = UnicodeScalar(base + scalar.value) {
                emoji.append(String(scalarValue))
            }
        }
        return emoji
    }
}

// User's stored country preference
struct UserCountry: Codable {
    let country: Country
    let confirmedAt: Date
    let detectionMethod: DetectionMethod

    enum DetectionMethod: String, Codable {
        case ip
        case manual
    }
}
