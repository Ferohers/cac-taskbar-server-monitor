import Foundation

class ServerManager {
    private let configFileName = ".Duman-secret"
    private let appSupportSubdirectory = "Duman"
    private let keychainManager: KeychainManager
    
    init(keychainManager: KeychainManager = KeychainManager()) {
        self.keychainManager = keychainManager
    }
    
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
        let serverID = server.id.uuidString
        
        if let password = password, !password.isEmpty {
            do {
                try keychainManager.storePassword(for: serverID, password: password)
                updatedServer.hasKeychainPassword = true
            } catch {
                return false
            }
        }
        
        if let keyPath = keyPath, !keyPath.isEmpty {
            do {
                try keychainManager.storeSSHKey(for: serverID, keyPath: keyPath)
                updatedServer.hasKeychainSSHKey = true
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
        let serverID = server.id.uuidString
        
        if let password = password {
            if password.isEmpty {
                try? keychainManager.deletePassword(for: serverID)
                updatedServer.hasKeychainPassword = false
            } else {
                do {
                    try keychainManager.storePassword(for: serverID, password: password)
                    updatedServer.hasKeychainPassword = true
                } catch {
                    return false
                }
            }
        }
        
        if let keyPath = keyPath {
            if keyPath.isEmpty {
                try? keychainManager.deleteSSHKey(for: serverID)
                updatedServer.hasKeychainSSHKey = false
            } else {
                do {
                    try keychainManager.storeSSHKey(for: serverID, keyPath: keyPath)
                    updatedServer.hasKeychainSSHKey = true
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
        
        keychainManager.cleanupCredentials(for: serverID.uuidString)
        
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
        do {
            return try keychainManager.retrievePassword(for: serverID.uuidString)
        } catch {
            return nil
        }
    }
    
    func getServerSSHKeyPath(for serverID: UUID) -> String? {
        do {
            return try keychainManager.writeSSHKeyToTempFile(for: serverID.uuidString)
        } catch {
            return nil
        }
    }
    
    func getKeychainManager() -> KeychainManager {
        return keychainManager
    }
}