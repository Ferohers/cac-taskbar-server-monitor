import Foundation

class ServerMonitor {
    private var servers: [ServerData] = []
    private var monitoringTimer: Timer?
    private let updateInterval: TimeInterval = 30.0 // Update every 30 seconds
    private let settingsManager = SettingsManager.shared
    
    var onDataUpdate: (([ServerData]) -> Void)?
    
    func startMonitoring(servers configs: [ServerConfig]) {
        stopMonitoring()
        
        // Initialize server data only for enabled servers
        let enabledConfigs = configs.filter { $0.isEnabled }
        self.servers = enabledConfigs.map { ServerData(config: $0) }
        
        // Start monitoring only if there are enabled servers
        if !self.servers.isEmpty {
            performMonitoringCheck()
            
            monitoringTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
                self?.performMonitoringCheck()
            }
        } else {
            // No enabled servers, just notify with empty array
            onDataUpdate?([])
        }
    }
    
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        // Clear servers array to prevent any lingering background tasks from accessing it
        servers.removeAll()
    }
    
    private func performMonitoringCheck() {
        let currentServers = servers // Capture current state
        
        for (index, server) in currentServers.enumerated() {
            // Perform monitoring in background
            DispatchQueue.global(qos: .utility).async { [weak self] in
                let updatedServer = self?.monitorServer(server) ?? server
                
                DispatchQueue.main.async {
                    // Safely update only if the server still exists at the same index
                    guard let strongSelf = self,
                          index < strongSelf.servers.count,
                          strongSelf.servers[index].config.id == updatedServer.config.id else {
                        return // Server was removed or array changed, skip update
                    }
                    
                    strongSelf.servers[index] = updatedServer
                    
                    // Check notifications for this server
                    strongSelf.settingsManager.checkServerMetrics(for: updatedServer)
                    
                    strongSelf.onDataUpdate?(strongSelf.servers)
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