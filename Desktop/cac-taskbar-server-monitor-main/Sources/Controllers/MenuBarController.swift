import Cocoa
import UserNotifications

class MenuBarController {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var serverMenuItems: [NSMenuItem] = []
    private weak var target: AnyObject?
    private var animationTimer: Timer?
    private var animationFrame = 0
    
    init(statusItem: NSStatusItem, target: AnyObject?) {
        self.statusItem = statusItem
        self.target = target
        setupMenu()
    }
    
    private func setupMenu() {
        statusItem.menu = menu
        showInitialLoadingState()
    }
    
    private func showInitialLoadingState() {
        menu.removeAllItems()
        
        // Start animating the taskbar icon
        startIconAnimation()
        
        let loadingItem = NSMenuItem(title: "Starting server monitoring...", action: nil, keyEquivalent: "")
        loadingItem.isEnabled = false
        let loadingAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
            .foregroundColor: NSColor.labelColor
        ]
        loadingItem.attributedTitle = NSAttributedString(string: "Starting server monitoring...", attributes: loadingAttributes)
        menu.addItem(loadingItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let addServerItem = NSMenuItem(title: "Add Server...", action: #selector(addServer), keyEquivalent: "")
        addServerItem.target = target
        menu.addItem(addServerItem)
        
        let preferencesItem = NSMenuItem(title: "Configure Servers...", action: #selector(showConfigWindow), keyEquivalent: ",")
        preferencesItem.target = target
        menu.addItem(preferencesItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit AltanMon", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = target
        menu.addItem(quitItem)
    }
    
    func updateServerData(_ servers: [ServerData]) {
        DispatchQueue.main.async { [weak self] in
            // Filter out disabled servers from display
            let enabledServers = servers.filter { $0.config.isEnabled }
            self?.updateMenu(with: enabledServers)
        }
    }
    
    private func updateMenu(with servers: [ServerData]) {
        menu.removeAllItems()
        serverMenuItems.removeAll()
        
        if servers.isEmpty {
            let noServersItem = NSMenuItem(title: "No servers configured", action: nil, keyEquivalent: "")
            noServersItem.isEnabled = false
            menu.addItem(noServersItem)
        } else {
            // Check if any servers are still being processed (no lastUpdate means initial connection)
            let serversBeingProcessed = servers.filter { $0.lastUpdate == nil }
            
            if !serversBeingProcessed.isEmpty {
                // Continue or start icon animation if servers are still being processed
                if animationTimer == nil {
                    startIconAnimation()
                }
                
                let reachingServersItem = NSMenuItem(title: "Reaching servers...", action: nil, keyEquivalent: "")
                reachingServersItem.isEnabled = false
                let loadingAttributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
                    .foregroundColor: NSColor.labelColor
                ]
                reachingServersItem.attributedTitle = NSAttributedString(string: "Reaching servers...", attributes: loadingAttributes)
                menu.addItem(reachingServersItem)
                
                if servers.count > serversBeingProcessed.count {
                    menu.addItem(NSMenuItem.separator())
                }
            }
            
            for (index, server) in servers.enumerated() {
                // Only show servers that have been processed at least once
                if server.lastUpdate != nil {
                    addServerSection(server: server)
                    
                    // Add separator if not the last processed server
                    let remainingServers = servers.dropFirst(index + 1).filter { $0.lastUpdate != nil }
                    if !remainingServers.isEmpty {
                        menu.addItem(NSMenuItem.separator())
                    }
                }
            }
            
            // Stop animation when all servers are processed (no servers being processed)
            if serversBeingProcessed.isEmpty {
                stopIconAnimation()
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let addServerItem = NSMenuItem(title: "Add Server...", action: #selector(addServer), keyEquivalent: "")
        addServerItem.target = target
        menu.addItem(addServerItem)
        
        let preferencesItem = NSMenuItem(title: "Configure Servers...", action: #selector(showConfigWindow), keyEquivalent: ",")
        preferencesItem.target = target
        menu.addItem(preferencesItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit AltanMon", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = target
        menu.addItem(quitItem)
    }
    
    private func addServerSection(server: ServerData) {
        // Prepare full server info for copying
        var fullServerInfo = "\(server.config.hostname) - \(server.remoteIP ?? server.config.hostname)"
        if server.isConnected {
            var infoLines = [fullServerInfo]
            
            // Add health metrics
            var healthItems: [String] = []
            if let memory = server.memoryUsage {
                healthItems.append(String(format: "Memory: %.1f%%", memory))
            }
            if let cpu = server.cpuUsage {
                healthItems.append(String(format: "CPU: %.1f%%", cpu))
            }
            if !healthItems.isEmpty {
                infoLines.append(healthItems.joined(separator: " | "))
            }
            
            // Add network and disk
            var networkDiskItems: [String] = []
            if let uploadStr = server.networkUploadStr, let downloadStr = server.networkDownloadStr {
                networkDiskItems.append("↑\(uploadStr) ↓\(downloadStr)")
            }
            if let availableGB = server.diskAvailableGB {
                networkDiskItems.append(String(format: "%.1f GB free", availableGB))
            }
            if !networkDiskItems.isEmpty {
                infoLines.append(networkDiskItems.joined(separator: " | "))
            }
            
            // Add containers
            let runningContainers = server.dockerContainers.filter { $0.status.lowercased().contains("up") }
            if !runningContainers.isEmpty {
                for container in runningContainers {
                    var containerInfo = container.name
                    if let runtimeHours = container.runtimeHours {
                        containerInfo = "\(container.name) [\(String(format: "%.1fh", runtimeHours))]"
                    }
                    infoLines.append(containerInfo)
                }
            }
            
            fullServerInfo = infoLines.joined(separator: "\n")
        }
        
        // Line 1: Hostname - Remote IP (clickable to copy full info)
        let displayText = "\(server.config.hostname) - \(server.remoteIP ?? server.config.hostname)"
        let serverInfoItem = NSMenuItem(title: displayText, action: #selector(copyServerInfo(_:)), keyEquivalent: "")
        serverInfoItem.target = self
        serverInfoItem.representedObject = fullServerInfo
        let titleFont = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        serverInfoItem.attributedTitle = NSAttributedString(string: displayText, attributes: [
            .font: titleFont,
            .foregroundColor: NSColor.labelColor
        ])
        menu.addItem(serverInfoItem)
        
        if server.isConnected {
            // Line 2: Free memory and CPU with color coding
            var healthItems: [String] = []
            // Use different green shades based on system appearance
            var healthColor: NSColor
            if NSApp.effectiveAppearance.name == .darkAqua {
                // Lighter green for dark mode
                healthColor = NSColor(red: 0.0, green: 0.7, blue: 0.0, alpha: 1.0)
            } else {
                // Darker green for light mode
                healthColor = NSColor(red: 0.0, green: 0.4, blue: 0.0, alpha: 1.0)
            }
            
            if let memory = server.memoryUsage {
                let memoryText = String(format: "Memory: %.1f%%", memory)
                healthItems.append(memoryText)
                
                // Determine color based on memory usage
                if memory > 80 {
                    healthColor = .systemRed
                } else if memory > 60 {
                    healthColor = .systemYellow
                }
            }
            
            if let cpu = server.cpuUsage {
                let cpuText = String(format: "CPU: %.1f%%", cpu)
                healthItems.append(cpuText)
                
                // Determine color based on CPU usage (override memory color if worse)
                if cpu > 80 && healthColor != .systemRed {
                    healthColor = .systemRed
                } else if cpu > 60 && healthColor == .systemGreen {
                    healthColor = .systemYellow
                }
            }
            
            if !healthItems.isEmpty {
                let healthText = healthItems.joined(separator: " | ")
                let healthItem = NSMenuItem(title: healthText, action: nil, keyEquivalent: "")
                healthItem.isEnabled = false
                let coloredAttributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
                    .foregroundColor: healthColor
                ]
                healthItem.attributedTitle = NSAttributedString(string: healthText, attributes: coloredAttributes)
                menu.addItem(healthItem)
            }
            
            // Line 3: Network speed and disk space (combined on one line in white)
            var networkDiskParts: [String] = []
            
            // Add network usage
            if let uploadStr = server.networkUploadStr, let downloadStr = server.networkDownloadStr {
                networkDiskParts.append("↑\(uploadStr) ↓\(downloadStr)")
            }
            
            // Add disk space
            if let availableGB = server.diskAvailableGB {
                networkDiskParts.append(String(format: "%.1f GB free", availableGB))
            }
            
            // Display network and disk together on one line
            if !networkDiskParts.isEmpty {
                let combinedText = networkDiskParts.joined(separator: " | ")
                let networkDiskItem = NSMenuItem(title: combinedText, action: #selector(copyNetworkDiskInfo(_:)), keyEquivalent: "")
                networkDiskItem.target = self
                networkDiskItem.representedObject = combinedText
                networkDiskItem.isEnabled = true // Enable to make it white and clickable
                
                // Use red color for disk if < 2GB, otherwise white
                let diskColor: NSColor
                if let availableGB = server.diskAvailableGB, availableGB < 2.0 {
                    diskColor = .systemRed
                } else {
                    diskColor = .labelColor
                }
                
                let networkDiskAttributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
                    .foregroundColor: diskColor
                ]
                networkDiskItem.attributedTitle = NSAttributedString(string: combinedText, attributes: networkDiskAttributes)
                menu.addItem(networkDiskItem)
            }
            
            // Line 4+: Running containers (each on separate line in white)
            if !server.dockerContainers.isEmpty {
                let runningContainers = server.dockerContainers.filter { container in
                    container.status.lowercased().contains("up")
                }
                
                if !runningContainers.isEmpty {
                    // Add each running container on its own line with restart icon
                    for container in runningContainers {
                        // Format container name with runtime in brackets and restart symbol
                        var displayName = container.name
                        if let runtimeHours = container.runtimeHours {
                            displayName = "\(container.name) [\(String(format: "%.1fh", runtimeHours))] ↻"
                        } else {
                            displayName = "\(container.name) ↻"
                        }
                        
                        let containerItem = NSMenuItem(title: displayName, action: #selector(restartContainer(_:)), keyEquivalent: "")
                        containerItem.target = self
                        // Store both server config and container info for restart action
                        containerItem.representedObject = ["server": server, "container": container]
                        containerItem.isEnabled = true // Enable to make it clickable
                        let containerAttributes: [NSAttributedString.Key: Any] = [
                            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                            .foregroundColor: NSColor.labelColor
                        ]
                        containerItem.attributedTitle = NSAttributedString(string: displayName, attributes: containerAttributes)
                        menu.addItem(containerItem)
                    }
                } else {
                    let noRunningItem = NSMenuItem(title: "No running containers", action: nil, keyEquivalent: "")
                    noRunningItem.isEnabled = false
                    let noRunningAttributes: [NSAttributedString.Key: Any] = [
                        .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                        .foregroundColor: NSColor.labelColor
                    ]
                    noRunningItem.attributedTitle = NSAttributedString(string: "No running containers", attributes: noRunningAttributes)
                    menu.addItem(noRunningItem)
                }
            } else {
                let noDockerItem = NSMenuItem(title: "No containers", action: nil, keyEquivalent: "")
                noDockerItem.isEnabled = false
                let noDockerAttributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                    .foregroundColor: NSColor.labelColor
                ]
                noDockerItem.attributedTitle = NSAttributedString(string: "No containers", attributes: noDockerAttributes)
                menu.addItem(noDockerItem)
            }
        } else {
            // Show connection status for disconnected servers
            let statusText = server.isConnected ? "Connected" : "Disconnected"
            let statusItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
            statusItem.isEnabled = false
            let statusColor: NSColor = server.isConnected ? .systemGreen : .systemRed
            let statusAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
                .foregroundColor: statusColor
            ]
            statusItem.attributedTitle = NSAttributedString(string: statusText, attributes: statusAttributes)
            menu.addItem(statusItem)
            
            if let error = server.error {
                let errorItem = NSMenuItem(title: "Error: \(error)", action: nil, keyEquivalent: "")
                errorItem.isEnabled = false
                let errorAttributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                    .foregroundColor: NSColor.systemRed
                ]
                errorItem.attributedTitle = NSAttributedString(string: "Error: \(error)", attributes: errorAttributes)
                menu.addItem(errorItem)
            }
        }
    }
    
    @objc private func copyServerInfo(_ sender: NSMenuItem) {
        guard let serverInfo = sender.representedObject as? String else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(serverInfo, forType: .string)
        
        // Show notification that text was copied (with permission check)
        showCopiedNotification(text: serverInfo)
    }
    
    private func showCopiedNotification(text: String) {
        // Check if we're running in a proper app bundle context
        guard Bundle.main.bundleIdentifier != nil else {
            print("📋 Copied to clipboard (notifications not available in command line mode)")
            return
        }
        
        // Check notification permissions first
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                print("📋 Copied to clipboard (notifications disabled)")
                return
            }
            
            let content = UNMutableNotificationContent()
            content.title = "Copied to Clipboard"
            content.body = text
            content.sound = nil // Silent notification
            
            let request = UNNotificationRequest(identifier: "copy-notification", content: content, trigger: nil)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Failed to show notification: \(error)")
                } else {
                    print("📋 Copied to clipboard with notification")
                }
            }
        }
    }
    
    @objc private func copyNetworkDiskInfo(_ sender: NSMenuItem) {
        guard let networkDiskInfo = sender.representedObject as? String else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(networkDiskInfo, forType: .string)
        
        // Show notification that text was copied
        showCopiedNotification(text: networkDiskInfo)
    }
    
    @objc private func copyContainerInfo(_ sender: NSMenuItem) {
        guard let containerName = sender.representedObject as? String else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(containerName, forType: .string)
        
        // Show notification that text was copied
        showCopiedNotification(text: containerName)
    }
    
    private func startIconAnimation() {
        guard animationTimer == nil else { return }
        
        animationFrame = 0
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.updateAnimationFrame()
        }
    }
    
    private func stopIconAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        
        // Restore original icon
        if let originalIcon = NSImage.menuBarIcon() {
            statusItem.button?.image = originalIcon
        }
    }
    
    private func updateAnimationFrame() {
        let frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
        let currentFrame = frames[animationFrame % frames.count]
        
        // Create animated icon text
        let animatedIcon = createAnimatedIcon(with: currentFrame)
        statusItem.button?.image = animatedIcon
        
        animationFrame += 1
    }
    
    private func createAnimatedIcon(with spinChar: String) -> NSImage {
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size)
        
        image.lockFocus()
        defer { image.unlockFocus() }
        
        // Clear background
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Draw spinning character
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.labelColor
        ]
        
        let attributedString = NSAttributedString(string: spinChar, attributes: attributes)
        let stringSize = attributedString.size()
        let drawRect = NSRect(
            x: (size.width - stringSize.width) / 2,
            y: (size.height - stringSize.height) / 2,
            width: stringSize.width,
            height: stringSize.height
        )
        
        attributedString.draw(in: drawRect)
        
        image.isTemplate = true
        return image
    }
    
    @objc private func restartContainer(_ sender: NSMenuItem) {
        guard let data = sender.representedObject as? [String: Any],
              let server = data["server"] as? ServerData,
              let container = data["container"] as? DockerContainer else {
            print("Failed to get container restart data")
            return
        }
        
        // Show confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Restart Container"
        alert.informativeText = "Are you sure you want to restart container '\(container.name)'?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Restart")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Perform restart in background
            DispatchQueue.global(qos: .userInitiated).async {
                let sshClient = SSHClient()
                do {
                    try sshClient.connect(to: server.config)
                    let success = try sshClient.restartContainer(containerId: container.id)
                    sshClient.disconnect()
                    
                    DispatchQueue.main.async {
                        if success {
                            self.showRestartNotification(containerName: container.name, success: true)
                        } else {
                            self.showRestartNotification(containerName: container.name, success: false)
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.showRestartNotification(containerName: container.name, success: false, error: error.localizedDescription)
                    }
                }
            }
        }
    }
    
    private func showRestartNotification(containerName: String, success: Bool, error: String? = nil) {
        // Check if we're running in a proper app bundle context
        guard Bundle.main.bundleIdentifier != nil else {
            let message = success ? "✅ Container '\(containerName)' restarted successfully" : "❌ Failed to restart container '\(containerName)'"
            print(message)
            if let error = error {
                print("Error: \(error)")
            }
            return
        }
        
        // Check notification permissions first
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                let message = success ? "✅ Container '\(containerName)' restarted successfully" : "❌ Failed to restart container '\(containerName)'"
                print(message)
                return
            }
            
            let content = UNMutableNotificationContent()
            content.title = success ? "Container Restarted" : "Restart Failed"
            if success {
                content.body = "Container '\(containerName)' has been restarted successfully"
            } else {
                content.body = "Failed to restart container '\(containerName)'"
                if let error = error {
                    content.body += ": \(error)"
                }
            }
            content.sound = nil // Silent notification
            
            let request = UNNotificationRequest(identifier: "restart-notification", content: content, trigger: nil)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Failed to show restart notification: \(error)")
                } else {
                    let message = success ? "✅ Container '\(containerName)' restarted successfully" : "❌ Failed to restart container '\(containerName)'"
                    print(message)
                }
            }
        }
    }
    
    @objc private func addServer() {}
    @objc private func showConfigWindow() {}
    @objc private func quitApp() {}
}
