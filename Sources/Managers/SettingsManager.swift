import Foundation

class SettingsManager {
    static let shared = SettingsManager()
    
    private let notificationSettingsKey = "NotificationSettings"
    private let advancedSettingsKey = "AdvancedSettings"
    private let userDefaults = UserDefaults.standard
    
    private init() {}
    
    // MARK: - Notification Settings
    
    func getNotificationSettings(for serverID: UUID) -> ServerNotificationSettings? {
        guard let data = userDefaults.data(forKey: notificationSettingsKey),
              let allSettings = try? JSONDecoder().decode([ServerNotificationSettings].self, from: data) else {
            return nil
        }
        
        return allSettings.first { $0.serverID == serverID }
    }
    
    func getAllNotificationSettings() -> [ServerNotificationSettings] {
        guard let data = userDefaults.data(forKey: notificationSettingsKey),
              let settings = try? JSONDecoder().decode([ServerNotificationSettings].self, from: data) else {
            return []
        }
        return settings
    }
    
    func saveNotificationSettings(_ settings: ServerNotificationSettings) {
        var allSettings = getAllNotificationSettings()
        
        // Remove existing settings for this server
        allSettings.removeAll { $0.serverID == settings.serverID }
        
        // Add new settings
        allSettings.append(settings)
        
        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(allSettings) {
            userDefaults.set(data, forKey: notificationSettingsKey)
        }
    }
    
    func removeNotificationSettings(for serverID: UUID) {
        var allSettings = getAllNotificationSettings()
        allSettings.removeAll { $0.serverID == serverID }
        
        if let data = try? JSONEncoder().encode(allSettings) {
            userDefaults.set(data, forKey: notificationSettingsKey)
        }
        
        // Also clear any notifications for this server
        NotificationManager.shared.clearNotifications(for: serverID)
    }
    
    func createDefaultNotificationSettings(for server: ServerConfig) -> ServerNotificationSettings {
        let settings = ServerNotificationSettings(serverID: server.id, serverName: server.name)
        saveNotificationSettings(settings)
        return settings
    }
    
    // MARK: - Advanced Settings
    
    func getAdvancedSettings() -> AdvancedSettings {
        guard let data = userDefaults.data(forKey: advancedSettingsKey),
              let settings = try? JSONDecoder().decode(AdvancedSettings.self, from: data) else {
            return AdvancedSettings()
        }
        return settings
    }
    
    func saveAdvancedSettings(_ settings: AdvancedSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: advancedSettingsKey)
        }
    }
    
    // MARK: - Server Monitoring and Notifications
    
    func checkServerMetrics(for serverData: ServerData) {
        guard let notificationSettings = getNotificationSettings(for: serverData.config.id) else {
            // Create default settings if none exist
            _ = createDefaultNotificationSettings(for: serverData.config)
            checkServerMetrics(for: serverData) // Retry with new settings
            return
        }
        
        let settings = notificationSettings.settings
        
        // Skip if notifications are disabled for this server
        guard settings.isEnabled else {
            return
        }
        
        print("🔍 Checking metrics for server: \(serverData.config.name)")
        
        // Check connection status
        checkConnectionStatus(serverData: serverData, settings: settings)
        
        // Check performance metrics if enabled
        if settings.performanceAlerts {
            checkPerformanceMetrics(serverData: serverData, settings: settings)
        }
    }
    
    private func checkConnectionStatus(serverData: ServerData, settings: NotificationSettings) {
        guard settings.connectionAlerts else { return }
        
        // Track connection state changes and send notifications
        let connectionKey = "connection_\(serverData.config.id.uuidString)"
        let wasConnected = userDefaults.bool(forKey: "\(connectionKey)_previous")
        let isConnected = serverData.isConnected
        
        // Only send notification if connection state changed
        if wasConnected != isConnected {
            NotificationManager.shared.sendConnectionAlert(
                serverName: serverData.config.name,
                serverID: serverData.config.id,
                isConnected: isConnected
            )
            
            userDefaults.set(isConnected, forKey: "\(connectionKey)_previous")
        }
    }
    
    private func checkPerformanceMetrics(serverData: ServerData, settings: NotificationSettings) {
        // Check CPU usage
        if let cpuUsage = serverData.cpuUsage, cpuUsage > settings.cpuThreshold {
            NotificationManager.shared.sendServerAlert(
                title: "High CPU Usage",
                message: "Server '\(serverData.config.name)' CPU usage is \(String(format: "%.1f", cpuUsage))% (threshold: \(String(format: "%.1f", settings.cpuThreshold))%)",
                serverName: serverData.config.name,
                serverID: serverData.config.id,
                alertType: "cpu"
            )
        }
        
        // Check Memory usage
        if let memoryUsage = serverData.memoryUsage, memoryUsage > settings.memoryThreshold {
            NotificationManager.shared.sendServerAlert(
                title: "High Memory Usage",
                message: "Server '\(serverData.config.name)' memory usage is \(String(format: "%.1f", memoryUsage))% (threshold: \(String(format: "%.1f", settings.memoryThreshold))%)",
                serverName: serverData.config.name,
                serverID: serverData.config.id,
                alertType: "memory"
            )
        }
        
        // Check Disk space
        if let diskAvailable = serverData.diskAvailableGB, diskAvailable < settings.diskThreshold {
            NotificationManager.shared.sendServerAlert(
                title: "Low Disk Space",
                message: "Server '\(serverData.config.name)' has only \(String(format: "%.1f", diskAvailable)) GB remaining (threshold: \(String(format: "%.1f", settings.diskThreshold)) GB)",
                serverName: serverData.config.name,
                serverID: serverData.config.id,
                alertType: "disk"
            )
        }
    }
}