import SwiftUI

public struct TapView: View {
    @StateObject private var viewModel = BattleViewModel()
    @State private var userCountry: Country?
    @State private var showCountryPicker = false
    @State private var tapScale: CGFloat = 1.0

    public init() {}

    public var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                // Header
                VStack(spacing: 8) {
                    if let country = userCountry {
                        Text("\(country.flag) \(country.name)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }

                    VStack(spacing: 4) {
                        Text("Total Taps")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))

                        Text("\(viewModel.totalTapsAllTime)")
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundColor(.yellow)
                    }
                }
                .padding(.top, 60)

                Spacer()

                // Tap Button
                VStack(spacing: 16) {
                    Button(action: {
                        viewModel.tap()
                        withAnimation(.easeInOut(duration: 0.1)) {
                            tapScale = 0.9
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                tapScale = 1.0
                            }
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.green, Color.blue]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 250, height: 250)
                                .shadow(color: .green.opacity(0.5), radius: 20)

                            Text("TAP")
                                .font(.system(size: 60, weight: .black))
                                .foregroundColor(.white)
                        }
                    }
                    .scaleEffect(tapScale)

                    // Session tap counter
                    if viewModel.tapCount > 0 {
                        Text("\(viewModel.tapCount) taps this session")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(20)
                    }
                }

                Spacer()

                // Bottom info
                Text("Tap to represent your country!")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer().frame(height: 40)
            }
        }
        .onAppear {
            loadUserCountry()
        }
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerView(onSelect: { country in
                userCountry = country
                LocationService.shared.saveCountry(country, method: .manual)
                showCountryPicker = false
            })
        }
    }

    private func loadUserCountry() {
        if let stored = LocationService.shared.getStoredCountry() {
            userCountry = stored.country
        } else {
            // Detect country
            Task {
                do {
                    let detected = try await LocationService.shared.detectCountry()
                    await MainActor.run {
                        userCountry = detected
                        showCountryPicker = true // Ask for confirmation
                    }
                } catch {
                    print("Failed to detect country: \(error)")
                    // Show manual picker
                    await MainActor.run {
                        showCountryPicker = true
                    }
                }
            }
        }
    }
}

// Simple country picker for MVP
struct CountryPickerView: View {
    let onSelect: (Country) -> Void
    @Environment(\.dismiss) var dismiss

    // Popular countries for MVP
    let countries = [
        Country(code: "US", name: "United States"),
        Country(code: "IL", name: "Israel"),
        Country(code: "IN", name: "India"),
        Country(code: "GB", name: "United Kingdom"),
        Country(code: "CA", name: "Canada"),
        Country(code: "AU", name: "Australia"),
        Country(code: "DE", name: "Germany"),
        Country(code: "FR", name: "France"),
        Country(code: "BR", name: "Brazil"),
        Country(code: "MX", name: "Mexico"),
    ]

    var body: some View {
        NavigationView {
            List(countries) { country in
                Button(action: {
                    onSelect(country)
                }) {
                    HStack {
                        Text(country.flag)
                            .font(.largeTitle)
                        Text(country.name)
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Select Your Country")
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
        }
    }
}

// Personal stats widget
struct PersonalStatsWidget: View {
    let country: Country
    let lastBattleTaps: Int

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Contribution")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    HStack(spacing: 4) {
                        Text(country.flag)
                            .font(.body)
                        Text(country.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                }

                Spacer()

                if lastBattleTaps > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(lastBattleTaps)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.yellow)

                        Text("taps")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.15))
        .cornerRadius(12)
    }
}
