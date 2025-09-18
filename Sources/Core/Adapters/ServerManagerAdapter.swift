import Foundation

/// Adapter to make ServerManager conform to ServerManaging protocol
class ServerManagerAdapter: ServerManaging {
    private let originalManager: ServerManager
    private let credentialManager: CredentialManaging
    
    init(originalManager: ServerManager, credentialManager: CredentialManaging) {
        self.originalManager = originalManager
        self.credentialManager = credentialManager
    }
    
    // MARK: - ServerManaging Implementation
    
    func getAllServers() -> [ServerConfig] {
        return originalManager.getAllServers()
    }
    
    func getServer(withID serverID: UUID) -> ServerConfig? {
        return originalManager.getServer(withID: serverID)
    }
    
    func addServer(_ server: ServerConfig) -> Result<Void, AppError> {
        let success = originalManager.addServer(server)
        return success ? .success(()) : .failure(.serverOperationFailed("Failed to add server"))
    }
    
    func addServerWithCredentials(_ server: ServerConfig, password: String?, keyPath: String?) -> Result<Void, AppError> {
        let success = originalManager.addServerWithCredentials(server, password: password, keyPath: keyPath)
        return success ? .success(()) : .failure(.serverOperationFailed("Failed to add server with credentials"))
    }
    
    func updateServer(_ server: ServerConfig) -> Result<Void, AppError> {
        let success = originalManager.updateServer(server)
        return success ? .success(()) : .failure(.serverOperationFailed("Failed to update server"))
    }
    
    func updateServerWithCredentials(_ server: ServerConfig, password: String?, keyPath: String?) -> Result<Void, AppError> {
        let success = originalManager.updateServerWithCredentials(server, password: password, keyPath: keyPath)
        return success ? .success(()) : .failure(.serverOperationFailed("Failed to update server with credentials"))
    }
    
    func removeServer(withID serverID: UUID) -> Result<Void, AppError> {
        let success = originalManager.removeServer(withID: serverID)
        return success ? .success(()) : .failure(.serverOperationFailed("Failed to remove server"))
    }
    
    func toggleServerEnabled(withID serverID: UUID) -> Result<Void, AppError> {
        let success = originalManager.toggleServerEnabled(withID: serverID)
        return success ? .success(()) : .failure(.serverOperationFailed("Failed to toggle server state"))
    }
    
    func hasServers() -> Bool {
        return originalManager.hasServers()
    }
    
    func validateServer(_ server: ServerConfig) -> [String] {
        return originalManager.validateServer(server)
    }
    
    func getServerPassword(for serverID: UUID) -> String? {
        return originalManager.getServerPassword(for: serverID)
    }
    
    func getServerSSHKeyPath(for serverID: UUID) -> String? {
        return originalManager.getServerSSHKeyPath(for: serverID)
    }
    
    func getConfigPath() -> String {
        return originalManager.getConfigPath()
    }
    
    func getCredentialManager() -> CredentialManager {
        return originalManager.getCredentialManager()
    }
}