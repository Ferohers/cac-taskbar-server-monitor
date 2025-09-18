import Foundation

/// Adapter to make SettingsManager conform to SettingsManaging protocol
class SettingsManagerAdapter: SettingsManaging {
    private let originalManager: SettingsManager
    
    init(originalManager: SettingsManager) {
        self.originalManager = originalManager
    }
    
    // MARK: - SettingsManaging Implementation
    
    // Notification Settings
    func getNotificationSettings(for serverID: UUID) -> ServerNotificationSettings? {
        return originalManager.getNotificationSettings(for: serverID)
    }
    
    func getAllNotificationSettings() -> [ServerNotificationSettings] {
        return originalManager.getAllNotificationSettings()
    }
    
    func saveNotificationSettings(_ settings: ServerNotificationSettings) {
        originalManager.saveNotificationSettings(settings)
    }
    
    func removeNotificationSettings(for serverID: UUID) {
        originalManager.removeNotificationSettings(for: serverID)
    }
    
    func createDefaultNotificationSettings(for server: ServerConfig) -> ServerNotificationSettings {
        return originalManager.createDefaultNotificationSettings(for: server)
    }
    
    // Advanced Settings
    func getAdvancedSettings() -> AdvancedSettings {
        return originalManager.getAdvancedSettings()
    }
    
    func saveAdvancedSettings(_ settings: AdvancedSettings) {
        originalManager.saveAdvancedSettings(settings)
    }
    
    // Server Monitoring and Notifications
    func checkServerMetrics(for serverData: ServerData) {
        originalManager.checkServerMetrics(for: serverData)
    }
}