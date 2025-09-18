import Foundation

protocol SettingsManaging {
    // Notification Settings
    func getNotificationSettings(for serverID: UUID) -> ServerNotificationSettings?
    func getAllNotificationSettings() -> [ServerNotificationSettings]
    func saveNotificationSettings(_ settings: ServerNotificationSettings)
    func removeNotificationSettings(for serverID: UUID)
    func createDefaultNotificationSettings(for server: ServerConfig) -> ServerNotificationSettings
    
    // Advanced Settings
    func getAdvancedSettings() -> AdvancedSettings
    func saveAdvancedSettings(_ settings: AdvancedSettings)
    
    // Server Monitoring and Notifications
    func checkServerMetrics(for serverData: ServerData)
}