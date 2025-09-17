import Foundation

class ConfigManager {
    private let configFileName = ".AltanMon-secret"
    private let appSupportSubdirectory = "AltanMon" // Name for your application's folder in Application Support

    private var configURL: URL {
        if let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let appDirectory = appSupportURL.appendingPathComponent(appSupportSubdirectory, isDirectory: true)
            return appDirectory.appendingPathComponent(configFileName)
        }
        // Fallback to current directory if Application Support is not accessible, though this should ideally not happen
        print("⚠️ Could not locate Application Support directory, falling back to current directory.")
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(configFileName)
    }

    func configExists() -> Bool {
        return FileManager.default.fileExists(atPath: configURL.path)
    }

    func saveServers(_ servers: [ServerConfig]) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(servers)
            
            let directoryURL = configURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directoryURL.path) {
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
                print("📁 Created Application Support directory: \(directoryURL.path)")
            }
            try data.write(to: configURL)
            print("💾 Saved \(servers.count) servers to: \(configURL.path)")
            return true
        } catch {
            print("❌ Failed to save config: \(error)")
            return false
        }
    }

    func loadServers() -> [ServerConfig]? {
        guard configExists() else {
            print("📁 No config file found at: \(configURL.path)")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: configURL)
            let servers = try JSONDecoder().decode([ServerConfig].self, from: data)
            print("📖 Loaded \(servers.count) servers from: \(configURL.path)")
            return servers
        } catch {
            print("❌ Failed to load config: \(error)")
            return nil
        }
    }

    func addServer(_ server: ServerConfig) -> Bool {
        var servers = loadServers() ?? []
        servers.append(server)
        return saveServers(servers)
    }

    func removeServer(withID serverID: UUID) -> Bool {
        var servers = loadServers() ?? []
        servers.removeAll { $0.id == serverID }
        return saveServers(servers)
    }

    func updateServer(_ updatedServer: ServerConfig) -> Bool {
        var servers = loadServers() ?? []
        if let index = servers.firstIndex(where: { $0.id == updatedServer.id }) {
            servers[index] = updatedServer
            return saveServers(servers)
        }
        return false
    }

    func toggleServerEnabled(withID serverID: UUID) -> Bool {
        var servers = loadServers() ?? []
        if let index = servers.firstIndex(where: { $0.id == serverID }) {
            servers[index].isEnabled.toggle()
            return saveServers(servers)
        }
        return false
    }

    func getConfigPath() -> String {
        return configURL.path
    }

    func deleteConfig() -> Bool {
        guard configExists() else { return true }
        
        do {
            try FileManager.default.removeItem(at: configURL)
            return true
        } catch {
            print("Failed to delete config: \(error)")
            return false
        }
    }
}
