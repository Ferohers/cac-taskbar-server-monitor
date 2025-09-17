import Foundation

class ServerRepository {
    private let configManager: ConfigManager
    
    init(configManager: ConfigManager) {
        self.configManager = configManager
    }
    
    // MARK: - Server Management
    
    func getAllServers() -> [ServerConfig] {
        return configManager.loadServers() ?? []
    }
    
    func getServer(withID serverID: UUID) -> ServerConfig? {
        return getAllServers().first { $0.id == serverID }
    }
    
    func addServer(_ server: ServerConfig) -> Bool {
        print("📝 Adding server to repository: \(server.name)")
        return configManager.addServer(server)
    }
    
    func updateServer(_ server: ServerConfig) -> Bool {
        print("📝 Updating server in repository: \(server.name)")
        return configManager.updateServer(server)
    }
    
    func removeServer(withID serverID: UUID) -> Bool {
        if let server = getServer(withID: serverID) {
            print("📝 Removing server from repository: \(server.name)")
            return configManager.removeServer(withID: serverID)
        }
        return false
    }
    
    func toggleServerEnabled(withID serverID: UUID) -> Bool {
        print("📝 Toggling server enabled status for ID: \(serverID)")
        return configManager.toggleServerEnabled(withID: serverID)
    }
    
    func getServerCount() -> Int {
        return getAllServers().count
    }
    
    func hasServers() -> Bool {
        return getServerCount() > 0
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
        
        // Check for duplicate names
        let existingServers = getAllServers().filter { $0.id != server.id }
        if existingServers.contains(where: { $0.name == server.name }) {
            errors.append("A server with this name already exists")
        }
        
        return errors
    }
    
    // MARK: - Bulk Operations
    
    func replaceAllServers(_ servers: [ServerConfig]) -> Bool {
        print("📝 Replacing all servers in repository with \(servers.count) servers")
        return configManager.saveServers(servers)
    }
    
    func clearAllServers() -> Bool {
        print("📝 Clearing all servers from repository")
        return configManager.saveServers([])
    }
    
    // MARK: - Export/Import
    
    func exportServers() -> String? {
        let servers = getAllServers()
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            let data = try encoder.encode(servers)
            return String(data: data, encoding: .utf8)
        } catch {
            print("❌ Failed to export servers: \(error)")
            return nil
        }
    }
    
    func importServers(from jsonString: String, replaceExisting: Bool = false) -> Bool {
        do {
            let data = Data(jsonString.utf8)
            let importedServers = try JSONDecoder().decode([ServerConfig].self, from: data)
            
            if replaceExisting {
                return replaceAllServers(importedServers)
            } else {
                var allServers = getAllServers()
                allServers.append(contentsOf: importedServers)
                return replaceAllServers(allServers)
            }
        } catch {
            print("❌ Failed to import servers: \(error)")
            return false
        }
    }
}