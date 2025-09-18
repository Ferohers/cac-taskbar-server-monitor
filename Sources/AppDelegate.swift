import Cocoa
import Foundation
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var menuBarController: MenuBarController!
    var serverMonitor: ServerMonitor!
    var serverManager: ServerManager!
    private let powerManager = PowerManager.shared
    
    private var settingsWindow: SettingsWindow?
    private var addServerWindow: SimpleAddServerWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize power management for menu bar app
        powerManager.optimizeForMenuBarApp()
        
        setupManagers()
        setupStatusBar()
        requestNotificationPermissions()
        
        print("🚀 Duman starting...")
        print("📁 Config file location: \(serverManager.getConfigPath())")
        
        if !serverManager.hasServers() {
            print("🔧 No configuration found, showing setup window")
            showInitialSetup()
        } else {
            print("✅ Configuration found, starting monitoring")
            startMonitoring()
        }
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            if let image = NSImage.menuBarIcon() {
                button.image = image
            } else {
                button.title = "⚡"
            }
            button.toolTip = "Duman - Server Monitor"
        }
        
        menuBarController = MenuBarController(statusItem: statusItem, target: self)
    }
    
    private func setupManagers() {
        // Create the single source of truth for server data
        serverManager = ServerManager()
        serverMonitor = ServerMonitor()
        
        serverMonitor.onDataUpdate = { [weak self] servers in
            DispatchQueue.main.async {
                self?.menuBarController.updateServerData(servers)
            }
        }
    }
    
    private func startMonitoring() {
        let servers = serverManager.getAllServers()
        if !servers.isEmpty {
            print("🔍 Starting monitoring for \(servers.count) servers")
            serverMonitor.startMonitoring(servers: servers)
        } else {
            print("⚠️ No servers to monitor")
        }
    }
    
    func restartMonitoring() {
        print("🔄 Restarting monitoring...")
        serverMonitor.stopMonitoring()
        startMonitoring()
    }
    
    private func showInitialSetup() {
        print("🎯 Showing initial setup")
        showSettingsWindow()
    }
    
    // MARK: - Menu Actions
    
    @objc func showSettingsWindow() {
        print("🔧 Menu item: Show Settings Window")
        if settingsWindow == nil {
            // Inject the shared manager
            settingsWindow = SettingsWindow(serverManager: serverManager)
        }
        settingsWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func addServer() {
        print("🔧 Menu item: Add Server")
        
        // Check if add server window already exists and is visible
        if let existingWindow = addServerWindow, existingWindow.window?.isVisible == true {
            // Bring existing window to front instead of creating a new one
            existingWindow.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Create new window only if none exists or previous one was closed
        addServerWindow = SimpleAddServerWindow(serverManager: serverManager)
        addServerWindow?.onServerAdded = { [weak self] in
            self?.restartMonitoring()
            self?.addServerWindow = nil
        }
        addServerWindow?.onWindowClosed = { [weak self] in
            self?.addServerWindow = nil
        }
        addServerWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func quitApp() {
        print("🔧 Menu item: Quit App")
        serverMonitor.stopMonitoring()
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Notification Permissions
    
    private func requestNotificationPermissions() {
        // Check if we're running in a proper app bundle context
        guard Bundle.main.bundleIdentifier != nil else {
            print("📱 Skipping notification permissions - not running in app bundle context")
            return
        }
        
        // Use the new NotificationManager
        NotificationManager.shared.requestPermissions()
    }
}
