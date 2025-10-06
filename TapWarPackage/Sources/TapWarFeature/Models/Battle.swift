import Foundation

struct Battle: Codable, Identifiable {
    let id: String // Format: "2025-10-05-14" (year-month-day-hour)
    let timestamp: Date
    let countries: [String: CountryBattleStats] // Key: country code

    var isActive: Bool {
        let now = Date()
        let endTime = timestamp.addingTimeInterval(10) // 10 second battle
        return now >= timestamp && now < endTime
    }

    static func currentBattleId() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }

    static func nextBattleTime() -> Date {
        let calendar = Calendar.current
        let now = Date()

        // Get current components in UTC
        var components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: now)

        // Set to next hour
        components.minute = 0
        components.second = 0
        components.nanosecond = 0

        if let currentHour = calendar.date(from: components) {
            if currentHour <= now {
                // Add one hour
                return calendar.date(byAdding: .hour, value: 1, to: currentHour)!
            }
            return currentHour
        }

        return now
    }
}

struct CountryBattleStats: Codable {
    var taps: Int
    var players: Int
    var intensity: Double // taps per player

    init(taps: Int = 0, players: Int = 0) {
        self.taps = taps
        self.players = players
        self.intensity = players > 0 ? Double(taps) / Double(players) : 0
    }

    mutating func addTaps(_ count: Int) {
        self.taps += count
        self.players += 1
        self.intensity = Double(taps) / Double(players)
    }
}

struct BattleSubmission: Codable {
    let battleId: String
    let countryCode: String
    let userId: String
    let taps: Int
    let timestamp: Date
}
