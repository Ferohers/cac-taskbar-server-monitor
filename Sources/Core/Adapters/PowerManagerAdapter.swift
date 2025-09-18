import Foundation

/// Adapter to make PowerManager conform to PowerManaging protocol
class PowerManagerAdapter: PowerManaging {
    private let originalManager: PowerManager
    
    init(originalManager: PowerManager) {
        self.originalManager = originalManager
    }
    
    // MARK: - PowerManaging Implementation
    
    var isInLowPowerMode: Bool {
        return originalManager.isInLowPowerMode
    }
    
    var recommendedMonitoringInterval: TimeInterval {
        return originalManager.recommendedMonitoringInterval
    }
    
    func optimizeForMenuBarApp() {
        originalManager.optimizeForMenuBarApp()
    }
    
    func beginBackgroundActivity(reason: String) -> NSObjectProtocol? {
        return originalManager.beginBackgroundActivity(reason: reason)
    }
    
    func endBackgroundActivity(_ activity: NSObjectProtocol?) {
        originalManager.endBackgroundActivity(activity)
    }
    
    func handleMemoryPressure() {
        originalManager.handleMemoryPressure()
    }
    
    func scheduleBackgroundWork(block: @escaping () -> Void) {
        originalManager.scheduleBackgroundWork(block: block)
    }
}