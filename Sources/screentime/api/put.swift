import Foundation

extension ScreenTimeAPI {
    public func putScreenTime(_ screenTime: ScreenTimeData, id: String, year: Int, day: Int, key: PrivateKey) async throws {
        let body = try JSONEncoder().encode(screenTime)
        try await sendSignedRequest(.PUT, "time", id, year.description, day.description, body: body, key: key)
    }
}
