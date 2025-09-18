import Foundation

class ServerManager {
    private let configFileName = ".Duman-secret"
    private let appSupportSubdirectory = "Duman"
    private let credentialManager = CredentialManager.shared
    
    init() {}
    
    private var configURL: URL {
        if let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let appDirectory = appSupportURL.appendingPathComponent(appSupportSubdirectory, isDirectory: true)
            return appDirectory.appendingPathComponent(configFileName)
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(configFileName)
    }
    
    // MARK: - Server Management
    
    func getAllServers() -> [ServerConfig] {
        return loadServers() ?? []
    }
    
    func getServer(withID serverID: UUID) -> ServerConfig? {
        return getAllServers().first { $0.id == serverID }
    }
    
    func addServer(_ server: ServerConfig) -> Bool {
        var servers = getAllServers()
        servers.append(server)
        return saveServers(servers)
    }
    
    func addServerWithCredentials(_ server: ServerConfig, password: String? = nil, keyPath: String? = nil) -> Bool {
        var updatedServer = server
        
        if let password = password, !password.isEmpty {
            do {
                let encryptedPassword = try credentialManager.encryptString(password)
                updatedServer.encryptedPassword = encryptedPassword
            } catch {
                return false
            }
        }
        
        if let keyPath = keyPath, !keyPath.isEmpty {
            do {
                // Read the SSH key file content
                let sshKeyContent = try String(contentsOfFile: keyPath, encoding: .utf8)
                let encryptedSSHKey = try credentialManager.encryptString(sshKeyContent)
                updatedServer.encryptedSSHKey = encryptedSSHKey
            } catch {
                return false
            }
        }
        
        return addServer(updatedServer)
    }
    
    func updateServer(_ server: ServerConfig) -> Bool {
        var servers = getAllServers()
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            servers[index] = server
            return saveServers(servers)
        }
        return false
    }
    
    func updateServerWithCredentials(_ server: ServerConfig, password: String? = nil, keyPath: String? = nil) -> Bool {
        var updatedServer = server
        
        if let password = password {
            if password.isEmpty {
                updatedServer.encryptedPassword = nil
            } else {
                do {
                    let encryptedPassword = try credentialManager.encryptString(password)
                    updatedServer.encryptedPassword = encryptedPassword
                } catch {
                    return false
                }
            }
        }
        
        if let keyPath = keyPath {
            if keyPath.isEmpty {
                updatedServer.encryptedSSHKey = nil
            } else {
                do {
                    // Read the SSH key file content
                    let sshKeyContent = try String(contentsOfFile: keyPath, encoding: .utf8)
                    let encryptedSSHKey = try credentialManager.encryptString(sshKeyContent)
                    updatedServer.encryptedSSHKey = encryptedSSHKey
                } catch {
                    return false
                }
            }
        }
        
        return updateServer(updatedServer)
    }
    
    func removeServer(withID serverID: UUID) -> Bool {
        var servers = getAllServers()
        servers.removeAll { $0.id == serverID }
        
        // No need to cleanup credentials since they're stored in the config file
        
        return saveServers(servers)
    }
    
    func toggleServerEnabled(withID serverID: UUID) -> Bool {
        var servers = getAllServers()
        if let index = servers.firstIndex(where: { $0.id == serverID }) {
            servers[index].isEnabled.toggle()
            return saveServers(servers)
        }
        return false
    }
    
    func hasServers() -> Bool {
        return !getAllServers().isEmpty
    }
    
    // MARK: - Validation
    
    func validateServer(_ server: ServerConfig) -> [String] {
        var errors: [String] = []
        
        if server.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Server name is required")
        }
        
        if server.hostname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Hostname is required")
        }
        
        if server.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Username is required")
        }
        
        if server.port < 1 || server.port > 65535 {
            errors.append("Port must be between 1 and 65535")
        }
        
        let existingServers = getAllServers().filter { $0.id != server.id }
        if existingServers.contains(where: { $0.name == server.name }) {
            errors.append("A server with this name already exists")
        }
        
        return errors
    }
    
    // MARK: - Private Configuration Methods
    
    private func configExists() -> Bool {
        return FileManager.default.fileExists(atPath: configURL.path)
    }
    
    private func saveServers(_ servers: [ServerConfig]) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(servers)
            
            let directoryURL = configURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directoryURL.path) {
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            }
            try data.write(to: configURL)
            return true
        } catch {
            return false
        }
    }
    
    private func loadServers() -> [ServerConfig]? {
        guard configExists() else { return nil }
        
        do {
            let data = try Data(contentsOf: configURL)
            let servers = try JSONDecoder().decode([ServerConfig].self, from: data)
            return servers
        } catch {
            return nil
        }
    }
    
    func getConfigPath() -> String {
        return configURL.path
    }
    
    // MARK: - Credential Access
    
    func getServerPassword(for serverID: UUID) -> String? {
        guard let server = getServer(withID: serverID),
              let encryptedPassword = server.encryptedPassword else {
            return nil
        }
        
        do {
            return try credentialManager.decryptString(encryptedPassword)
        } catch {
            return nil
        }
    }
    
    func getServerSSHKeyPath(for serverID: UUID) -> String? {
        guard let server = getServer(withID: serverID),
              let encryptedSSHKey = server.encryptedSSHKey else {
            return nil
        }
        
        do {
            let sshKeyContent = try credentialManager.decryptString(encryptedSSHKey)
            return try credentialManager.writeSSHKeyToTempFile(sshKeyContent)
        } catch {
            return nil
        }
    }
    
    func getCredentialManager() -> CredentialManager {
        return credentialManager
    }
}