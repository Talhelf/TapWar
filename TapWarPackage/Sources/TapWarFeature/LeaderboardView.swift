import SwiftUI

public struct LeaderboardView: View {
    @StateObject private var viewModel = LeaderboardViewModel()
    @State private var userCountry: Country?
    @State private var showResetConfirm = false

    public init() {}

    public var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    HStack {
                        Text("Global Rankings")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Spacer()

                        // Reset button (for development)
                        Button(action: {
                            showResetConfirm = true
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red.opacity(0.8))
                                .font(.title3)
                        }
                    }
                    .padding(.horizontal, 16)

                    // Tab selector
                    HStack(spacing: 0) {
                        TabButton(
                            title: "TOTAL TAPS",
                            isSelected: viewModel.selectedTab == .total,
                            action: { viewModel.changeTab(.total) }
                        )

                        TabButton(
                            title: "INTENSITY",
                            isSelected: viewModel.selectedTab == .intensity,
                            action: { viewModel.changeTab(.intensity) }
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .padding(.top, 60)
                .padding(.bottom, 16)

                // User's country rank card
                if let rank = viewModel.userCountryRank, let country = userCountry {
                    UserRankCard(country: country, rank: rank)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }

                // Leaderboard list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if viewModel.isLoading && viewModel.leaderboard.isEmpty {
                            ProgressView()
                                .tint(.white)
                                .padding(.top, 40)
                        } else if viewModel.leaderboard.isEmpty {
                            VStack(spacing: 16) {
                                Text("No data yet")
                                    .foregroundColor(.white.opacity(0.8))
                                    .font(.headline)

                                Text("Start tapping to see rankings!")
                                    .foregroundColor(.white.opacity(0.6))
                                    .font(.subheadline)

                                Button("Refresh") {
                                    Task {
                                        await viewModel.fetchLeaderboard()
                                    }
                                }
                                .foregroundColor(.yellow)
                                .padding(.top, 8)
                            }
                            .padding(.top, 40)
                        } else {
                            ForEach(Array(viewModel.leaderboard.prefix(20).enumerated()), id: \.element.id) { index, entry in
                                LeaderboardRow(
                                    entry: entry,
                                    isUserCountry: entry.country.id == userCountry?.id,
                                    showIntensity: viewModel.selectedTab == .intensity
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
                .refreshable {
                    print("🔄 Manual refresh triggered")
                    await viewModel.fetchLeaderboard()
                }
            }
        }
        .onAppear {
            loadUserCountry()
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .alert("Reset All Stats?", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                Task {
                    do {
                        try await BackendService.shared.resetAllStats()
                        await viewModel.fetchLeaderboard()
                    } catch {
                        print("❌ Failed to reset stats: \(error)")
                    }
                }
            }
        } message: {
            Text("This will delete all data from the database including all countries, players, and taps. This cannot be undone.")
        }
    }

    private func loadUserCountry() {
        if let stored = LocationService.shared.getStoredCountry() {
            userCountry = stored.country
        }
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    isSelected
                        ? Color.white.opacity(0.2)
                        : Color.clear
                )
                .overlay(
                    Rectangle()
                        .fill(isSelected ? Color.white : Color.clear)
                        .frame(height: 3),
                    alignment: .bottom
                )
        }
    }
}

struct UserRankCard: View {
    let country: Country
    let rank: Int

    var body: some View {
        HStack {
            Text(country.flag)
                .font(.title)

            VStack(alignment: .leading, spacing: 4) {
                Text(country.name)
                    .font(.headline)
                    .foregroundColor(.white)

                Text("Your Country Rank")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            Text("#\(rank)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.yellow)
        }
        .padding(16)
        .background(Color.white.opacity(0.15))
        .cornerRadius(12)
    }
}

struct LeaderboardRow: View {
    let entry: CountryLeaderboardEntry
    let isUserCountry: Bool
    let showIntensity: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text("\(entry.rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(rankColor)
                .frame(width: 30, alignment: .leading)

            // Flag
            Text(entry.country.flag)
                .font(.title2)

            // Country name
            Text(entry.country.name)
                .font(.body)
                .fontWeight(isUserCountry ? .bold : .regular)
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            // Stats
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatNumber(showIntensity ? Int(entry.stats.intensity) : entry.stats.taps))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                if showIntensity {
                    Text("per player")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                } else {
                    Text("\(formatNumber(entry.stats.players)) players")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            isUserCountry
                ? Color.yellow.opacity(0.2)
                : Color.white.opacity(0.1)
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isUserCountry ? Color.yellow : Color.clear, lineWidth: 2)
        )
    }

    private var rankColor: Color {
        switch entry.rank {
        case 1: return .yellow
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75) // Silver
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2) // Bronze
        default: return .white
        }
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}
