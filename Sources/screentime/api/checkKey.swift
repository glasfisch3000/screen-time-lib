import Foundation

extension ScreenTimeAPI {
    public enum KeyType: String {
        case admin
        case user
        case viewer
        case none
    }
    
    public func checkKey(id: String, key: PublicKey) async throws -> KeyType? {
        let body = try JSONEncoder().encode(key)
        
        guard let response = try await sendRequest(.GET, "key", id, body: body) else { return nil }
        guard let responseData = response.getData(at: response.readerIndex, length: response.readableBytes) else { return nil }
        guard let responseString = String(data: responseData, encoding: .utf8) else { return nil }
        return .init(rawValue: responseString)
    }
}
