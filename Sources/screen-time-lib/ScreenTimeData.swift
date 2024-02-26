public struct ScreenTimeData: Hashable, Codable {
    public var available: Int
    public var used: Int
    
    init(available: Int = 0, used: Int = 0) {
        self.available = available
        self.used = used
    }
}
