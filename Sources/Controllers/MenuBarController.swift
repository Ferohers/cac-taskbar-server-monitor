
import Cocoa
import UserNotifications

class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private weak var target: AnyObject?
    private var animationTimer: Timer?
    private var animationFrame = 0
    private let settingsManager = SettingsManager.shared
    
    
    
    init(statusItem: NSStatusItem, target: AnyObject?) {
        self.statusItem = statusItem
        self.target = target
        super.init()
        setupMenu()
    }
    
    private func setupMenu() {
        statusItem.menu = menu
        
        // Set up menu delegate to handle cleanup
        menu.delegate = self
        
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
        
        let preferencesItem = NSMenuItem(title: "Settings...", action: #selector(AppDelegate.showSettingsWindow), keyEquivalent: ",")
        preferencesItem.target = target
        menu.addItem(preferencesItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit Duman", action: #selector(AppDelegate.quitApp), keyEquivalent: "q")
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
        
        let preferencesItem = NSMenuItem(title: "Settings...", action: #selector(AppDelegate.showSettingsWindow), keyEquivalent: ",")
        preferencesItem.target = target
        menu.addItem(preferencesItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit Duman", action: #selector(AppDelegate.quitApp), keyEquivalent: "q")
        quitItem.target = target
        menu.addItem(quitItem)
    }
    
    private func addServerSection(server: ServerData) {
        // Prepare full server info for copying (exclude ping from copy)
        var fullServerInfo = server.config.hostname
        if server.isConnected {
            var infoLines = [server.config.hostname]
            
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
        
        // Line 1: Hostname with ping time (clickable to copy full info, but not ping)
        let displayText = server.config.hostname
        
        let serverInfoItem = NSMenuItem(title: displayText, action: #selector(handleServerInfoClick(_:)), keyEquivalent: "")
        serverInfoItem.target = self
        serverInfoItem.representedObject = ["fullServerInfo": fullServerInfo, "serverData": server]
        serverInfoItem.toolTip = "Click to choose: copy server data or restart server"
        let titleFont = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        
        if let pingTime = server.pingTime {
            // Create attributed string with hostname in white and ping in color
            let fullText = server.config.hostname + String(format: " (%.0fms)", pingTime)
            let attributedString = NSMutableAttributedString(string: fullText)
            
            // Set hostname part to white
            attributedString.addAttributes([
                .font: titleFont,
                .foregroundColor: NSColor.labelColor
            ], range: NSRange(location: 0, length: server.config.hostname.count))
            
            // Set ping part to appropriate color
            var pingColor: NSColor
            if pingTime <= 65 {
                if NSApp.effectiveAppearance.name == .darkAqua {
                    pingColor = NSColor(red: 0.0, green: 0.7, blue: 0.0, alpha: 1.0) // Lighter green for dark mode
                } else {
                    pingColor = NSColor(red: 0.0, green: 0.4, blue: 0.0, alpha: 1.0) // Darker green for light mode
                }
            } else if pingTime <= 140 {
                pingColor = .systemYellow
            } else {
                pingColor = .systemRed
            }
            
            let pingText = String(format: " (%.0fms)", pingTime)
            attributedString.addAttributes([
                .font: titleFont,
                .foregroundColor: pingColor
            ], range: NSRange(location: server.config.hostname.count, length: pingText.count))
            
            serverInfoItem.attributedTitle = attributedString
        } else {
            // No ping time, just show hostname in white
            serverInfoItem.attributedTitle = NSAttributedString(string: displayText, attributes: [
                .font: titleFont,
                .foregroundColor: NSColor.labelColor
            ])
        }
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
                let healthItem = NSMenuItem(title: healthText, action: #selector(copyHealthInfo(_:)), keyEquivalent: "")
                healthItem.target = self
                healthItem.representedObject = healthText
                healthItem.toolTip = "Click to copy this system health data (memory and CPU usage)"
                healthItem.isEnabled = true
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
                networkDiskItem.toolTip = "Click to copy this network and disk usage data"
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
            
            // Line 4+: Running containers with section header and separators
            if !server.dockerContainers.isEmpty {
                let runningContainers = server.dockerContainers.filter { container in
                    container.status.lowercased().contains("up")
                }
                
                let advancedSettings = settingsManager.getAdvancedSettings()
                let deadContainers = server.dockerContainers.filter { container in
                    !container.status.lowercased().contains("up")
                }
                
                if !runningContainers.isEmpty {
                    // Add section header with server hostname
                    let sectionHeader = NSMenuItem(title: "Running Containers of \(server.config.hostname)", action: nil, keyEquivalent: "")
                    sectionHeader.isEnabled = false
                    let headerAttributes: [NSAttributedString.Key: Any] = [
                        .font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize),
                        .foregroundColor: NSColor.labelColor
                    ]
                    sectionHeader.attributedTitle = NSAttributedString(string: "Running Containers of \(server.config.hostname)", attributes: headerAttributes)
                    menu.addItem(sectionHeader)
                    
                    // Group containers 2 per line with separator
                    for i in stride(from: 0, to: runningContainers.count, by: 2) {
                        var containerPairs: [String] = []
                        var containerData: [[String: Any]] = []
                        
                        // First container
                        let container1 = runningContainers[i]
                        var displayName1 = container1.name
                        if let runtimeHours = container1.runtimeHours {
                            displayName1 = "\(container1.name) [\(String(format: "%.1fh", runtimeHours))]"
                        } else {
                            displayName1 = container1.name
                        }
                        containerPairs.append(displayName1)
                        containerData.append(["server": server, "container": container1])
                        
                        // Second container if exists
                        if i + 1 < runningContainers.count {
                            let container2 = runningContainers[i + 1]
                            var displayName2 = container2.name
                            if let runtimeHours = container2.runtimeHours {
                                displayName2 = "\(container2.name) [\(String(format: "%.1fh", runtimeHours))]"
                            } else {
                                displayName2 = container2.name
                            }
                            containerPairs.append(displayName2)
                            containerData.append(["server": server, "container": container2])
                        }
                        
                        // Create combined display text with separator
                        let combinedText = containerPairs.joined(separator: " • ")
                        
                        let containerItem = NSMenuItem(title: combinedText, action: #selector(handleContainerAction(_:)), keyEquivalent: "")
                        containerItem.target = self
                        // Store container data for action handling
                        containerItem.representedObject = containerData
                        containerItem.toolTip = "Click to restart the selected Docker container (confirmation dialog will appear)"
                        containerItem.isEnabled = true
                        let containerAttributes: [NSAttributedString.Key: Any] = [
                            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
                            .foregroundColor: NSColor.labelColor
                        ]
                        containerItem.attributedTitle = NSAttributedString(string: combinedText, attributes: containerAttributes)
                        menu.addItem(containerItem)
                    }
                } else {
                    // Add section header with server hostname
                    let sectionHeader = NSMenuItem(title: "Running Containers of \(server.config.hostname)", action: nil, keyEquivalent: "")
                    sectionHeader.isEnabled = false
                    let headerAttributes: [NSAttributedString.Key: Any] = [
                        .font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize),
                        .foregroundColor: NSColor.labelColor
                    ]
                    sectionHeader.attributedTitle = NSAttributedString(string: "Running Containers of \(server.config.hostname)", attributes: headerAttributes)
                    menu.addItem(sectionHeader)
                    
                    let noRunningItem = NSMenuItem(title: "No running containers", action: nil, keyEquivalent: "")
                    noRunningItem.isEnabled = false
                    let noRunningAttributes: [NSAttributedString.Key: Any] = [
                        .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
                        .foregroundColor: NSColor.secondaryLabelColor
                    ]
                    noRunningItem.attributedTitle = NSAttributedString(string: "No running containers", attributes: noRunningAttributes)
                    menu.addItem(noRunningItem)
                }
                
                // Add dead containers section if enabled in advanced settings
                if advancedSettings.showInactiveDockerContainers && !deadContainers.isEmpty {
                    // Add section header for dead containers
                    let deadSectionHeader = NSMenuItem(title: "Dead Containers of \(server.config.hostname)", action: nil, keyEquivalent: "")
                    deadSectionHeader.isEnabled = false
                    let deadHeaderAttributes: [NSAttributedString.Key: Any] = [
                        .font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize),
                        .foregroundColor: NSColor.systemRed
                    ]
                    deadSectionHeader.attributedTitle = NSAttributedString(string: "Dead Containers of \(server.config.hostname)", attributes: deadHeaderAttributes)
                    menu.addItem(deadSectionHeader)
                    
                    // Group dead containers 2 per line with separator
                    for i in stride(from: 0, to: deadContainers.count, by: 2) {
                        var containerPairs: [String] = []
                        var containerData: [[String: Any]] = []
                        
                        // First dead container
                        let container1 = deadContainers[i]
                        containerPairs.append(container1.name)
                        containerData.append(["server": server, "container": container1])
                        
                        // Second dead container if exists
                        if i + 1 < deadContainers.count {
                            let container2 = deadContainers[i + 1]
                            containerPairs.append(container2.name)
                            containerData.append(["server": server, "container": container2])
                        }
                        
                        // Create combined display text with separator
                        let combinedText = containerPairs.joined(separator: " • ")
                        
                        let deadContainerItem = NSMenuItem(title: combinedText, action: #selector(handleDeadContainerAction(_:)), keyEquivalent: "")
                        deadContainerItem.target = self
                        // Store container data for action handling
                        deadContainerItem.representedObject = containerData
                        deadContainerItem.toolTip = "Click to start the selected Docker container (confirmation dialog will appear)"
                        deadContainerItem.isEnabled = true
                        let deadContainerAttributes: [NSAttributedString.Key: Any] = [
                            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
                            .foregroundColor: NSColor.systemRed
                        ]
                        deadContainerItem.attributedTitle = NSAttributedString(string: combinedText, attributes: deadContainerAttributes)
                        menu.addItem(deadContainerItem)
                    }
                }
            } else {
                // Add section header with server hostname
                let sectionHeader = NSMenuItem(title: "Running Containers of \(server.config.hostname)", action: nil, keyEquivalent: "")
                sectionHeader.isEnabled = false
                let headerAttributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize),
                    .foregroundColor: NSColor.labelColor
                ]
                sectionHeader.attributedTitle = NSAttributedString(string: "Running Containers of \(server.config.hostname)", attributes: headerAttributes)
                menu.addItem(sectionHeader)
                
                let noDockerItem = NSMenuItem(title: "No containers", action: nil, keyEquivalent: "")
                noDockerItem.isEnabled = false
                let noDockerAttributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
                    .foregroundColor: NSColor.secondaryLabelColor
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
                    .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
                    .foregroundColor: NSColor.systemRed
                ]
                errorItem.attributedTitle = NSAttributedString(string: "Error: \(error)", attributes: errorAttributes)
                menu.addItem(errorItem)
            }
        }
    }
    
    @objc func handleServerInfoClick(_ sender: NSMenuItem) {
        guard let representedData = sender.representedObject as? [String: Any],
              let serverInfo = representedData["fullServerInfo"] as? String,
              let serverData = representedData["serverData"] as? ServerData else {
            return
        }
        
        // Show dialog with options
        let alert = NSAlert()
        alert.messageText = "Server Action"
        alert.informativeText = "What would you like to do with server '\(serverData.config.hostname)'?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Copy Server Data")
        alert.addButton(withTitle: "Restart Server")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            // Copy server data
            copyServerInfo(serverInfo)
        case .alertSecondButtonReturn:
            // Show restart confirmation
            showRestartConfirmation(for: serverData)
        default:
            // Cancel - do nothing
            break
        }
    }
    
    private func showRestartConfirmation(for serverData: ServerData) {
        let alert = NSAlert()
        alert.messageText = "Restart Server"
        alert.informativeText = "Are you sure you want to restart server '\(serverData.config.hostname)'?\n\nThis will reboot the entire server and may cause temporary downtime."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Restart Server")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            performServerRestart(serverData: serverData)
        }
    }
    
    
    private func copyServerInfo(_ serverInfo: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(serverInfo, forType: .string)
        
        // Show notification that whole server data was copied
        showCopiedNotification(text: "Whole server data copied")
    }
    
    private func performServerRestart(serverData: ServerData) {
        // Perform restart in background
        DispatchQueue.global(qos: .userInitiated).async {
            let sshClient = SSHClient()
            do {
                try sshClient.connect(to: serverData.config)
                let success = try sshClient.restartServer()
                sshClient.disconnect()
                
                DispatchQueue.main.async {
                    self.showServerRestartNotification(hostname: serverData.config.hostname, success: success)
                }
            } catch {
                DispatchQueue.main.async {
                    self.showServerRestartNotification(hostname: serverData.config.hostname, success: false, error: error.localizedDescription)
                }
            }
        }
    }
    
    private func showServerRestartNotification(hostname: String, success: Bool, error: String? = nil) {
        // Check if we're running in a proper app bundle context
        guard Bundle.main.bundleIdentifier != nil else {
            let message = success ? "🔄 Server '\(hostname)' restart initiated" : "❌ Failed to restart server '\(hostname)'"
            print(message)
            if let error = error {
                print("Error: \(error)")
            }
            return
        }
        
        // Check notification permissions first
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                let message = success ? "🔄 Server '\(hostname)' restart initiated" : "❌ Failed to restart server '\(hostname)'"
                print(message)
                return
            }
            
            let content = UNMutableNotificationContent()
            content.title = success ? "Server Restart Initiated" : "Server Restart Failed"
            if success {
                content.body = "Server '\(hostname)' is restarting. It may be temporarily unavailable."
            } else {
                content.body = "Failed to restart server '\(hostname)'"
                if let error = error {
                    content.body += ": \(error)"
                }
            }
            content.sound = nil // Silent notification
            
            let request = UNNotificationRequest(identifier: "server-restart-notification", content: content, trigger: nil)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Failed to show server restart notification: \(error)")
                } else {
                    let message = success ? "🔄 Server '\(hostname)' restart initiated" : "❌ Failed to restart server '\(hostname)'"
                    print(message)
                }
            }
        }
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
    
    @objc private func copyHealthInfo(_ sender: NSMenuItem) {
        guard let healthInfo = sender.representedObject as? String else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(healthInfo, forType: .string)
        
        // Show notification that health info was copied
        showCopiedNotification(text: healthInfo)
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
        // Simple dot animation instead of Unicode spinner
        let dotCount = (animationFrame % 4) + 1
        let dots = String(repeating: ".", count: dotCount)
        
        // Create animated icon text
        let animatedIcon = createAnimatedIcon(with: dots)
        statusItem.button?.image = animatedIcon
        
        animationFrame += 1
    }
    
    private func createAnimatedIcon(with text: String) -> NSImage {
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size)
        
        image.lockFocus()
        defer { image.unlockFocus() }
        
        // Clear background
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Draw text
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.labelColor
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
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
    
    @objc private func handleContainerAction(_ sender: NSMenuItem) {
        guard let containerDataArray = sender.representedObject as? [[String: Any]] else {
            print("Failed to get container action data")
            return
        }
        
        // If there are multiple containers, show a selection dialog
        if containerDataArray.count > 1 {
            let alert = NSAlert()
            alert.messageText = "Select Container"
            alert.informativeText = "Which container would you like to restart?"
            alert.alertStyle = .informational
            
            // Add buttons for each container
            for containerData in containerDataArray {
                if let container = containerData["container"] as? DockerContainer {
                    alert.addButton(withTitle: container.name)
                }
            }
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response.rawValue >= NSApplication.ModalResponse.alertFirstButtonReturn.rawValue &&
               response.rawValue < NSApplication.ModalResponse.alertFirstButtonReturn.rawValue + containerDataArray.count {
                let selectedIndex = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
                let selectedData = containerDataArray[selectedIndex]
                performContainerRestart(with: selectedData)
            }
        } else if let containerData = containerDataArray.first {
            // Single container, restart directly
            performContainerRestart(with: containerData)
        }
    }
    
    private func performContainerRestart(with containerData: [String: Any]) {
        guard let server = containerData["server"] as? ServerData,
              let container = containerData["container"] as? DockerContainer else {
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
    
    @objc private func handleDeadContainerAction(_ sender: NSMenuItem) {
        guard let containerDataArray = sender.representedObject as? [[String: Any]] else {
            print("Failed to get dead container action data")
            return
        }
        
        // If there are multiple containers, show a selection dialog
        if containerDataArray.count > 1 {
            let alert = NSAlert()
            alert.messageText = "Select Container"
            alert.informativeText = "Which container would you like to start?"
            alert.alertStyle = .informational
            
            // Add buttons for each container
            for containerData in containerDataArray {
                if let container = containerData["container"] as? DockerContainer {
                    alert.addButton(withTitle: container.name)
                }
            }
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response.rawValue >= NSApplication.ModalResponse.alertFirstButtonReturn.rawValue &&
               response.rawValue < NSApplication.ModalResponse.alertFirstButtonReturn.rawValue + containerDataArray.count {
                let selectedIndex = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
                let selectedData = containerDataArray[selectedIndex]
                performContainerStart(with: selectedData)
            }
        } else if let containerData = containerDataArray.first {
            // Single container, start directly
            performContainerStart(with: containerData)
        }
    }
    
    private func performContainerStart(with containerData: [String: Any]) {
        guard let server = containerData["server"] as? ServerData,
              let container = containerData["container"] as? DockerContainer else {
            print("Failed to get container start data")
            return
        }
        
        // Show confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Start Container"
        alert.informativeText = "Are you sure you want to start container '\(container.name)'?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Perform start in background
            DispatchQueue.global(qos: .userInitiated).async {
                let sshClient = SSHClient()
                do {
                    try sshClient.connect(to: server.config)
                    let success = try sshClient.startContainer(containerId: container.id)
                    sshClient.disconnect()
                    
                    DispatchQueue.main.async {
                        if success {
                            self.showStartNotification(containerName: container.name, success: true)
                        } else {
                            self.showStartNotification(containerName: container.name, success: false)
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.showStartNotification(containerName: container.name, success: false, error: error.localizedDescription)
                    }
                }
            }
        }
    }
    
    private func showStartNotification(containerName: String, success: Bool, error: String? = nil) {
        // Check if we're running in a proper app bundle context
        guard Bundle.main.bundleIdentifier != nil else {
            let message = success ? "✅ Container '\(containerName)' started successfully" : "❌ Failed to start container '\(containerName)'"
            print(message)
            if let error = error {
                print("Error: \(error)")
            }
            return
        }
        
        // Check notification permissions first
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                let message = success ? "✅ Container '\(containerName)' started successfully" : "❌ Failed to start container '\(containerName)'"
                print(message)
                return
            }
            
            let content = UNMutableNotificationContent()
            content.title = success ? "Container Started" : "Start Failed"
            if success {
                content.body = "Container '\(containerName)' has been started successfully"
            } else {
                content.body = "Failed to start container '\(containerName)'"
                if let error = error {
                    content.body += ": \(error)"
                }
            }
            content.sound = nil // Silent notification
            
            let request = UNNotificationRequest(identifier: "start-notification", content: content, trigger: nil)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Failed to show start notification: \(error)")
                } else {
                    let message = success ? "✅ Container '\(containerName)' started successfully" : "❌ Failed to start container '\(containerName)'"
                    print(message)
                }
            }
        }
    }
    
}

// MARK: - NSMenuDelegate
extension MenuBarController: NSMenuDelegate {
    func menuDidClose(_ menu: NSMenu) {
        // Menu closed
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        // Menu will open
    }
}
