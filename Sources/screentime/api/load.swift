import Foundation

extension ScreenTimeAPI {
    public func loadScreenTime(id: String, year: Int, day: Int, key: PrivateKey) async throws -> ScreenTimeData {
        let response = try await sendSignedRequest(.GET, "time", id, year.description, day.description, key: key)
        guard let response = response else { throw APIError.invalidResponse }
        
        let screenTime = try JSONDecoder().decode(ScreenTimeData.self, from: response)
        return screenTime
    }
}
