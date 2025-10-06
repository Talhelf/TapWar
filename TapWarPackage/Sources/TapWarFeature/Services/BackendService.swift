import Foundation

final class BackendService: @unchecked Sendable {
    static let shared = BackendService()

    private let baseURL = "\(Config.supabaseURL)/rest/v1"
    private let apiKey = Config.supabaseAnonKey

    private init() {}

    func submitBattle(_ submission: BattleSubmission) async throws {
        // Step 1: Ensure battle exists
        try await ensureBattleExists(battleId: submission.battleId, timestamp: submission.timestamp)

        // Step 2: Upsert country stats (increment taps and players)
        try await upsertCountryStats(submission)
    }

    private func ensureBattleExists(battleId: String, timestamp: Date) async throws {
        guard let url = URL(string: "\(baseURL)/battles") else {
            throw BackendError.invalidURL
        }

        let battleData: [String: Any] = [
            "id": battleId,
            "timestamp": ISO8601DateFormatter().string(from: timestamp)
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: battleData)

        let (_, response) = try await URLSession.shared.data(for: request)

        // 201 = created, 409 = already exists (both OK)
        guard let httpResponse = response as? HTTPURLResponse,
              [201, 409].contains(httpResponse.statusCode) else {
            // Battle might already exist, that's fine
            return
        }
    }

    private func upsertCountryStats(_ submission: BattleSubmission) async throws {
        // Use RPC function for atomic increment
        guard let url = URL(string: "\(baseURL)/rpc/increment_country_taps") else {
            throw BackendError.invalidURL
        }

        let payload: [String: Any] = [
            "p_battle_id": submission.battleId,
            "p_country_code": submission.countryCode,
            "p_country_name": getCountryName(submission.countryCode),
            "p_user_id": submission.userId,
            "p_taps": submission.taps
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw BackendError.serverError
        }
    }

    func fetchLeaderboard(battleId: String = "all") async throws -> [CountryLeaderboardEntry] {
        guard let url = URL(string: "\(baseURL)/current_leaderboard?limit=50") else {
            throw BackendError.invalidURL
        }

        print("🔍 Fetching leaderboard from: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "apikey")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.serverError
        }

        print("📡 Response status: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ Error response: \(responseString)")
            }
            throw BackendError.serverError
        }

        if let responseString = String(data: data, encoding: .utf8) {
            print("✅ Raw response: \(responseString)")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let entries = try decoder.decode([SupabaseLeaderboardRow].self, from: data)

        print("✅ Decoded \(entries.count) entries")

        return entries.enumerated().map { index, row in
            CountryLeaderboardEntry(
                id: row.countryCode,
                country: Country(code: row.countryCode, name: row.countryName),
                stats: CountryBattleStats(
                    taps: row.totalTaps,
                    players: row.totalPlayers
                ),
                rank: index + 1
            )
        }
    }

    func resetAllStats() async throws {
        // Delete all data from tables
        let tables = ["user_taps", "country_stats", "battles"]

        for table in tables {
            guard let url = URL(string: "\(baseURL)/\(table)?select=*") else {
                throw BackendError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue(apiKey, forHTTPHeaderField: "apikey")
            request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("❌ Failed to delete from \(table)")
                throw BackendError.serverError
            }

            print("✅ Cleared table: \(table)")
        }
    }

    private func getCountryName(_ code: String) -> String {
        let countries: [String: String] = [
            "US": "United States", "IL": "Israel", "IN": "India",
            "GB": "United Kingdom", "CA": "Canada", "AU": "Australia",
            "DE": "Germany", "FR": "France", "BR": "Brazil", "MX": "Mexico"
        ]
        return countries[code] ?? code
    }
}

enum BackendError: Error {
    case invalidURL
    case serverError
    case decodingError
}

struct CountryLeaderboardEntry: Codable, Identifiable {
    let id: String // Country code
    let country: Country
    let stats: CountryBattleStats
    let rank: Int
}

struct SupabaseLeaderboardRow: Codable {
    let countryCode: String
    let countryName: String
    let totalTaps: Int
    let battlesParticipated: Int
    let totalPlayers: Int
    let intensity: Double
}
