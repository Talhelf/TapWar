import Foundation

final class LocationService: @unchecked Sendable {
    static let shared = LocationService()

    private init() {}

    func getUserId() -> String {
        if let existingId = UserDefaults.standard.string(forKey: "userId") {
            return existingId
        }

        // Generate unique user ID
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: "userId")
        return newId
    }

    func detectCountry() async throws -> Country {
        // Use ipapi.co for free IP geolocation
        let url = URL(string: "https://ipapi.co/json/")!

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(IPAPIResponse.self, from: data)

        return Country(code: response.countryCode, name: response.countryName)
    }

    func getStoredCountry() -> UserCountry? {
        guard let data = UserDefaults.standard.data(forKey: "userCountry") else {
            return nil
        }

        return try? JSONDecoder().decode(UserCountry.self, from: data)
    }

    func saveCountry(_ country: Country, method: UserCountry.DetectionMethod) {
        let userCountry = UserCountry(
            country: country,
            confirmedAt: Date(),
            detectionMethod: method
        )

        if let encoded = try? JSONEncoder().encode(userCountry) {
            UserDefaults.standard.set(encoded, forKey: "userCountry")
        }
    }
}

struct IPAPIResponse: Codable {
    let countryCode: String
    let countryName: String

    enum CodingKeys: String, CodingKey {
        case countryCode = "country_code"
        case countryName = "country_name"
    }
}
