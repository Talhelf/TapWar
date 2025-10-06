import Foundation
import SwiftUI

@MainActor
class LeaderboardViewModel: ObservableObject {
    @Published var leaderboard: [CountryLeaderboardEntry] = []
    @Published var selectedTab: LeaderboardTab = .total
    @Published var isLoading: Bool = false
    @Published var userCountryRank: Int?

    private var refreshTimer: Timer?

    enum LeaderboardTab {
        case total
        case intensity
    }

    init() {
        startAutoRefresh()
    }

    func startAutoRefresh() {
        refreshTimer?.invalidate()

        // Refresh every 5 seconds for free tapping mode
        let interval: TimeInterval = 5

        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchLeaderboard()
            }
        }

        Task {
            await fetchLeaderboard()
        }
    }

    private func shouldRefreshFrequently() -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: now)

        if let minute = components.minute {
            // Refresh frequently from 5 min before to 5 min after the hour
            return minute >= 55 || minute <= 5
        }

        return false
    }

    func fetchLeaderboard() async {
        isLoading = true

        do {
            let battleId = Battle.currentBattleId()
            let entries = try await BackendService.shared.fetchLeaderboard(battleId: battleId)

            // Sort based on selected tab
            let sorted = sortLeaderboard(entries)

            leaderboard = sorted

            // Find user's country rank
            if let userCountry = LocationService.shared.getStoredCountry()?.country {
                userCountryRank = sorted.firstIndex(where: { $0.country.id == userCountry.id }).map { $0 + 1 }
            }

        } catch {
            print("❌ Failed to fetch leaderboard: \(error)")
            if let urlError = error as? URLError {
                print("URLError code: \(urlError.code)")
            }
            // For now, show empty instead of mock data
            leaderboard = []
        }

        isLoading = false
    }

    private func sortLeaderboard(_ entries: [CountryLeaderboardEntry]) -> [CountryLeaderboardEntry] {
        let sorted: [CountryLeaderboardEntry]

        switch selectedTab {
        case .total:
            sorted = entries.sorted { $0.stats.taps > $1.stats.taps }
        case .intensity:
            sorted = entries.sorted { $0.stats.intensity > $1.stats.intensity }
        }

        // Assign ranks
        return sorted.enumerated().map { index, entry in
            var updatedEntry = entry
            var mutableEntry = CountryLeaderboardEntry(
                id: entry.id,
                country: entry.country,
                stats: entry.stats,
                rank: index + 1
            )
            return mutableEntry
        }
    }

    func changeTab(_ tab: LeaderboardTab) {
        selectedTab = tab
        leaderboard = sortLeaderboard(leaderboard)
    }

    private func generateMockLeaderboard() -> [CountryLeaderboardEntry] {
        // Mock data for testing UI
        let countries = [
            ("US", "United States", 1234567, 12543),
            ("IN", "India", 987654, 15432),
            ("IL", "Israel", 52341, 1003),
            ("GB", "United Kingdom", 345678, 8765),
            ("CA", "Canada", 234567, 5432),
            ("AU", "Australia", 123456, 3456),
            ("DE", "Germany", 456789, 9876),
            ("FR", "France", 345678, 7654),
            ("BR", "Brazil", 567890, 11234),
            ("MX", "Mexico", 234567, 6543),
        ]

        return countries.map { code, name, taps, players in
            CountryLeaderboardEntry(
                id: code,
                country: Country(code: code, name: name),
                stats: CountryBattleStats(taps: taps, players: players),
                rank: 0
            )
        }
    }

    func cleanup() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
