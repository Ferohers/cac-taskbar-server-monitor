import Foundation

protocol ServerManaging {
    func getAllServers() -> [ServerConfig]
    func getServer(withID serverID: UUID) -> ServerConfig?
    func addServer(_ server: ServerConfig) -> Result<Void, AppError>
    func updateServer(_ server: ServerConfig) -> Result<Void, AppError>
    func removeServer(withID serverID: UUID) -> Result<Void, AppError>
    func toggleServerEnabled(withID serverID: UUID) -> Result<Void, AppError>
    func hasServers() -> Bool
    func validateServer(_ server: ServerConfig) -> [String]
    func getConfigPath() -> String
    
    // Credential access methods
    func getServerPassword(for serverID: UUID) -> String?
    func getServerSSHKeyPath(for serverID: UUID) -> String?
    func getCredentialManager() -> CredentialManager
    
    // Credential management methods
    func addServerWithCredentials(_ server: ServerConfig, password: String?, keyPath: String?) -> Result<Void, AppError>
    func updateServerWithCredentials(_ server: ServerConfig, password: String?, keyPath: String?) -> Result<Void, AppError>
}