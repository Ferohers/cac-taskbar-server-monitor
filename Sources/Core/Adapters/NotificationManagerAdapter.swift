import Foundation

/// Adapter to make NotificationManager conform to NotificationManaging protocol
class NotificationManagerAdapter: NotificationManaging {
    private let originalManager: NotificationManager
    
    init(originalManager: NotificationManager) {
        self.originalManager = originalManager
    }
    
    // MARK: - NotificationManaging Implementation
    
    func requestPermissions() {
        originalManager.requestPermissions()
    }
    
    func sendServerAlert(title: String, message: String, serverName: String, serverID: UUID, alertType: String) {
        originalManager.sendServerAlert(title: title, message: message, serverName: serverName, serverID: serverID, alertType: alertType)
    }
    
    func sendConnectionAlert(serverName: String, serverID: UUID, isConnected: Bool) {
        originalManager.sendConnectionAlert(serverName: serverName, serverID: serverID, isConnected: isConnected)
    }
    
    func sendSystemAlert(title: String, message: String) {
        originalManager.sendSystemAlert(title: title, message: message)
    }
    
    func clearAllNotifications() {
        originalManager.clearAllNotifications()
    }
    
    func clearNotifications(for serverID: UUID) {
        originalManager.clearNotifications(for: serverID)
    }
}