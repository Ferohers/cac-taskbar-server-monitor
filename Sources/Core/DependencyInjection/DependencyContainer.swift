import Foundation

// MARK: - Dependency Container Protocol
protocol DependencyContainer {
    var serverManager: ServerManaging { get }
    var credentialManager: CredentialManaging { get }
    var settingsManager: SettingsManaging { get }
    var notificationManager: NotificationManaging { get }
    var powerManager: PowerManaging { get }
}

// MARK: - Production Container
class ProductionContainer: DependencyContainer {
    
    // Lazy initialization to avoid circular dependencies
    private(set) lazy var credentialManager: CredentialManaging = CredentialManagerAdapter(
        originalManager: CredentialManager.shared
    )
    private(set) lazy var serverManager: ServerManaging = ServerManagerAdapter(
        originalManager: ServerManager(),
        credentialManager: credentialManager
    )
    private(set) lazy var settingsManager: SettingsManaging = SettingsManagerAdapter(
        originalManager: SettingsManager.shared
    )
    private(set) lazy var notificationManager: NotificationManaging = NotificationManagerAdapter(
        originalManager: NotificationManager.shared
    )
    private(set) lazy var powerManager: PowerManaging = PowerManagerAdapter(
        originalManager: PowerManager.shared
    )
}

// MARK: - Test Container
class TestContainer: DependencyContainer {
    let serverManager: ServerManaging
    let credentialManager: CredentialManaging
    let settingsManager: SettingsManaging
    let notificationManager: NotificationManaging
    let powerManager: PowerManaging
    
    init(
        serverManager: ServerManaging? = nil,
        credentialManager: CredentialManaging? = nil,
        settingsManager: SettingsManaging? = nil,
        notificationManager: NotificationManaging? = nil,
        powerManager: PowerManaging? = nil
    ) {
        self.serverManager = serverManager ?? MockServerManager()
        self.credentialManager = credentialManager ?? MockCredentialManager()
        self.settingsManager = settingsManager ?? MockSettingsManager()
        self.notificationManager = notificationManager ?? MockNotificationManager()
        self.powerManager = powerManager ?? MockPowerManager()
    }
}

// MARK: - Container Factory
class ContainerFactory {
    private static var _shared: DependencyContainer?
    
    static var shared: DependencyContainer {
        if let container = _shared {
            return container
        }
        
        // Default to production container
        let container = ProductionContainer()
        _shared = container
        return container
    }
    
    static func setSharedContainer(_ container: DependencyContainer) {
        _shared = container
    }
    
    static func createTestContainer(
        serverManager: ServerManaging? = nil,
        credentialManager: CredentialManaging? = nil,
        settingsManager: SettingsManaging? = nil,
        notificationManager: NotificationManaging? = nil,
        powerManager: PowerManaging? = nil
    ) -> DependencyContainer {
        return TestContainer(
            serverManager: serverManager,
            credentialManager: credentialManager,
            settingsManager: settingsManager,
            notificationManager: notificationManager,
            powerManager: powerManager
        )
    }
}

// MARK: - Dependency Resolution Helper
protocol DependencyInjectable {
    var dependencies: DependencyContainer { get }
}

extension DependencyInjectable {
    var dependencies: DependencyContainer {
        return ContainerFactory.shared
    }
}