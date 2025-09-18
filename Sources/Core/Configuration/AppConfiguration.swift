import Foundation
import Cocoa

struct AppConfiguration {
    
    // MARK: - Monitoring Configuration
    struct Monitoring {
        static let defaultInterval: TimeInterval = 30.0
        static let minimumInterval: TimeInterval = 7.0
        static let maximumInterval: TimeInterval = 600.0
        static let connectionTimeout: TimeInterval = 15.0
        static let serverAliveInterval: TimeInterval = 10.0
        static let serverAliveCountMax = 3
        static let timerTolerance: Double = 0.1 // 10% tolerance for power efficiency
    }
    
    // MARK: - UI Configuration
    struct UI {
        static let menuBarIconSize = NSSize(width: 16, height: 16)
        static let maxServerNameLength = 50
        static let animationDuration: TimeInterval = 0.3
        static let animationInterval: TimeInterval = 0.3
        static let maxMenuWidth: CGFloat = 400.0
        static let defaultWindowSize = NSSize(width: 800, height: 600)
        static let minimumWindowSize = NSSize(width: 700, height: 500)
        static let sidebarWidth: CGFloat = 200.0
    }
    
    // MARK: - Security Configuration
    struct Security {
        static let keySize = 32 // 256 bits for AES-256
        static let tempFilePermissions: mode_t = 0o600
        static let appIdentifier = "com.altan.Duman"
    }
    
    // MARK: - File System Configuration
    struct Files {
        static let configFileName = ".Duman-secret"
        static let appSupportSubdirectory = "Duman"
        static let iconFileName = "Duman.icns"
        static let menuBarIconPrefix = "MenuBarIcon"
    }
    
    // MARK: - Network Configuration
    struct Network {
        static let sshOptions = [
            "ConnectTimeout=\(Monitoring.connectionTimeout)",
            "ServerAliveInterval=\(Monitoring.serverAliveInterval)",
            "ServerAliveCountMax=\(Monitoring.serverAliveCountMax)",
            "BatchMode=yes",
            "StrictHostKeyChecking=no",
            "UserKnownHostsFile=/dev/null",
            "LogLevel=ERROR"
        ]
        
        static let defaultSSHPort = 22
        static let maxRetryAttempts = 3
        static let retryDelay: TimeInterval = 2.0
    }
    
    // MARK: - Performance Configuration
    struct Performance {
        static let maxConcurrentConnections = 10
        static let backgroundQueueQoS = DispatchQoS.utility
        static let memoryWarningThreshold: Float = 80.0
        static let cpuWarningThreshold: Float = 80.0
        static let diskWarningThreshold: Float = 2.0 // GB
    }
    
    // MARK: - Notification Configuration
    struct Notifications {
        static let defaultSoundEnabled = true
        static let defaultBadgeEnabled = true
        static let throttleInterval: TimeInterval = 60.0 // Minimum time between same type notifications
        static let maxRetainedNotifications = 100
    }
    
    // MARK: - Validation Rules
    struct Validation {
        static let maxServerNameLength = 50
        static let maxHostnameLength = 255
        static let maxUsernameLength = 32
        static let minPortNumber = 1
        static let maxPortNumber = 65535
        static let maxPasswordLength = 1024
        static let maxSSHKeyLength = 8192
    }
    
    // MARK: - Debug Configuration
    struct Debug {
        static let enableVerboseLogging = false
        static let enablePerformanceMetrics = false
        static let logFileMaxSize = 10 * 1024 * 1024 // 10MB
        static let maxLogFiles = 5
    }
}

// MARK: - Configuration Extensions
extension AppConfiguration {
    
    // MARK: - Dynamic Configuration
    static var isRunningInDebugMode: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    static var isRunningOnAppleSilicon: Bool {
        #if ARM64_OPTIMIZED
        return true
        #else
        return false
        #endif
    }
    
    static var supportsPowerEfficiency: Bool {
        #if POWER_EFFICIENT
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - Environment-specific configurations
    static func monitoringInterval(for powerState: Bool) -> TimeInterval {
        if powerState {
            return Monitoring.defaultInterval * 2 // Slower when on battery
        }
        return Monitoring.defaultInterval
    }
    
    static func maxConcurrentConnections(for systemLoad: Float) -> Int {
        if systemLoad > 0.8 {
            return Performance.maxConcurrentConnections / 2 // Reduce load when system is busy
        }
        return Performance.maxConcurrentConnections
    }
}

// MARK: - Configuration Validation
extension AppConfiguration {
    
    static func validateMonitoringInterval(_ interval: TimeInterval) -> TimeInterval {
        return max(Monitoring.minimumInterval, min(Monitoring.maximumInterval, interval))
    }
    
    static func validateServerName(_ name: String) -> Bool {
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               name.count <= Validation.maxServerNameLength
    }
    
    static func validateHostname(_ hostname: String) -> Bool {
        return !hostname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               hostname.count <= Validation.maxHostnameLength
    }
    
    static func validatePort(_ port: Int) -> Bool {
        return port >= Validation.minPortNumber && port <= Validation.maxPortNumber
    }
}