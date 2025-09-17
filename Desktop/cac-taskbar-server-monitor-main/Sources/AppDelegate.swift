import Cocoa
import Foundation
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var menuBarController: MenuBarController!
    var serverMonitor: ServerMonitor!
    var serverRepository: ServerRepository!
    var configManager: ConfigManager!
    
    private var configWindow: SimpleConfigWindow?
    private var addServerWindow: SimpleAddServerWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupManagers()
        setupStatusBar()
        requestNotificationPermissions()
        
        print("🚀 AltanMon starting...")
        print("📁 Config file location: \(configManager.getConfigPath())")
        
        if !serverRepository.hasServers() {
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
            button.toolTip = "AltanMon - Server Monitor"
        }
        
        menuBarController = MenuBarController(statusItem: statusItem, target: self)
    }
    
    private func setupManagers() {
        // Create the single source of truth for server data
        configManager = ConfigManager()
        serverRepository = ServerRepository(configManager: configManager)
        serverMonitor = ServerMonitor()
        
        serverMonitor.onDataUpdate = { [weak self] servers in
            DispatchQueue.main.async {
                self?.menuBarController.updateServerData(servers)
            }
        }
    }
    
    private func startMonitoring() {
        let servers = serverRepository.getAllServers()
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
        showConfigWindow()
    }
    
    // MARK: - Menu Actions
    
    @objc func showConfigWindow() {
        print("🔧 Menu item: Show Config Window")
        if configWindow == nil {
            // Inject the shared repository
            configWindow = SimpleConfigWindow(serverRepository: serverRepository)
        }
        configWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func addServer() {
        print("🔧 Menu item: Add Server")
        // Inject the shared repository
        addServerWindow = SimpleAddServerWindow(serverRepository: serverRepository)
        addServerWindow?.onServerAdded = { [weak self] in
            self?.restartMonitoring()
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
        
        let center = UNUserNotificationCenter.current()
        
        // First check current authorization status
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                print("📱 Current notification status: \(settings.authorizationStatus.rawValue)")
                
                switch settings.authorizationStatus {
                case .notDetermined:
                    print("🔔 Requesting notification permissions...")
                    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                        DispatchQueue.main.async {
                            if let error = error {
                                print("⚠️ Notification permission error: \(error.localizedDescription)")
                            } else if granted {
                                print("✅ Notification permissions granted")
                            } else {
                                print("❌ Notification permissions denied by user")
                            }
                        }
                    }
                case .denied:
                    print("❌ Notifications previously denied - user must enable in System Preferences")
                case .authorized, .provisional, .ephemeral:
                    print("✅ Notifications already authorized")
                @unknown default:
                    print("🤔 Unknown notification authorization status")
                }
            }
        }
    }
}
