import Foundation

// MARK: - Mock Server Manager
class MockServerManager: ServerManaging {
    private var servers: [ServerConfig] = []
    private var shouldFail = false
    
    func setShouldFail(_ fail: Bool) {
        shouldFail = fail
    }
    
    func getAllServers() -> [ServerConfig] {
        return servers
    }
    
    func getServer(withID serverID: UUID) -> ServerConfig? {
        return servers.first { $0.id == serverID }
    }
    
    func addServer(_ server: ServerConfig) -> Result<Void, AppError> {
        if shouldFail {
            return .failure(.serverOperationFailed("Mock failure"))
        }
        servers.append(server)
        return .success(())
    }
    
    func addServerWithCredentials(_ server: ServerConfig, password: String?, keyPath: String?) -> Result<Void, AppError> {
        if shouldFail {
            return .failure(.serverOperationFailed("Mock failure"))
        }
        var updatedServer = server
        if let password = password {
            updatedServer.encryptedPassword = "mock_encrypted_\(password)"
        }
        if let keyPath = keyPath {
            updatedServer.encryptedSSHKey = "mock_encrypted_key_\(keyPath)"
        }
        servers.append(updatedServer)
        return .success(())
    }
    
    func updateServer(_ server: ServerConfig) -> Result<Void, AppError> {
        if shouldFail {
            return .failure(.serverOperationFailed("Mock failure"))
        }
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            servers[index] = server
            return .success(())
        }
        return .failure(.serverOperationFailed("Server not found"))
    }
    
    func updateServerWithCredentials(_ server: ServerConfig, password: String?, keyPath: String?) -> Result<Void, AppError> {
        return updateServer(server)
    }
    
    func removeServer(withID serverID: UUID) -> Result<Void, AppError> {
        if shouldFail {
            return .failure(.serverOperationFailed("Mock failure"))
        }
        servers.removeAll { $0.id == serverID }
        return .success(())
    }
    
    func toggleServerEnabled(withID serverID: UUID) -> Result<Void, AppError> {
        if shouldFail {
            return .failure(.serverOperationFailed("Mock failure"))
        }
        if let index = servers.firstIndex(where: { $0.id == serverID }) {
            servers[index].isEnabled.toggle()
            return .success(())
        }
        return .failure(.serverOperationFailed("Server not found"))
    }
    
    func hasServers() -> Bool {
        return !servers.isEmpty
    }
    
    func validateServer(_ server: ServerConfig) -> [String] {
        var errors: [String] = []
        if server.name.isEmpty { errors.append("Name required") }
        if server.hostname.isEmpty { errors.append("Hostname required") }
        return errors
    }
    
    func getConfigPath() -> String {
        return "/mock/config/path"
    }
    
    func getServerPassword(for serverID: UUID) -> String? {
        return getServer(withID: serverID)?.encryptedPassword?.replacingOccurrences(of: "mock_encrypted_", with: "")
    }
    
    func getServerSSHKeyPath(for serverID: UUID) -> String? {
        return "/mock/ssh/key/path"
    }
    
    func getCredentialManager() -> CredentialManager {
        return CredentialManager.shared
    }
}

// MARK: - Mock Credential Manager
class MockCredentialManager: CredentialManaging {
    private var shouldFail = false
    
    func setShouldFail(_ fail: Bool) {
        shouldFail = fail
    }
    
    func encryptString(_ plaintext: String) throws -> String {
        if shouldFail {
            throw CredentialError.encryptionFailed
        }
        return "mock_encrypted_\(plaintext)"
    }
    
    func decryptString(_ encryptedString: String) throws -> String {
        if shouldFail {
            throw CredentialError.decryptionFailed
        }
        return encryptedString.replacingOccurrences(of: "mock_encrypted_", with: "")
    }
    
    func writeSSHKeyToTempFile(_ sshKey: String) throws -> String {
        if shouldFail {
            throw CredentialError.keyGenerationFailed
        }
        return "/tmp/mock_ssh_key"
    }
    
    func cleanupTempFile(_ filePath: String?) {
        // Mock cleanup - no-op
    }
    
    func migrateFromKeychain() {
        // Mock migration - no-op
    }
}

// MARK: - Mock Settings Manager
class MockSettingsManager: SettingsManaging {
    private var notificationSettings: [ServerNotificationSettings] = []
    private var advancedSettings = AdvancedSettings()
    
    func getNotificationSettings(for serverID: UUID) -> ServerNotificationSettings? {
        return notificationSettings.first { $0.serverID == serverID }
    }
    
    func getAllNotificationSettings() -> [ServerNotificationSettings] {
        return notificationSettings
    }
    
    func saveNotificationSettings(_ settings: ServerNotificationSettings) {
        notificationSettings.removeAll { $0.serverID == settings.serverID }
        notificationSettings.append(settings)
    }
    
    func removeNotificationSettings(for serverID: UUID) {
        notificationSettings.removeAll { $0.serverID == serverID }
    }
    
    func createDefaultNotificationSettings(for server: ServerConfig) -> ServerNotificationSettings {
        let settings = ServerNotificationSettings(serverID: server.id, serverName: server.name)
        saveNotificationSettings(settings)
        return settings
    }
    
    func getAdvancedSettings() -> AdvancedSettings {
        return advancedSettings
    }
    
    func saveAdvancedSettings(_ settings: AdvancedSettings) {
        self.advancedSettings = settings
    }
    
    func checkServerMetrics(for serverData: ServerData) {
        // Mock metrics check - no-op
    }
}

// MARK: - Mock Notification Manager
class MockNotificationManager: NotificationManaging {
    private var sentNotifications: [(title: String, message: String, serverID: UUID?)] = []
    
    var lastNotification: (title: String, message: String, serverID: UUID?)? {
        return sentNotifications.last
    }
    
    func requestPermissions() {
        // Mock permission request - no-op
    }
    
    func sendServerAlert(title: String, message: String, serverName: String, serverID: UUID, alertType: String) {
        sentNotifications.append((title: title, message: message, serverID: serverID))
    }
    
    func sendConnectionAlert(serverName: String, serverID: UUID, isConnected: Bool) {
        let title = isConnected ? "Connected" : "Disconnected"
        sentNotifications.append((title: title, message: "Server \(serverName)", serverID: serverID))
    }
    
    func sendSystemAlert(title: String, message: String) {
        sentNotifications.append((title: title, message: message, serverID: nil))
    }
    
    func clearAllNotifications() {
        sentNotifications.removeAll()
    }
    
    func clearNotifications(for serverID: UUID) {
        sentNotifications.removeAll { $0.serverID == serverID }
    }
}

// MARK: - Mock Power Manager
class MockPowerManager: PowerManaging {
    private var _isInLowPowerMode = false
    private var backgroundActivities: [NSObjectProtocol] = []
    
    var isInLowPowerMode: Bool {
        return _isInLowPowerMode
    }
    
    var recommendedMonitoringInterval: TimeInterval {
        return isInLowPowerMode ? 60.0 : 30.0
    }
    
    func setLowPowerMode(_ enabled: Bool) {
        _isInLowPowerMode = enabled
    }
    
    func optimizeForMenuBarApp() {
        // Mock optimization - no-op
    }
    
    func beginBackgroundActivity(reason: String) -> NSObjectProtocol? {
        let activity = NSObject()
        backgroundActivities.append(activity)
        return activity
    }
    
    func endBackgroundActivity(_ activity: NSObjectProtocol?) {
        if let activity = activity,
           let index = backgroundActivities.firstIndex(where: { $0 === activity }) {
            backgroundActivities.remove(at: index)
        }
    }
    
    func handleMemoryPressure() {
        // Mock memory pressure handling - no-op
    }
    
    func scheduleBackgroundWork(block: @escaping () -> Void) {
        // Execute immediately in mock
        block()
    }
}