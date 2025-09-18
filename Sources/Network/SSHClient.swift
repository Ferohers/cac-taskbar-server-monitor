import Foundation

enum SSHError: Error, LocalizedError {
    case connectionFailed(String)
    case authenticationFailed
    case commandFailed(String)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .authenticationFailed:
            return "Authentication failed"
        case .commandFailed(let message):
            return "Command failed: \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}

struct MemoryInfo {
    let usagePercentage: Float
    let totalGB: Float
}

struct CPUInfo {
    let total: UInt64
    let idle: UInt64
}

struct NetworkInfo {
    let uploadMbps: UInt64
    let downloadMbps: UInt64
    let downloadStr: String?
    let uploadStr: String?
    
    init(uploadMbps: UInt64, downloadMbps: UInt64, downloadStr: String? = nil, uploadStr: String? = nil) {
        self.uploadMbps = uploadMbps
        self.downloadMbps = downloadMbps
        self.downloadStr = downloadStr
        self.uploadStr = uploadStr
    }
}

class SSHClient {
    private var isConnected = false
    private var serverConfig: ServerConfig?
    private let keychainManager: KeychainManager
    private var tempKeyFilePath: String?
    
    init(keychainManager: KeychainManager = KeychainManager()) {
        self.keychainManager = keychainManager
    }
    
    func connect(to config: ServerConfig) throws {
        serverConfig = config
        
        let testCommand = try buildSSHCommand(command: "echo 'connected'", config: config)
        let result = executeCommand(testCommand)
        
        if result.exitCode != 0 {
            throw SSHError.connectionFailed(result.error)
        }
        
        if !result.output.contains("connected") {
            throw SSHError.authenticationFailed
        }
        
        isConnected = true
    }
    
    func disconnect() {
        isConnected = false
        serverConfig = nil
        
        // Clean up temporary SSH key file if it exists
        if let tempPath = tempKeyFilePath {
            try? FileManager.default.removeItem(atPath: tempPath)
            tempKeyFilePath = nil
        }
    }
    
    func getCPUInfo() throws -> CPUInfo? {
        guard isConnected, let config = serverConfig else {
            throw SSHError.connectionFailed("Not connected")
        }
        
        // Get total and idle CPU times from /proc/stat for Linux.
        let command = "grep '^cpu ' /proc/stat | awk '{print ($2+$3+$4+$5+$6+$7+$8+$9+$10) \" \" $5}'"
        let sshCommand = try buildSSHCommand(command: command, config: config)
        let result = executeCommand(sshCommand)
        
        if result.exitCode != 0 {
            // Fallback for non-Linux or if /proc/stat fails
            return nil
        }
        
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = output.components(separatedBy: " ")
        if parts.count == 2, let total = UInt64(parts[0]), let idle = UInt64(parts[1]) {
            return CPUInfo(total: total, idle: idle)
        }
        
        return nil
    }
    
    func getMemoryUsage() throws -> MemoryInfo {
        guard isConnected, let config = serverConfig else {
            throw SSHError.connectionFailed("Not connected")
        }
        
        // Manually verified and corrected command string with proper escaping for printf in awk
        let command = "free -m 2>/dev/null | awk 'NR==2{printf \"%.2f %.2f\", $3*100/$2, $2/1024}' || vm_stat | awk 'BEGIN{total=used=0} /Pages free/{free=$3} /Pages active/{active=$3} /Pages inactive/{inactive=$3} /Pages speculative/{spec=$3} /Pages wired/{wired=$3} END{total=(free+active+inactive+wired)*4096/1024/1024/1024; used=(active+inactive+wired)*4096/1024/1024/1024; printf \"%.2f %.2f\", used*100/total, total}'"
        let sshCommand = try buildSSHCommand(command: command, config: config)
        let result = executeCommand(sshCommand)
        
        if result.exitCode != 0 {
            throw SSHError.commandFailed(result.error)
        }
        
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = output.components(separatedBy: " ")
        
        guard components.count >= 2,
              let usage = Float(components[0]),
              let total = Float(components[1]) else {
            throw SSHError.invalidResponse
        }
        
        return MemoryInfo(usagePercentage: usage, totalGB: total)
    }
    
    func getDockerContainers() throws -> [DockerContainer] {
        guard isConnected, let config = serverConfig else {
            throw SSHError.connectionFailed("Not connected")
        }
        
        // First get basic container info including IDs
        let commands = [
            // First try with format string including ID
            "docker ps -a --format '{{.ID}}|{{.Names}}|{{.Status}}|{{.Image}}' 2>/dev/null",
            // Fallback to simpler format with ID
            "docker ps -a --format '{{.ID}} {{.Names}} {{.Status}}' 2>/dev/null",
            // Last resort: basic docker ps
            "docker ps -a 2>/dev/null"
        ]
        
        var containers: [DockerContainer] = []
        
        for command in commands {
            let sshCommand = try buildSSHCommand(command: command, config: config)
            let result = executeCommand(sshCommand)
            
            if result.exitCode == 0 && !result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                containers = parseDockerOutput(result.output, format: command.contains("|") ? "pipe" : (command.contains("{{.ID}} {{.Names}} {{.Status}}") ? "space" : "raw"))
                break
            }
        }
        
        // Now get start times for running containers
        if !containers.isEmpty {
            containers = try getContainerStartTimes(containers, config: config)
        }
        
        return containers
    }
    
    private func getContainerStartTimes(_ containers: [DockerContainer], config: ServerConfig) throws -> [DockerContainer] {
        var updatedContainers: [DockerContainer] = []
        
        for container in containers {
            var updatedContainer = container
            
            // Only get start time for running containers
            if container.status.lowercased().contains("up") {
                let inspectCommand = "docker inspect --format='{{.State.StartedAt}}' '\(container.name)' 2>/dev/null"
                let sshCommand = try buildSSHCommand(command: inspectCommand, config: config)
                let result = executeCommand(sshCommand)
                
                if result.exitCode == 0 {
                    let startTimeString = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let startTime = parseDockerTimestamp(startTimeString) {
                        updatedContainer = DockerContainer(
                            id: container.id,
                            name: container.name,
                            status: container.status,
                            image: container.image,
                            startTime: startTime
                        )
                    }
                }
            }
            
            updatedContainers.append(updatedContainer)
        }
        
        return updatedContainers
    }
    
    private func parseDockerTimestamp(_ timestamp: String) -> Date? {
        // Docker timestamps are in ISO 8601 format like "2023-12-01T10:30:45.123456789Z"
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: timestamp) {
            return date
        }
        
        // Fallback for timestamps without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: timestamp)
    }
    
    private func parseDockerOutput(_ output: String, format: String) -> [DockerContainer] {
        let lines = output.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var containers: [DockerContainer] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty || trimmedLine.contains("CONTAINER ID") || trimmedLine.contains("NAMES") {
                continue
            }
            
            var id = "", name = "", status = "", image = ""
            
            switch format {
            case "pipe":
                let components = trimmedLine.components(separatedBy: "|")
                if components.count >= 4 {
                    id = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    name = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    status = components[2].trimmingCharacters(in: .whitespacesAndNewlines)
                    image = components[3].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            case "space":
                let components = trimmedLine.components(separatedBy: " ")
                if components.count >= 3 {
                    id = components[0]
                    name = components[1]
                    status = components[2]
                    image = "unknown"
                }
            case "raw":
                // Parse raw docker ps output
                let components = trimmedLine.components(separatedBy: CharacterSet.whitespacesAndNewlines).filter { !$0.isEmpty }
                if components.count >= 2 {
                    id = components[0]  // ID is usually first column
                    name = components.last ?? ""  // Name is usually last column
                    status = components.count > 5 ? components[4] : "unknown"
                    image = components.count > 1 ? components[1] : "unknown"
                }
            default:
                continue
            }
            
            if !name.isEmpty && name != "NAMES" && !id.isEmpty {
                containers.append(DockerContainer(id: id, name: name, status: status, image: image, startTime: nil))
            }
        }
        
        return containers
    }
    
    func getNetworkUsage() throws -> NetworkInfo {
        guard isConnected, let config = serverConfig else {
            throw SSHError.connectionFailed("Not connected")
        }
        
        // Get raw network byte counts for speed calculation
        let command = """
        # Get network interface with most activity (not loopback)
        iface=$(awk 'NR>2 && !/lo:/ && ($2+$10>1000) {gsub(/:/, "", $1); bytes=$2+$10; if(bytes>max) {max=bytes; best=$1}} END{print best}' /proc/net/dev)
        
        # Fallback to default route interface
        if [ -z "$iface" ]; then
            iface=$(ip route | awk '/default/ {print $5; exit}' 2>/dev/null)
        fi
        
        # Final fallback to any non-loopback interface
        if [ -z "$iface" ]; then
            iface=$(awk 'NR>2 && !/lo:/ {gsub(/:/, "", $1); print $1; exit}' /proc/net/dev)
        fi
        
        if [ -n "$iface" ] && [ -f /proc/net/dev ]; then
            # Get raw bytes received and transmitted for speed calculation
            awk -v iface="$iface:" '$1 == iface {
                printf "%d %d", $2, $10;
            }' /proc/net/dev
        else
            echo "0 0"
        fi
        """
        let sshCommand = try buildSSHCommand(command: command, config: config)
        let result = executeCommand(sshCommand)
        
        if result.exitCode != 0 {
            return NetworkInfo(uploadMbps: 0, downloadMbps: 0)
        }
        
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = output.components(separatedBy: " ").filter { !$0.isEmpty }
        
        guard components.count >= 2,
              let downloadBytes = UInt64(components[0]),
              let uploadBytes = UInt64(components[1]) else {
            return NetworkInfo(uploadMbps: 0, downloadMbps: 0)
        }
        
        // Return raw byte values for speed calculation in ServerMonitor
        return NetworkInfo(uploadMbps: uploadBytes, downloadMbps: downloadBytes)
    }
    
    func getDiskSpace() throws -> DiskInfo {
        guard isConnected, let config = serverConfig else {
            throw SSHError.connectionFailed("Not connected")
        }
        
        // Get main drive disk space (usually / mount point)
        let command = "df -BG / 2>/dev/null | awk 'NR==2{gsub(/G/,\"\"); avail=$4; used=$3; total=$2; usage=used*100/total; print avail\" \"usage\" \"total}'"
        let sshCommand = try buildSSHCommand(command: command, config: config)
        let result = executeCommand(sshCommand)
        
        if result.exitCode != 0 {
            throw SSHError.commandFailed(result.error)
        }
        
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = output.components(separatedBy: " ").filter { !$0.isEmpty }
        
        guard components.count >= 3,
              let availableGB = Float(components[0]),
              let usagePercent = Float(components[1]),
              let totalGB = Float(components[2]) else {
            throw SSHError.invalidResponse
        }
        
        return DiskInfo(availableGB: availableGB, usagePercent: usagePercent, totalGB: totalGB)
    }
    
    func getRemoteIP() throws -> String {
        guard isConnected, let config = serverConfig else {
            throw SSHError.connectionFailed("Not connected")
        }
        
        // Get the server's public IP address
        let command = "curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || curl -s ipecho.net/plain 2>/dev/null || hostname -I | awk '{print $1}'"
        let sshCommand = try buildSSHCommand(command: command, config: config)
        let result = executeCommand(sshCommand)
        
        if result.exitCode == 0 {
            let ip = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            return ip.isEmpty ? config.hostname : ip
        }
        
        return config.hostname
    }
    
    func restartContainer(containerId: String) throws -> Bool {
        guard isConnected, let config = serverConfig else {
            throw SSHError.connectionFailed("Not connected")
        }
        
        // First, inspect the container to check if it's a compose container
        let inspectCommand = """
        docker inspect '\(containerId)' --format='{{index .Config.Labels "com.docker.compose.project"}}|{{index .Config.Labels "com.docker.compose.service"}}|{{index .Config.Labels "com.docker.compose.project.working_dir"}}' 2>/dev/null
        """
        let sshCommand = try buildSSHCommand(command: inspectCommand, config: config)
        let result = executeCommand(sshCommand)
        
        if result.exitCode != 0 {
            throw SSHError.commandFailed("Failed to inspect container: \(result.error)")
        }
        
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = output.components(separatedBy: "|")
        
        // Check if this is a compose container
        if components.count >= 3,
           let project = components[0].isEmpty ? nil : components[0],
           let service = components[1].isEmpty ? nil : components[1],
           let workingDir = components[2].isEmpty ? nil : components[2],
           project != "<no value>", service != "<no value>", workingDir != "<no value>" {
            
            // This is a compose container, restart using docker compose
            return try restartComposeService(project: project, service: service, workingDir: workingDir, config: config)
        } else {
            // This is a standalone container, restart using docker restart
            return try restartStandaloneContainer(containerId: containerId, config: config)
        }
    }
    
    private func restartComposeService(project: String, service: String, workingDir: String, config: ServerConfig) throws -> Bool {
        // Change to the working directory and restart the service
        let restartCommand = """
        cd '\(workingDir)' && docker compose restart '\(service)' 2>/dev/null
        """
        let sshCommand = try buildSSHCommand(command: restartCommand, config: config)
        let result = executeCommand(sshCommand)
        
        return result.exitCode == 0
    }
    
    private func restartStandaloneContainer(containerId: String, config: ServerConfig) throws -> Bool {
        let restartCommand = "docker restart '\(containerId)' 2>/dev/null"
        let sshCommand = try buildSSHCommand(command: restartCommand, config: config)
        let result = executeCommand(sshCommand)
        
        return result.exitCode == 0
    }
    
    func startContainer(containerId: String) throws -> Bool {
        guard isConnected, let config = serverConfig else {
            throw SSHError.connectionFailed("Not connected")
        }
        
        // First, inspect the container to check if it's a compose container
        let inspectCommand = """
        docker inspect '\(containerId)' --format='{{index .Config.Labels "com.docker.compose.project"}}|{{index .Config.Labels "com.docker.compose.service"}}|{{index .Config.Labels "com.docker.compose.project.working_dir"}}' 2>/dev/null
        """
        let sshCommand = try buildSSHCommand(command: inspectCommand, config: config)
        let result = executeCommand(sshCommand)
        
        if result.exitCode != 0 {
            throw SSHError.commandFailed("Failed to inspect container: \(result.error)")
        }
        
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = output.components(separatedBy: "|")
        
        // Check if this is a compose container
        if components.count >= 3,
           let project = components[0].isEmpty ? nil : components[0],
           let service = components[1].isEmpty ? nil : components[1],
           let workingDir = components[2].isEmpty ? nil : components[2],
           project != "<no value>", service != "<no value>", workingDir != "<no value>" {
            
            // This is a compose container, start using docker compose
            return try startComposeService(project: project, service: service, workingDir: workingDir, config: config)
        } else {
            // This is a standalone container, start using docker start
            return try startStandaloneContainer(containerId: containerId, config: config)
        }
    }
    
    private func startComposeService(project: String, service: String, workingDir: String, config: ServerConfig) throws -> Bool {
        // Change to the working directory and start the service
        let startCommand = """
        cd '\(workingDir)' && docker compose start '\(service)' 2>/dev/null
        """
        let sshCommand = try buildSSHCommand(command: startCommand, config: config)
        let result = executeCommand(sshCommand)
        
        return result.exitCode == 0
    }
    
    private func startStandaloneContainer(containerId: String, config: ServerConfig) throws -> Bool {
        let startCommand = "docker start '\(containerId)' 2>/dev/null"
        let sshCommand = try buildSSHCommand(command: startCommand, config: config)
        let result = executeCommand(sshCommand)
        
        return result.exitCode == 0
    }
    
    private func buildSSHCommand(command: String, config: ServerConfig) throws -> String {
        var sshCommand = "ssh -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
        
        // Handle SSH key authentication from keychain
        if config.hasKeychainSSHKey {
            do {
                let tempKeyPath = try keychainManager.writeSSHKeyToTempFile(for: config.id.uuidString)
                self.tempKeyFilePath = tempKeyPath
                let escapedPath = tempKeyPath.replacingOccurrences(of: "'", with: "'\"'\"'")
                sshCommand += " -i '\(escapedPath)'"
            } catch {
                throw SSHError.authenticationFailed
            }
        }
        // Handle password authentication from keychain
        else if config.hasKeychainPassword {
            // For password authentication, we'll use sshpass if available
            do {
                let password = try keychainManager.retrievePassword(for: config.id.uuidString)
                let escapedPassword = password.replacingOccurrences(of: "'", with: "'\"'\"'")
                sshCommand = "sshpass -p '\(escapedPassword)' " + sshCommand
            } catch {
                throw SSHError.authenticationFailed
            }
        }
        else {
            // No credentials configured
            throw SSHError.authenticationFailed
        }
        
        if config.port != 22 {
            sshCommand += " -p \(config.port)"
        }
        
        // Escape the username@hostname in case hostname has special characters
        let userHost = "\(config.username)@\(config.hostname)"
        let escapedUserHost = userHost.replacingOccurrences(of: "'", with: "'\"'\"'")
        sshCommand += " '\(escapedUserHost)'"
        
        // Properly escape the command to handle nested quotes and special characters
        let escapedCommand = command.replacingOccurrences(of: "'", with: "'\"'\"'")
        sshCommand += " '\(escapedCommand)'"
        
        return sshCommand
    }
    
    private func executeCommand(_ command: String) -> (output: String, error: String, exitCode: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ("", "Failed to execute command: \(error.localizedDescription)", 1)
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""
        
        return (output, error, process.terminationStatus)
    }
    
    func pingServer(hostname: String) -> Float? {
        // Use local ping command to measure latency
        let command = "ping -c 1 -W 3000 '\(hostname)' | grep 'time=' | sed -n 's/.*time=\\([0-9.]*\\).*/\\1/p'"
        let result = executeCommand(command)
        
        if result.exitCode == 0 {
            let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if let pingTime = Float(output), pingTime > 0 {
                return pingTime
            }
        }
        
        return nil
    }
    
    func restartServer() throws -> Bool {
        guard isConnected, let config = serverConfig else {
            throw SSHError.connectionFailed("Not connected")
        }
        
        // Use sudo reboot command to restart the server
        let command = "sudo reboot"
        let sshCommand = try buildSSHCommand(command: command, config: config)
        _ = executeCommand(sshCommand)
        
        // For reboot command, we expect the connection to drop, so exit code might not be 0
        // We'll consider it successful if the command was executed (connection drops)
        return true
    }
}
