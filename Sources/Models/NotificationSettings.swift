import Foundation

// MARK: - Notification Settings Models

struct NotificationSettings: Codable {
    var isEnabled: Bool = false  // Disabled by default for new users
    var connectionAlerts: Bool = false  // Disabled by default for new users
    var performanceAlerts: Bool = false  // Disabled by default for new users
    var systemAlerts: Bool = false  // Disabled by default for new users
    
    // Performance thresholds (when performanceAlerts is enabled)
    // Updated to allow 0-100 range per user request
    var cpuThreshold: Float = 85.0
    var memoryThreshold: Float = 85.0
    var diskThreshold: Float = 2.0 // GB remaining
    
    init() {}
}

struct ServerNotificationSettings: Codable, Identifiable {
    let id: UUID
    let serverID: UUID
    var serverName: String
    var settings: NotificationSettings
    
    init(serverID: UUID, serverName: String) {
        self.id = UUID()
        self.serverID = serverID
        self.serverName = serverName
        self.settings = NotificationSettings()
    }
}

// MARK: - Advanced Settings Models

struct AdvancedSettings: Codable {
    var showInactiveDockerContainers: Bool = false
    var customRefreshEnabled: Bool = false
    var refreshIntervalSeconds: Double = 30.0 // Default 30 seconds
    
    init() {}
}

