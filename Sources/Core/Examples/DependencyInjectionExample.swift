import Foundation

/// Example demonstrating how to use the new dependency injection system
class DependencyInjectionExample {
    
    /// Example 1: Using production container
    static func demonstrateProductionUsage() {
        // Get the shared container
        let container = ContainerFactory.shared
        
        // Access managers through protocols
        let serverManager = container.serverManager
        let credentialManager = container.credentialManager
        _ = container.settingsManager // Used for demonstration
        
        // Example server creation
        let server = ServerConfig(
            name: "Example Server",
            hostname: "example.com",
            username: "admin",
            port: 22,
            isEnabled: true
        )
        
        // Add server using protocol
        let result = serverManager.addServer(server)
        switch result {
        case .success:
            print("✅ Server added successfully")
        case .failure(let error):
            print("❌ Failed to add server: \(error.localizedDescription)")
        }
        
        // Example credential encryption
        do {
            let encrypted = try credentialManager.encryptString("secret_password")
            print("🔐 Password encrypted: \(encrypted)")
            
            let decrypted = try credentialManager.decryptString(encrypted)
            print("🔓 Password decrypted: \(decrypted)")
        } catch {
            print("❌ Credential operation failed: \(error)")
        }
    }
    
    /// Example 2: Using test container
    static func demonstrateTestUsage() {
        // Create test container with custom mocks
        let mockServerManager = MockServerManager()
        let mockCredentialManager = MockCredentialManager()
        
        let testContainer = ContainerFactory.createTestContainer(
            serverManager: mockServerManager,
            credentialManager: mockCredentialManager
        )
        
        // Set the container for testing
        ContainerFactory.setSharedContainer(testContainer)
        
        // Now any code using the container will use mock implementations
        let container = ContainerFactory.shared
        let serverManager = container.serverManager
        
        let server = ServerConfig(
            name: "Test Server",
            hostname: "test.com", 
            username: "test",
            port: 22,
            isEnabled: true
        )
        
        // This will use the mock implementation
        let result = serverManager.addServer(server)
        switch result {
        case .success:
            print("✅ Mock server added successfully")
        case .failure(let error):
            print("❌ Mock failed: \(error.localizedDescription)")
        }
        
        // Verify mock behavior
        let allServers = serverManager.getAllServers()
        print("📊 Mock container has \(allServers.count) servers")
    }
    
    /// Example 3: Component with dependency injection
    static func demonstrateComponentUsage() {
        // Example of a component that uses dependency injection
        class ServerService: DependencyInjectable {
            func createServer(name: String, hostname: String) -> Result<UUID, AppError> {
                let server = ServerConfig(
                    name: name,
                    hostname: hostname,
                    username: "default",
                    port: 22,
                    isEnabled: true
                )
                
                // Validate using injected dependencies
                let errors = dependencies.serverManager.validateServer(server)
                guard errors.isEmpty else {
                    return .failure(.validationError(errors))
                }
                
                // Add server using injected dependencies
                switch dependencies.serverManager.addServer(server) {
                case .success:
                    return .success(server.id)
                case .failure(let error):
                    return .failure(error)
                }
            }
            
            func sendNotificationForServer(_ serverID: UUID, message: String) {
                guard let server = dependencies.serverManager.getServer(withID: serverID) else {
                    return
                }
                
                dependencies.notificationManager.sendServerAlert(
                    title: "Server Update",
                    message: message,
                    serverName: server.name,
                    serverID: serverID,
                    alertType: "info"
                )
            }
        }
        
        let service = ServerService()
        
        // This automatically uses the configured dependencies
        switch service.createServer(name: "Production Server", hostname: "prod.example.com") {
        case .success(let serverID):
            print("✅ Service created server: \(serverID)")
            service.sendNotificationForServer(serverID, message: "Server configured successfully")
        case .failure(let error):
            print("❌ Service failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Configuration Example
extension DependencyInjectionExample {
    
    /// Example 4: Using AppConfiguration
    static func demonstrateConfigurationUsage() {
        // Access configuration values
        print("⏱️ Default monitoring interval: \(AppConfiguration.Monitoring.defaultInterval)s")
        print("🔄 Max retry attempts: \(AppConfiguration.Network.maxRetryAttempts)")
        print("🔐 Encryption key size: \(AppConfiguration.Security.keySize * 8) bits")
        print("📱 Notification throttle interval: \(AppConfiguration.Notifications.throttleInterval)s")
        
        // Validate configuration values
        let testServerName = "My Server"
        let testHostname = "example.com"
        let testPort = 22
        
        if AppConfiguration.validateServerName(testServerName) {
            print("✅ Server name '\(testServerName)' is valid")
        } else {
            print("❌ Server name validation failed")
        }
        
        if AppConfiguration.validateHostname(testHostname) {
            print("✅ Hostname '\(testHostname)' is valid")
        } else {
            print("❌ Hostname validation failed")
        }
        
        if AppConfiguration.validatePort(testPort) {
            print("✅ Port \(testPort) is valid")
        } else {
            print("❌ Port validation failed")
        }
        
        // Access environment-specific settings
        if AppConfiguration.isRunningInDebugMode {
            print("🧪 Running in debug mode")
        } else {
            print("🚀 Running in release mode")
        }
        
        if AppConfiguration.isRunningOnAppleSilicon {
            print("🖥️ Running on Apple Silicon")
        } else {
            print("🖥️ Running on Intel")
        }
        
        // Dynamic configuration based on system state
        let monitoringInterval = AppConfiguration.monitoringInterval(for: false) // Not on battery
        print("⚡ Monitoring interval for AC power: \(monitoringInterval)s")
        
        let batteryInterval = AppConfiguration.monitoringInterval(for: true) // On battery
        print("🔋 Monitoring interval for battery: \(batteryInterval)s")
    }
}