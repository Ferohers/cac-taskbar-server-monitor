import Foundation
import Cocoa

// MARK: - Power Management for Menu Bar Apps

class PowerManager {
    static let shared = PowerManager()
    private var isLowPowerMode = false
    
    
    private init() {
        setupPowerManagement()
        observePowerStateChanges()
    }
    
    // MARK: - Power Management Setup
    
    private func setupPowerManagement() {
        // Enable App Nap for background efficiency
        ProcessInfo.processInfo.enableSuddenTermination()
        
        // Set quality of service for background operations
        DispatchQueue.global(qos: .utility).async {
            print("⚡ Power manager initialized with utility QoS")
        }
        
        #if ARM64_OPTIMIZED
        print("⚡ ARM64 optimizations enabled")
        #endif
        
        #if POWER_EFFICIENT
        print("⚡ Power efficiency mode enabled")
        #endif
    }
    
    private func observePowerStateChanges() {
        // Monitor power source changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(powerSourceChanged),
            name: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil
        )
        
        // Monitor thermal state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateChanged),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func powerSourceChanged() {
        let isOnBattery = !ProcessInfo.processInfo.isOperatingSystemAtLeast(
            OperatingSystemVersion(majorVersion: 12, minorVersion: 0, patchVersion: 0)
        ) || isRunningOnBattery()
        
        if isOnBattery && !isLowPowerMode {
            enableLowPowerMode()
        } else if !isOnBattery && isLowPowerMode {
            disableLowPowerMode()
        }
    }
    
    @objc private func thermalStateChanged() {
        let thermalState = ProcessInfo.processInfo.thermalState
        
        switch thermalState {
        case .critical, .serious:
            if !isLowPowerMode {
                enableLowPowerMode()
                print("⚡ Thermal protection: Low power mode enabled")
            }
        case .fair, .nominal:
            if isLowPowerMode {
                disableLowPowerMode()
                print("⚡ Thermal state normal: Low power mode disabled")
            }
        @unknown default:
            break
        }
    }
    
    // MARK: - Power State Management
    
    private func enableLowPowerMode() {
        isLowPowerMode = true
        
        // Increase monitoring intervals
        NotificationCenter.default.post(
            name: NSNotification.Name("PowerManager.LowPowerModeEnabled"),
            object: nil
        )
        
        print("⚡ Low power mode enabled - reducing background activity")
    }
    
    private func disableLowPowerMode() {
        isLowPowerMode = false
        
        // Resume normal intervals
        NotificationCenter.default.post(
            name: NSNotification.Name("PowerManager.LowPowerModeDisabled"),
            object: nil
        )
        
        print("⚡ Low power mode disabled - resuming normal activity")
    }
    
    // MARK: - Background Activity Management
    
    func beginBackgroundActivity(reason: String) -> NSObjectProtocol? {
        #if POWER_EFFICIENT
        let activity = ProcessInfo.processInfo.beginActivity(
            options: [.background, .latencyCritical],
            reason: reason
        )
        return activity
        #else
        return nil
        #endif
    }
    
    func endBackgroundActivity(_ activity: NSObjectProtocol?) {
        #if POWER_EFFICIENT
        if let activity = activity {
            ProcessInfo.processInfo.endActivity(activity)
        }
        #endif
    }
    
    // MARK: - Utility Methods
    
    var isInLowPowerMode: Bool {
        return isLowPowerMode || ProcessInfo.processInfo.isLowPowerModeEnabled
    }
    
    var recommendedMonitoringInterval: TimeInterval {
        if isInLowPowerMode {
            return 60.0  // 1 minute when power constrained
        } else {
            return 30.0  // 30 seconds normal
        }
    }
    
    private func isRunningOnBattery() -> Bool {
        // Simple heuristic - in a real implementation, you'd check IOKit
        // For now, assume battery if thermal state is not nominal
        return ProcessInfo.processInfo.thermalState != .nominal
    }
    
    // MARK: - Memory Pressure Handling
    
    func handleMemoryPressure() {
        #if POWER_EFFICIENT
        // Clear caches and reduce memory footprint
        URLCache.shared.removeAllCachedResponses()
        
        // Suggest garbage collection
        DispatchQueue.global(qos: .utility).async {
            // Force a cleanup cycle
            autoreleasepool {
                // Temporary objects will be cleaned up
            }
        }
        
        print("⚡ Memory pressure handled - caches cleared")
        #endif
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Menu Bar Specific Optimizations

extension PowerManager {
    
    func optimizeForMenuBarApp() {
        // Disable automatic termination for menu bar apps
        ProcessInfo.processInfo.disableAutomaticTermination("Menu bar app should stay running")
        
        // But enable sudden termination for quick shutdown
        ProcessInfo.processInfo.enableSuddenTermination()
        
        // Set low priority for non-critical operations
        DispatchQueue.global(qos: .background).async {
            Thread.current.qualityOfService = .background
        }
        
        print("⚡ Menu bar app optimizations applied")
    }
    
    func scheduleBackgroundWork(block: @escaping () -> Void) {
        let activity = beginBackgroundActivity(reason: "Server monitoring")
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            // Perform work on efficiency cores when possible
            print("⚡ Executing background work...")
            block()
            print("⚡ Background work completed")
            
            DispatchQueue.main.async {
                self?.endBackgroundActivity(activity)
            }
        }
    }
}