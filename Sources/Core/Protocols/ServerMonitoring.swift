import Foundation

protocol ServerMonitoring {
    var onDataUpdate: (([ServerData]) -> Void)? { get set }
    
    func startMonitoring(servers: [ServerConfig])
    func stopMonitoring()
    func updateRefreshInterval()
}

protocol PowerManaging {
    var isInLowPowerMode: Bool { get }
    var recommendedMonitoringInterval: TimeInterval { get }
    
    func optimizeForMenuBarApp()
    func beginBackgroundActivity(reason: String) -> NSObjectProtocol?
    func endBackgroundActivity(_ activity: NSObjectProtocol?)
    func handleMemoryPressure()
    func scheduleBackgroundWork(block: @escaping () -> Void)
}

protocol NotificationManaging {
    func requestPermissions()
    func sendServerAlert(title: String, message: String, serverName: String, serverID: UUID, alertType: String)
    func sendConnectionAlert(serverName: String, serverID: UUID, isConnected: Bool)
    func sendSystemAlert(title: String, message: String)
    func clearAllNotifications()
    func clearNotifications(for serverID: UUID)
}