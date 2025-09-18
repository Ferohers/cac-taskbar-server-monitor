import Foundation

class ServerMonitor {
    private var servers: [ServerData] = []
    private var monitoringTimer: Timer?
    private var updateInterval: TimeInterval = 30.0 // Default 30 seconds, now configurable
    private let settingsManager = SettingsManager.shared
    private let powerManager = PowerManager.shared
    private var backgroundActivity: NSObjectProtocol?
    
    var onDataUpdate: (([ServerData]) -> Void)?
    
    func startMonitoring(servers configs: [ServerConfig]) {
        stopMonitoring()
        
        // Load custom refresh settings with power management
        let advancedSettings = settingsManager.getAdvancedSettings()
        if advancedSettings.customRefreshEnabled {
            updateInterval = max(7.0, min(600.0, advancedSettings.refreshIntervalSeconds))
        } else {
            // Use power-aware default interval
            updateInterval = powerManager.recommendedMonitoringInterval
        }
        
        // Initialize server data only for enabled servers
        let enabledConfigs = configs.filter { $0.isEnabled }
        self.servers = enabledConfigs.map { ServerData(config: $0) }
        
        // Setup power state monitoring
        setupPowerStateObservers()
        
        // Start monitoring only if there are enabled servers
        if !self.servers.isEmpty {
            print("🚀 Starting monitoring for \(self.servers.count) servers")
            
            // Begin background activity for monitoring
            backgroundActivity = powerManager.beginBackgroundActivity(reason: "Server monitoring")
            
            // Perform initial check
            performMonitoringCheck()
            
            // Create timer for subsequent checks
            createPowerEfficientTimer()
        } else {
            print("⚠️ No enabled servers to monitor")
            // No enabled servers, just notify with empty array
            onDataUpdate?([])
        }
    }
    
    private func setupPowerStateObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(powerStateChanged),
            name: NSNotification.Name("PowerManager.LowPowerModeEnabled"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(powerStateChanged),
            name: NSNotification.Name("PowerManager.LowPowerModeDisabled"),
            object: nil
        )
    }
    
    @objc private func powerStateChanged() {
        // Adjust monitoring interval based on power state
        let newInterval = powerManager.recommendedMonitoringInterval
        if abs(newInterval - updateInterval) > 1.0 {
            updateInterval = newInterval
            recreateTimer()
            print("🔋 Monitoring interval adjusted to \(updateInterval)s for power efficiency")
        }
    }
    
    private func createPowerEfficientTimer() {
        print("⚡ Creating timer with interval: \(updateInterval)s")
        
        // Create timer on main queue to ensure it fires properly
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] timer in
            print("⏰ Timer fired! Starting monitoring check...")
            self?.performPowerEfficientMonitoringCheck()
        }
        
        // Add to main run loop to ensure it fires
        if let timer = monitoringTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        
        // Set timer tolerance for power efficiency
        monitoringTimer?.tolerance = updateInterval * 0.1  // 10% tolerance
        
        print("⚡ Timer created and added to main run loop with interval: \(updateInterval)s")
    }
    
    private func recreateTimer() {
        monitoringTimer?.invalidate()
        createPowerEfficientTimer()
    }
    
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        // End background activity
        powerManager.endBackgroundActivity(backgroundActivity)
        backgroundActivity = nil
        
        // Remove power state observers
        NotificationCenter.default.removeObserver(self)
        
        // Clear servers array to prevent any lingering background tasks from accessing it
        servers.removeAll()
        
        print("⚡ Server monitoring stopped and background activity ended")
    }
    
    func updateRefreshInterval() {
        // Get current settings and update interval
        let advancedSettings = settingsManager.getAdvancedSettings()
        let newInterval = advancedSettings.customRefreshEnabled ? 
            max(7.0, min(600.0, advancedSettings.refreshIntervalSeconds)) : 30.0
        
        // Only restart if the interval actually changed
        if abs(newInterval - updateInterval) > 0.1 {
            updateInterval = newInterval
            
            // If monitoring is active, restart with new interval
            if monitoringTimer != nil {
                let currentConfigs = servers.map { $0.config }
                startMonitoring(servers: currentConfigs)
            }
        }
    }
    
    private func performMonitoringCheck() {
        performPowerEfficientMonitoringCheck()
    }
    
    private func performPowerEfficientMonitoringCheck() {
        let currentServers = servers // Capture current state
        
        print("🔄 Starting monitoring check for \(currentServers.count) servers...")
        
        // Process each server individually to avoid blocking
        for (index, server) in currentServers.enumerated() {
            // Use background queue for monitoring
            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let self = self else { return }
                
                print("🔍 Monitoring server: \(server.config.name)")
                let updatedServer = self.monitorServer(server)
                
                DispatchQueue.main.async {
                    // Safely update only if the server still exists at the same index
                    guard index < self.servers.count,
                          self.servers[index].config.id == updatedServer.config.id else {
                        print("⚠️ Server array changed, skipping update for \(server.config.name)")
                        return
                    }
                    
                    self.servers[index] = updatedServer
                    
                    // Check notifications for this server
                    self.settingsManager.checkServerMetrics(for: updatedServer)
                    
                    print("✅ Updated server: \(server.config.name) - Connected: \(updatedServer.isConnected)")
                    
                    // Notify UI of update
                    self.onDataUpdate?(self.servers)
                }
            }
        }
    }
    
    private func monitorServer(_ server: ServerData) -> ServerData {
        var updatedServer = server
        updatedServer.lastUpdate = Date()
        
        // First, perform local ping to measure latency
        let sshClient = SSHClient()
        updatedServer.pingTime = sshClient.pingServer(hostname: server.config.hostname)
        
        do {
            // Connect to server
            try sshClient.connect(to: server.config)
            updatedServer.isConnected = true
            updatedServer.error = nil
            
            // Gather and calculate CPU usage
            if let cpuInfo = try sshClient.getCPUInfo() {
                if let prevTotal = updatedServer.previousCPUTotal, let prevIdle = updatedServer.previousCPUIdle {
                    let totalDiff = cpuInfo.total > prevTotal ? cpuInfo.total - prevTotal : 0
                    let idleDiff = cpuInfo.idle > prevIdle ? cpuInfo.idle - prevIdle : 0
                    
                    if totalDiff > 0 {
                        let usage = (Double(totalDiff) - Double(idleDiff)) / Double(totalDiff)
                        updatedServer.cpuUsage = Float(usage * 100.0)
                    } else {
                        updatedServer.cpuUsage = 0
                    }
                } else {
                    // First run, no previous data to compare against
                    updatedServer.cpuUsage = 0
                }
                updatedServer.previousCPUTotal = cpuInfo.total
                updatedServer.previousCPUIdle = cpuInfo.idle
            } else {
                updatedServer.cpuUsage = nil
            }
            
            // Gather memory usage
            let memoryInfo = try sshClient.getMemoryUsage()
            updatedServer.memoryUsage = memoryInfo.usagePercentage
            updatedServer.totalMemory = memoryInfo.totalGB
            
            // Gather Docker containers
            updatedServer.dockerContainers = try sshClient.getDockerContainers()
            
            // Gather network usage and calculate speeds
            let networkInfo = try sshClient.getNetworkUsage()
            let currentTime = Date()
            
            // Calculate speed if we have previous measurements
            if let prevUpload = updatedServer.previousNetworkUpload,
               let prevDownload = updatedServer.previousNetworkDownload,
               let prevTime = updatedServer.previousNetworkTime {
                
                let timeDiff = currentTime.timeIntervalSince(prevTime)
                if timeDiff > 0 {
                    // Calculate bytes per second
                    let uploadDiff = networkInfo.uploadMbps > prevUpload ? networkInfo.uploadMbps - prevUpload : 0
                    let downloadDiff = networkInfo.downloadMbps > prevDownload ? networkInfo.downloadMbps - prevDownload : 0
                    
                    let uploadBytesPerSec = UInt64(Double(uploadDiff) / timeDiff)
                    let downloadBytesPerSec = UInt64(Double(downloadDiff) / timeDiff)
                    
                    // Store calculated speeds
                    updatedServer.networkUpload = uploadBytesPerSec
                    updatedServer.networkDownload = downloadBytesPerSec
                    
                    // Format to human readable
                    updatedServer.networkUploadStr = formatNetworkSpeed(uploadBytesPerSec)
                    updatedServer.networkDownloadStr = formatNetworkSpeed(downloadBytesPerSec)
                } else {
                    // No time difference, keep previous values
                    updatedServer.networkUploadStr = updatedServer.networkUploadStr ?? "0B/s"
                    updatedServer.networkDownloadStr = updatedServer.networkDownloadStr ?? "0B/s"
                }
            } else {
                // First measurement, no speed available yet
                updatedServer.networkUpload = 0
                updatedServer.networkDownload = 0
                updatedServer.networkUploadStr = "0B/s"
                updatedServer.networkDownloadStr = "0B/s"
            }
            
            // Store current values for next calculation
            updatedServer.previousNetworkUpload = networkInfo.uploadMbps
            updatedServer.previousNetworkDownload = networkInfo.downloadMbps
            updatedServer.previousNetworkTime = currentTime
            
            // Gather disk space
            let diskInfo = try sshClient.getDiskSpace()
            updatedServer.diskAvailableGB = diskInfo.availableGB
            updatedServer.diskUsagePercent = diskInfo.usagePercent
            
            // Get remote IP address
            updatedServer.remoteIP = try? sshClient.getRemoteIP()
            
            sshClient.disconnect()
            
        } catch {
            updatedServer.isConnected = false
            updatedServer.error = error.localizedDescription
            updatedServer.cpuUsage = nil
            updatedServer.memoryUsage = nil
            updatedServer.totalMemory = nil
            updatedServer.dockerContainers = []
            updatedServer.networkUpload = nil
            updatedServer.networkDownload = nil
            updatedServer.networkUploadStr = nil
            updatedServer.networkDownloadStr = nil
            updatedServer.previousNetworkUpload = nil
            updatedServer.previousNetworkDownload = nil
            updatedServer.previousNetworkTime = nil
            updatedServer.diskAvailableGB = nil
            updatedServer.diskUsagePercent = nil
            updatedServer.remoteIP = nil
            updatedServer.previousCPUTotal = nil
            updatedServer.previousCPUIdle = nil
            // Keep ping time even if SSH connection fails
        }
        
        return updatedServer
    }
    
    private func formatNetworkSpeed(_ bytesPerSecond: UInt64) -> String {
        if bytesPerSecond >= 1_073_741_824 { // >= 1 GB/s
            return String(format: "%.1fGB/s", Float(bytesPerSecond) / 1_073_741_824)
        } else if bytesPerSecond >= 1_048_576 { // >= 1 MB/s
            return String(format: "%.1fMB/s", Float(bytesPerSecond) / 1_048_576)
        } else if bytesPerSecond >= 1_024 { // >= 1 KB/s
            return String(format: "%.1fKB/s", Float(bytesPerSecond) / 1_024)
        } else {
            return String(format: "%dB/s", bytesPerSecond)
        }
    }
}