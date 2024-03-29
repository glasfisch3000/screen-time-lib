import Vapor
import Crypto

public struct ScreenTimeAPI {
    public typealias PrivateKey = Curve25519.Signing.PrivateKey
    public typealias PublicKey = Curve25519.Signing.PublicKey
    
    public struct KeySet<Key> {
        public var admin: Key
        public var users: [Key]
        public var viewers: [Key]
        
        public init(admin: Key, users: [Key], viewers: [Key]) {
            self.admin = admin
            self.users = users
            self.viewers = viewers
        }
        
        public func map<Result>(_ transform: @escaping (Key) throws -> Result) rethrows -> KeySet<Result> {
            KeySet<Result>(
                admin: try transform(self.admin),
                users: try self.users.map(transform),
                viewers: try self.viewers.map(transform)
            )
        }
    }
    
    public struct SignatureData: Codable {
        public var timestamp: TimeInterval
        public var signature: Data
    }
    
    public enum APIError: Error {
        case unableToEncode
        case unableToSign
        case invalidResponse
        case invalidResponseStatus(_ status: HTTPResponseStatus)
    }
    
    public var scheme: String
    public var host: String
    
    public init(scheme: String, host: String) {
        self.scheme = scheme
        self.host = host
    }
    
    @discardableResult
    public func sendRequest(_ method: HTTPMethod, _ components: String..., body: Data? = nil) async throws -> ByteBuffer? {
        var encodedComponents: [String] = []
        for component in components {
            let encoded = component.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)
            guard let encoded = encoded else { throw APIError.unableToEncode }
            
            encodedComponents.append(encoded)
        }
        
        let url = "\(self.scheme)://\(self.host)/\(encodedComponents.joined(separator: "/"))"
        
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
    
    @discardableResult
    public func sendSignedRequest(_ method: HTTPMethod, _ components: String..., body: Data? = nil, key: PrivateKey) async throws -> ByteBuffer? {
        var encodedComponents: [String] = []
        for component in components {
            let encoded = component.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)
            guard let encoded = encoded else { throw APIError.unableToEncode }
            
            encodedComponents.append(encoded)
        }
        
        let signature = try Self.createSignature([method.rawValue] + components, body: body, key: key)
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
    
    public static func createSignature(_ components: [String], body: Data?, key: PrivateKey) throws -> SignatureData {
        let timestamp = Date().timeIntervalSince1970
        
        let newComponents = components + [timestamp.description]
        let componentsString = newComponents.joined(separator: ":")
        
        guard var dataToSign = componentsString.data(using: .utf8) else { throw APIError.unableToSign }
        
        if let body = body { dataToSign += body }
        
        let signature = try key.signature(for: dataToSign)
        return SignatureData(timestamp: timestamp, signature: signature)
    }
    
    public enum SignatureVerificationResult {
        case valid
        case invalid
        case outdated
    }
    
    public static func verifySignature(_ components: [String], body: Data?, signature: SignatureData, keys: [PublicKey]) throws -> SignatureVerificationResult {
        guard (0...2).contains(Date().timeIntervalSince1970 - signature.timestamp) else { return .outdated }
        
        let newComponents = components + [signature.timestamp.description]
        let componentsString = newComponents.joined(separator: ":")
        
        guard var dataToSign = componentsString.data(using: .utf8) else { throw APIError.unableToSign }
        
        if let body = body { dataToSign += body }
        
        for key in keys {
            if key.isValidSignature(signature.signature, for: dataToSign) { return .valid }
        }
        
        return .invalid
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
