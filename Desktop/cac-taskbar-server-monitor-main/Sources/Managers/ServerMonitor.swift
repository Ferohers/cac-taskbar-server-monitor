import Foundation

class ServerMonitor {
    private var servers: [ServerData] = []
    private var monitoringTimer: Timer?
    private let updateInterval: TimeInterval = 30.0 // Update every 30 seconds
    
    var onDataUpdate: (([ServerData]) -> Void)?
    
    func startMonitoring(servers configs: [ServerConfig]) {
        stopMonitoring()
        
        // Initialize server data only for enabled servers
        let enabledConfigs = configs.filter { $0.isEnabled }
        self.servers = enabledConfigs.map { ServerData(config: $0) }
        
        // Start monitoring only if there are enabled servers
        if !self.servers.isEmpty {
            performInitialCheck()
            
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
    }
    
    private func performInitialCheck() {
        performMonitoringCheck()
    }
    
    private func performMonitoringCheck() {
        for i in 0..<servers.count {
            let server = servers[i]
            
            // Perform monitoring in background
            DispatchQueue.global(qos: .utility).async { [weak self] in
                let updatedServer = self?.monitorServer(server) ?? server
                
                DispatchQueue.main.async {
                    self?.servers[i] = updatedServer
                    self?.onDataUpdate?(self?.servers ?? [])
                }
            }
        }
    }
    
    private func monitorServer(_ server: ServerData) -> ServerData {
        var updatedServer = server
        updatedServer.lastUpdate = Date()
        
        // Create SSH connection and gather metrics
        let sshClient = SSHClient()
        
        do {
            // Connect to server
            try sshClient.connect(to: server.config)
            updatedServer.isConnected = true
            updatedServer.error = nil
            
            // Gather CPU usage
            if let cpuUsage = try sshClient.getCPUUsage() {
                updatedServer.cpuUsage = cpuUsage
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
                    let uploadDiff = networkInfo.uploadMbps - prevUpload
                    let downloadDiff = networkInfo.downloadMbps - prevDownload
                    
                    let uploadBytesPerSec = uploadDiff / timeDiff
                    let downloadBytesPerSec = downloadDiff / timeDiff
                    
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
        }
        
        return updatedServer
    }
    
    private func formatNetworkSpeed(_ bytesPerSecond: Double) -> String {
        let absBytes = abs(bytesPerSecond)
        
        if absBytes >= 1_073_741_824 { // >= 1 GB/s
            return String(format: "%.1fGB/s", bytesPerSecond / 1_073_741_824)
        } else if absBytes >= 1_048_576 { // >= 1 MB/s
            return String(format: "%.1fMB/s", bytesPerSecond / 1_048_576)
        } else if absBytes >= 1_024 { // >= 1 KB/s
            return String(format: "%.1fKB/s", bytesPerSecond / 1_024)
        } else {
            return String(format: "%.0fB/s", bytesPerSecond)
        }
    }
}