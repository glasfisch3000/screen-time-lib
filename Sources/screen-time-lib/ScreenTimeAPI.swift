import Vapor
import Crypto

struct ScreenTimeAPI {
    typealias PrivateKey = Curve25519.Signing.PrivateKey
    typealias PublicKey = Curve25519.Signing.PublicKey
    
    struct KeySet<Key> {
        var admin: Key
        var users: [Key]
        var viewers: [Key]
        
        init(admin: Key, users: [Key], viewers: [Key]) {
            self.admin = admin
            self.users = users
            self.viewers = viewers
        }
        
        func map<Result>(_ transform: @escaping (Key) throws -> Result) rethrows -> KeySet<Result> {
            KeySet<Result>(
                admin: try transform(self.admin),
                users: try self.users.map(transform),
                viewers: try self.viewers.map(transform)
            )
        }
    }
    
    struct SignatureData: Codable {
        var timestamp: TimeInterval
        var signature: Data
    }
    
    enum APIError: Error {
        case unableToEncode
        case unableToSign
        case invalidResponse
        case invalidResponseStatus(_ status: HTTPResponseStatus)
    }
    
    var scheme: String
    var host: String
    
    func loadScreenTime(id: String, year: Int, day: Int, keys: KeySet<PrivateKey>) async throws -> ScreenTimeData {
        let response = try await sendRequest(.GET, "time", id, year.description, day.description, key: keys.admin)
        guard let response = response else { throw APIError.invalidResponse }
        
        let screenTime = try JSONDecoder().decode(ScreenTimeData.self, from: response)
        return screenTime
    }
    
    func putScreenTime(_ screenTime: ScreenTimeData, id: String, year: Int, day: Int, keys: KeySet<PrivateKey>) async throws {
        let body = try JSONEncoder().encode(screenTime)
        try await sendRequest(.PUT, "time", id, year.description, day.description, body: body, key: keys.admin)
    }
    
    func uploadKeys(id: String, keys: KeySet<PrivateKey>, master: PrivateKey) async throws {
        let publicKeys = keys.map(\.publicKey)
        let body = try JSONEncoder().encode(publicKeys)
        
        guard let masterKeyString = UserDefaults.standard.string(forKey: "master-key") else { throw APIError.unableToSign }
        guard let masterKey = PrivateKey(rawValue: masterKeyString) else { throw APIError.unableToSign }
        
        try await sendRequest(.PUT, "keys", id, body: body, key: masterKey)
    }
    
    public func createSignature(_ components: [String], body: Data?, key: PrivateKey) throws -> SignatureData {
        let timestamp = Date().timeIntervalSince1970
        
        let newComponents = components + [timestamp.description]
        let componentsString = newComponents.joined(separator: ":")
        
        guard var dataToSign = componentsString.data(using: .utf8) else { throw APIError.unableToSign }
        
        if let body = body { dataToSign += body }
        
        let signature = try key.signature(for: dataToSign)
        return SignatureData(timestamp: timestamp, signature: signature)
    }
    
    @discardableResult
    public func sendRequest(_ method: HTTPMethod, _ components: String..., body: Data? = nil, key: PrivateKey) async throws -> ByteBuffer? {
        var encodedComponents: [String] = []
        for component in components {
            let encoded = component.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)
            guard let encoded = encoded else { throw APIError.unableToEncode }
            
            encodedComponents.append(encoded)
        }
        
        let signature = try createSignature([method.rawValue] + components, body: body, key: key)
        let signatureString = try URLEncodedFormEncoder().encode(signature)
        
        let url = "\(self.scheme)://\(self.host)/\(encodedComponents.joined(separator: "/"))?\(signatureString)"
        
        let requestBody: HTTPClient.Body?
        if let body = body {
            requestBody = .data(body)
        } else {
            requestBody = nil
        }
        
        let client = AsyncHTTPClient.HTTPClient()
        defer { Task { try? await client.shutdown().get() } }
        
        let response = try await client.execute(method, url: url, body: requestBody).get()
        guard response.status == .ok else { throw APIError.invalidResponseStatus(response.status) }
        
        return response.body
    }
}

extension ScreenTimeAPI.PrivateKey: RawRepresentable {
    public var rawValue: String { rawRepresentation.base64EncodedString() }
    
    public init?(rawValue: String) {
        guard let encoded = rawValue.data(using: .utf8) else { return nil }
        guard let data = Data(base64Encoded: encoded) else { return nil }
        try? self.init(rawRepresentation: data)
    }
}

extension ScreenTimeAPI.PublicKey: RawRepresentable {
    public var rawValue: String { rawRepresentation.base64EncodedString() }
    
    public init?(rawValue: String) {
        guard let encoded = rawValue.data(using: .utf8) else { return nil }
        guard let data = Data(base64Encoded: encoded) else { return nil }
        try? self.init(rawRepresentation: data)
    }
}

extension ScreenTimeAPI.PrivateKey: Codable { }
extension ScreenTimeAPI.PublicKey: Codable { }

extension ScreenTimeAPI.KeySet: Equatable where Key: Equatable { }
extension ScreenTimeAPI.KeySet: Hashable where Key: Hashable { }
extension ScreenTimeAPI.KeySet: Encodable where Key: Encodable { }
extension ScreenTimeAPI.KeySet: Decodable where Key: Decodable { }
