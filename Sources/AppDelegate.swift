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
        setupMainMenu() // Call to setup the main menu
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
    
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        NSApp.mainMenu = mainMenu
        
        // Application Menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        
        appMenu.addItem(withTitle: "About Duman", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Duman", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        
        // Edit Menu
        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        
        editMenu.addItem(withTitle: "Undo", action: #selector(undo(_:)), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: #selector(redo(_:)), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Delete", action: #selector(delete(_:)), keyEquivalent: "")
        editMenu.addItem(withTitle: "Select All", action: #selector(selectAll(_:)), keyEquivalent: "a")
    }
    
    // MARK: - Standard Editing Actions (Forwarded to first responder)
    
    @objc func undo(_ sender: Any?) {
        NSApp.sendAction(#selector(undo(_:)), to: nil, from: sender)
    }
    
    @objc func redo(_ sender: Any?) {
        NSApp.sendAction(#selector(redo(_:)), to: nil, from: sender)
    }
    
    @objc func cut(_ sender: Any?) {
        NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: sender)
    }
    
    @objc func copy(_ sender: Any?) {
        NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: sender)
    }
    
    @objc func paste(_ sender: Any?) {
        NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: sender)
    }
    
    @objc func delete(_ sender: Any?) {
        NSApp.sendAction(#selector(NSText.delete(_:)), to: nil, from: sender)
    }
    
    @objc func selectAll(_ sender: Any?) {
        NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: sender)
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


