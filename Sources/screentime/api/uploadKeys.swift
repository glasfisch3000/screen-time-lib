import Foundation

extension ScreenTimeAPI {
    public func uploadKeys(id: String, keys: KeySet<PrivateKey>, master: PrivateKey) async throws {
        let publicKeys = keys.map(\.publicKey)
        let body = try JSONEncoder().encode(publicKeys)
        
        try await sendSignedRequest(.PUT, "keys", id, body: body, key: master)
    }
}
