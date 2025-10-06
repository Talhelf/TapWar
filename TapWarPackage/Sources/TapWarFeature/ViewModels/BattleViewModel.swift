import Foundation
import SwiftUI

@MainActor
class BattleViewModel: ObservableObject {
    @Published var tapCount: Int = 0
    @Published var totalTapsAllTime: Int = 0

    init() {
        loadStats()
    }

    private func loadStats() {
        totalTapsAllTime = UserDefaults.standard.integer(forKey: "totalTapsAllTime")
    }

    func tap() {
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        tapCount += 1
        totalTapsAllTime += 1

        // Save every 10 taps to avoid too many writes
        if tapCount % 10 == 0 {
            saveStats()
        }

        // Submit every 10 taps (for testing)
        if tapCount % 10 == 0 {
            submitTaps()
        }
    }

    private func saveStats() {
        UserDefaults.standard.set(totalTapsAllTime, forKey: "totalTapsAllTime")
    }

    private func submitTaps() {
        guard let country = LocationService.shared.getStoredCountry()?.country else {
            return
        }

        let battleId = Battle.currentBattleId()
        let userId = LocationService.shared.getUserId()
        let submission = BattleSubmission(
            battleId: battleId,
            countryCode: country.id,
            userId: userId,
            taps: 10, // Submit in batches of 10
            timestamp: Date()
        )

        Task {
            do {
                try await BackendService.shared.submitBattle(submission)
                print("✅ Submitted 10 taps for \(country.name). Total: \(totalTapsAllTime)")
            } catch {
                print("❌ Failed to submit taps: \(error). URL: \(error)")
            }
        }
    }

    func cleanup() {
        saveStats()
    }
}
