import Foundation

struct ServerConfig: Codable, Identifiable {
    let id: UUID
    var name: String
    var hostname: String
    var username: String
    var port: Int
    var isEnabled: Bool
    
    // Keychain integration flags
    var hasKeychainPassword: Bool
    var hasKeychainSSHKey: Bool
    
    init(id: UUID = UUID(), name: String, hostname: String, username: String, port: Int = 22, isEnabled: Bool = true, hasKeychainPassword: Bool = false, hasKeychainSSHKey: Bool = false) {
        self.id = id
        self.name = name
        self.hostname = hostname
        self.username = username
        self.port = port
        self.isEnabled = isEnabled
        self.hasKeychainPassword = hasKeychainPassword
        self.hasKeychainSSHKey = hasKeychainSSHKey
    }
    
    // Computed properties for authentication method
    var authenticationMethod: AuthenticationMethod {
        if hasKeychainSSHKey {
            return .sshKey
        } else if hasKeychainPassword {
            return .password
        } else {
            return .none
        }
    }
    
    var hasCredentials: Bool {
        return hasKeychainPassword || hasKeychainSSHKey
    }
}

enum AuthenticationMethod {
    case password
    case sshKey
    case none
    
    var displayName: String {
        switch self {
        case .password:
            return "Password"
        case .sshKey:
            return "SSH Key"
        case .none:
            return "None"
        }
    }
}

struct ServerData {
    let config: ServerConfig
    var isConnected: Bool = false
    var lastUpdate: Date?
    var cpuUsage: Float?
    var memoryUsage: Float?
    var totalMemory: Float?
    var dockerContainers: [DockerContainer] = []
    var networkUpload: UInt64?
    var networkDownload: UInt64?
    var networkUploadStr: String?
    var networkDownloadStr: String?
    var previousNetworkUpload: UInt64?
    var previousNetworkDownload: UInt64?
    var previousNetworkTime: Date?
    var diskAvailableGB: Float?
    var diskUsagePercent: Float?
    var remoteIP: String?
    var error: String?
    var pingTime: Float?
    var previousCPUTotal: UInt64?
    var previousCPUIdle: UInt64?
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
    let availableGB: Float
    let usagePercent: Float
    let totalGB: Float
}