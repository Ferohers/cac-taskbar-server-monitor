import Foundation

struct ServerConfig: Codable, Identifiable {
    let id: UUID
    var name: String
    var hostname: String
    var username: String
    var password: String?
    var keyPath: String?
    var port: Int
    var isEnabled: Bool
    
    init(id: UUID = UUID(), name: String, hostname: String, username: String, password: String? = nil, keyPath: String? = nil, port: Int = 22, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.hostname = hostname
        self.username = username
        self.password = password
        self.keyPath = keyPath
        self.port = port
        self.isEnabled = isEnabled
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, hostname, username, password, keyPath, port, isEnabled
    }
}

struct ServerData {
    let config: ServerConfig
    var isConnected: Bool = false
    var lastUpdate: Date?
    var cpuUsage: Double?
    var memoryUsage: Double?
    var totalMemory: Double?
    var dockerContainers: [DockerContainer] = []
    var networkUpload: Double?
    var networkDownload: Double?
    var networkUploadStr: String?
    var networkDownloadStr: String?
    var previousNetworkUpload: Double?
    var previousNetworkDownload: Double?
    var previousNetworkTime: Date?
    var diskAvailableGB: Double?
    var diskUsagePercent: Double?
    var remoteIP: String?
    var error: String?
}

struct DockerContainer {
    let id: String
    let name: String
    let status: String
    let image: String
    let startTime: Date?
    
    var runtimeHours: Double? {
        guard let startTime = startTime else { return nil }
        return Date().timeIntervalSince(startTime) / 3600.0
    }
    
    init(id: String, name: String, status: String, image: String, startTime: Date? = nil) {
        self.id = id
        self.name = name
        self.status = status
        self.image = image
        self.startTime = startTime
    }
}

struct DiskInfo {
    let availableGB: Double
    let usagePercent: Double
    let totalGB: Double
}