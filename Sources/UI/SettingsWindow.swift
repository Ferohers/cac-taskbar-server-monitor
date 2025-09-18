import Cocoa

class SettingsWindow: NSWindowController {
    private let serverManager: ServerManager
    private let settingsManager = SettingsManager.shared
    
    // UI Components
    private var tabView: NSTabView!
    private var sidebarTableView: NSTableView!
    
    // Tab content views
    private var serversContentView: NSView!
    private var notificationsContentView: NSScrollView!
    private var advancedContentView: NSScrollView!
    
    // Servers tab components (reuse existing functionality)
    private var serverTableView: NSTableView!
    private var servers: [ServerConfig] = []
    
    // Notifications tab components
    private var notificationsView: NotificationsSettingsView!
    
    // Advanced settings
    private var showInactiveContainersCheckbox: NSButton!
    
    // Child windows
    private var addServerWindow: SimpleAddServerWindow?
    private var editServerWindow: SimpleEditServerWindow?
    
    enum SettingsTab: Int, CaseIterable {
        case servers = 0
        case notifications = 1
        case advanced = 2
        
        var title: String {
            switch self {
            case .servers: return "Configure Servers"
            case .notifications: return "Notifications"
            case .advanced: return "Advanced"
            }
        }
        
        var icon: String {
            switch self {
            case .servers: return "server.rack"
            case .notifications: return "bell.badge"
            case .advanced: return "gearshape"
            }
        }
    }
    
    init(serverManager: ServerManager) {
        self.serverManager = serverManager
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: window)
        setupWindow()
        // Load data after UI is fully setup
        DispatchQueue.main.async { [weak self] in
            self?.loadData()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupWindow() {
        guard let window = window else { return }
        
        window.title = "Settings"
        window.center()
        window.minSize = NSSize(width: 700, height: 500)
        
        let contentView = NSView()
        window.contentView = contentView
        
        setupSidebar(in: contentView)
        setupTabView(in: contentView)
        setupConstraints(in: contentView)
    }
    
    private func setupSidebar(in contentView: NSView) {
        // Create sidebar container
        let sidebarContainer = NSView()
        sidebarContainer.translatesAutoresizingMaskIntoConstraints = false
        sidebarContainer.wantsLayer = true
        sidebarContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        contentView.addSubview(sidebarContainer)
        
        // Create sidebar table view
        sidebarTableView = NSTableView()
        sidebarTableView.headerView = nil
        sidebarTableView.intercellSpacing = NSSize(width: 0, height: 2)
        if #available(macOS 12.0, *) {
            sidebarTableView.style = .sourceList
        } else {
            sidebarTableView.selectionHighlightStyle = .sourceList
        }
        sidebarTableView.backgroundColor = .clear
        sidebarTableView.gridStyleMask = []
        
        // Create single column
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SidebarColumn"))
        column.width = 200
        sidebarTableView.addTableColumn(column)
        
        sidebarTableView.dataSource = self
        sidebarTableView.delegate = self
        
        let sidebarScrollView = NSScrollView()
        sidebarScrollView.documentView = sidebarTableView
        sidebarScrollView.hasVerticalScroller = true
        sidebarScrollView.hasHorizontalScroller = false
        sidebarScrollView.autohidesScrollers = true
        sidebarScrollView.translatesAutoresizingMaskIntoConstraints = false
        sidebarScrollView.borderType = .noBorder
        sidebarContainer.addSubview(sidebarScrollView)
        
        // Select first tab by default
        sidebarTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        
        NSLayoutConstraint.activate([
            sidebarContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            sidebarContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            sidebarContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            sidebarContainer.widthAnchor.constraint(equalToConstant: 200),
            
            sidebarScrollView.leadingAnchor.constraint(equalTo: sidebarContainer.leadingAnchor),
            sidebarScrollView.trailingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor),
            sidebarScrollView.topAnchor.constraint(equalTo: sidebarContainer.topAnchor),
            sidebarScrollView.bottomAnchor.constraint(equalTo: sidebarContainer.bottomAnchor)
        ])
    }
    
    private func setupTabView(in contentView: NSView) {
        // Create tab view (hidden, we'll use our custom sidebar)
        tabView = NSTabView()
        tabView.tabViewType = .noTabsNoBorder
        tabView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tabView)
        
        // Setup each tab
        setupServersTab()
        setupNotificationsTab()
        setupAdvancedTab()
    }
    
    private func setupConstraints(in contentView: NSView) {
        NSLayoutConstraint.activate([
            tabView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 200),
            tabView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tabView.topAnchor.constraint(equalTo: contentView.topAnchor),
            tabView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    // MARK: - Servers Tab Setup
    
    private func setupServersTab() {
        let tabViewItem = NSTabViewItem()
        tabViewItem.label = "Servers"
        
        serversContentView = NSView()
        tabViewItem.view = serversContentView
        
        setupServersContent()
        
        tabView.addTabViewItem(tabViewItem)
    }
    
    private func setupServersContent() {
        // Reuse the server table functionality from SimpleConfigWindow
        serverTableView = NSTableView()
        
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Server Name"
        nameColumn.minWidth = 100
        nameColumn.resizingMask = .userResizingMask
        
        let hostColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("host"))
        hostColumn.title = "Hostname"
        hostColumn.minWidth = 120
        hostColumn.resizingMask = .userResizingMask
        
        let userColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("user"))
        userColumn.title = "Username"
        userColumn.minWidth = 80
        userColumn.resizingMask = .userResizingMask
        
        let authColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("auth"))
        authColumn.title = "Auth Method"
        authColumn.minWidth = 90
        authColumn.resizingMask = .userResizingMask
        
        let statusColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("status"))
        statusColumn.title = "Status"
        statusColumn.minWidth = 70
        statusColumn.resizingMask = .userResizingMask
        
        serverTableView.addTableColumn(nameColumn)
        serverTableView.addTableColumn(hostColumn)
        serverTableView.addTableColumn(userColumn)
        serverTableView.addTableColumn(authColumn)
        serverTableView.addTableColumn(statusColumn)
        
        serverTableView.dataSource = self
        serverTableView.delegate = self
        serverTableView.columnAutoresizingStyle = .noColumnAutoresizing
        
        let scrollView = NSScrollView()
        scrollView.documentView = serverTableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        serversContentView.addSubview(scrollView)
        
        // Add buttons
        let addButton = NSButton(title: "Add Server", target: self, action: #selector(addServer))
        addButton.bezelStyle = .rounded
        addButton.translatesAutoresizingMaskIntoConstraints = false
        
        let removeButton = NSButton(title: "Remove", target: self, action: #selector(removeServer))
        removeButton.bezelStyle = .rounded
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        
        let editButton = NSButton(title: "Edit", target: self, action: #selector(editServer))
        editButton.bezelStyle = .rounded
        editButton.translatesAutoresizingMaskIntoConstraints = false
        
        let toggleButton = NSButton(title: "Toggle Status", target: self, action: #selector(toggleServerStatus))
        toggleButton.bezelStyle = .rounded
        toggleButton.translatesAutoresizingMaskIntoConstraints = false
        
        serversContentView.addSubview(addButton)
        serversContentView.addSubview(removeButton)
        serversContentView.addSubview(editButton)
        serversContentView.addSubview(toggleButton)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: serversContentView.topAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: serversContentView.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: serversContentView.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: addButton.topAnchor, constant: -20),
            
            addButton.leadingAnchor.constraint(equalTo: serversContentView.leadingAnchor, constant: 20),
            addButton.bottomAnchor.constraint(equalTo: serversContentView.bottomAnchor, constant: -20),
            
            removeButton.leadingAnchor.constraint(equalTo: addButton.trailingAnchor, constant: 10),
            removeButton.bottomAnchor.constraint(equalTo: serversContentView.bottomAnchor, constant: -20),
            
            editButton.leadingAnchor.constraint(equalTo: removeButton.trailingAnchor, constant: 10),
            editButton.bottomAnchor.constraint(equalTo: serversContentView.bottomAnchor, constant: -20),
            
            toggleButton.leadingAnchor.constraint(equalTo: editButton.trailingAnchor, constant: 10),
            toggleButton.bottomAnchor.constraint(equalTo: serversContentView.bottomAnchor, constant: -20)
        ])
    }
    
    // MARK: - Notifications Tab Setup
    
    private func setupNotificationsTab() {
        let tabViewItem = NSTabViewItem()
        tabViewItem.label = "Notifications"
        
        // Create scroll view for notifications content
        notificationsContentView = NSScrollView()
        notificationsContentView.hasVerticalScroller = true
        notificationsContentView.hasHorizontalScroller = false
        notificationsContentView.autohidesScrollers = true
        notificationsContentView.borderType = .noBorder
        
        tabViewItem.view = notificationsContentView
        
        setupNotificationsContent()
        
        tabView.addTabViewItem(tabViewItem)
    }
    
    private func setupNotificationsContent() {
        // Create the notifications settings view
        notificationsView = NotificationsSettingsView()
        notificationsView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create a document view for the scroll view
        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(notificationsView)
        
        // Set the document view
        notificationsContentView.documentView = documentView
        
        NSLayoutConstraint.activate([
            notificationsView.topAnchor.constraint(equalTo: documentView.topAnchor),
            notificationsView.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            notificationsView.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            notificationsView.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
            
            // Set document view width to match scroll view
            documentView.widthAnchor.constraint(equalTo: notificationsContentView.widthAnchor),
            
            // Allow document view height to expand as needed
            documentView.heightAnchor.constraint(greaterThanOrEqualTo: notificationsContentView.heightAnchor, constant: 1)
        ])
    }
    
    // MARK: - Advanced Tab Setup
    
    private func setupAdvancedTab() {
        let tabViewItem = NSTabViewItem()
        tabViewItem.label = "Advanced"
        
        // Create scroll view for advanced content
        advancedContentView = NSScrollView()
        advancedContentView.hasVerticalScroller = true
        advancedContentView.hasHorizontalScroller = false
        advancedContentView.autohidesScrollers = true
        advancedContentView.borderType = .noBorder
        
        tabViewItem.view = advancedContentView
        
        setupAdvancedContent()
        
        tabView.addTabViewItem(tabViewItem)
    }
    
    private func setupAdvancedContent() {
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 15
        stackView.alignment = .centerX  // Center the content
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create a document view for the scroll view
        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(stackView)
        
        // Set the document view
        advancedContentView.documentView = documentView
        
        // Docker Containers Section
        let dockerSectionLabel = NSTextField(labelWithString: "Docker Containers")
        dockerSectionLabel.font = NSFont.boldSystemFont(ofSize: 16)
        dockerSectionLabel.alignment = .center
        stackView.addArrangedSubview(dockerSectionLabel)
        
        showInactiveContainersCheckbox = NSButton(checkboxWithTitle: "Show inactive docker containers", target: self, action: #selector(toggleInactiveContainers))
        showInactiveContainersCheckbox.toolTip = "When enabled, dead/stopped containers will be shown under a separate 'Dead Containers' section in the menu"
        stackView.addArrangedSubview(showInactiveContainersCheckbox)
        
        let explanationLabel = NSTextField(wrappingLabelWithString: "When this option is enabled, inactive (dead/stopped) Docker containers will be displayed under a separate 'Dead Containers' section in the taskbar menu. This allows you to see all containers on your servers, not just the running ones.")
        explanationLabel.textColor = .secondaryLabelColor
        explanationLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        explanationLabel.alignment = .center
        explanationLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(explanationLabel)
        
        NSLayoutConstraint.activate([
            // Center the stack view vertically and horizontally
            stackView.centerXAnchor.constraint(equalTo: documentView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: documentView.centerYAnchor),
            stackView.topAnchor.constraint(greaterThanOrEqualTo: documentView.topAnchor, constant: 40),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: documentView.bottomAnchor, constant: -40),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: documentView.leadingAnchor, constant: 40),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: documentView.trailingAnchor, constant: -40),
            
            explanationLabel.widthAnchor.constraint(equalToConstant: 400),
            
            // Set document view width to match scroll view
            documentView.widthAnchor.constraint(equalTo: advancedContentView.widthAnchor),
            
            // Allow document view height to expand as needed
            documentView.heightAnchor.constraint(greaterThanOrEqualTo: advancedContentView.heightAnchor, constant: 1)
        ])
        
        // Load current settings
        let advancedSettings = settingsManager.getAdvancedSettings()
        showInactiveContainersCheckbox.state = advancedSettings.showInactiveDockerContainers ? .on : .off
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        loadServers()
        loadNotificationSettings()
    }
    
    private func loadServers() {
        servers = serverManager.getAllServers()
        serverTableView?.reloadData()
    }
    
    private func loadNotificationSettings() {
        // Load data into the notifications view
        guard let notificationsView = notificationsView else { return }
        notificationsView.loadData(servers: servers)
    }
    
    // MARK: - Action Methods
    
    @objc private func addServer() {
        addServerWindow = SimpleAddServerWindow(serverManager: serverManager)
        addServerWindow?.onServerAdded = { [weak self] in
            self?.loadData()
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.restartMonitoring()
            }
            self?.addServerWindow = nil
        }
        addServerWindow?.onWindowClosed = { [weak self] in
            self?.addServerWindow = nil
        }
        addServerWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func removeServer() {
        let selectedRow = serverTableView.selectedRow
        guard selectedRow >= 0 && selectedRow < servers.count else {
            showAlert("Error", "Please select a server to remove")
            return
        }
        
        let server = servers[selectedRow]
        
        let alert = NSAlert()
        alert.messageText = "Remove Server"
        alert.informativeText = "Are you sure you want to remove '\(server.name)'? This will also remove all notification settings for this server."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            if serverManager.removeServer(withID: server.id) {
                settingsManager.removeNotificationSettings(for: server.id)
                loadData()
                
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.restartMonitoring()
                }
            } else {
                showAlert("Error", "Failed to remove server")
            }
        }
    }
    
    @objc private func editServer() {
        let selectedRow = serverTableView.selectedRow
        guard selectedRow >= 0 && selectedRow < servers.count else {
            showAlert("Error", "Please select a server to edit")
            return
        }
        
        if editServerWindow != nil {
            showAlert("Error", "An edit window is already open. Please close it before opening another.")
            return
        }
        
        let server = servers[selectedRow]
        
        editServerWindow = SimpleEditServerWindow(serverManager: serverManager, serverToEdit: server)
        editServerWindow?.onServerUpdated = { [weak self] in
            self?.loadData()
            
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.restartMonitoring()
            }
            self?.editServerWindow = nil
        }
        editServerWindow?.onWindowClosed = { [weak self] in
            self?.editServerWindow = nil
        }
        editServerWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func toggleServerStatus() {
        let selectedRow = serverTableView.selectedRow
        guard selectedRow >= 0 && selectedRow < servers.count else {
            showAlert("Error", "Please select a server to change status")
            return
        }
        
        let server = servers[selectedRow]
        if serverManager.toggleServerEnabled(withID: server.id) {
            loadData()
            
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.restartMonitoring()
            }
        } else {
            showAlert("Error", "Failed to change server status")
        }
    }
    
    @objc private func toggleInactiveContainers(_ sender: NSButton) {
        var advancedSettings = settingsManager.getAdvancedSettings()
        advancedSettings.showInactiveDockerContainers = sender.state == .on
        settingsManager.saveAdvancedSettings(advancedSettings)
        
        // Notify app delegate to update menu
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.restartMonitoring()
        }
    }
    
    private func showAlert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}

// MARK: - Sidebar Table View Data Source & Delegate

extension SettingsWindow: NSTableViewDataSource, NSTableViewDelegate {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == sidebarTableView {
            return SettingsTab.allCases.count
        } else if tableView == serverTableView {
            return servers.count
        }
        return 0
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView == sidebarTableView {
            let tab = SettingsTab.allCases[row]
            
            let cellView = NSTableCellView()
            
            let stackView = NSStackView()
            stackView.orientation = .horizontal
            stackView.spacing = 8
            stackView.alignment = .centerY
            stackView.translatesAutoresizingMaskIntoConstraints = false
            
            // Icon
            let iconImageView = NSImageView()
            if let image = NSImage(systemSymbolName: tab.icon, accessibilityDescription: nil) {
                iconImageView.image = image
            }
            iconImageView.translatesAutoresizingMaskIntoConstraints = false
            stackView.addArrangedSubview(iconImageView)
            
            // Label
            let label = NSTextField(labelWithString: tab.title)
            label.font = NSFont.systemFont(ofSize: 13)
            label.textColor = .labelColor
            stackView.addArrangedSubview(label)
            
            cellView.addSubview(stackView)
            
            NSLayoutConstraint.activate([
                iconImageView.widthAnchor.constraint(equalToConstant: 16),
                iconImageView.heightAnchor.constraint(equalToConstant: 16),
                
                stackView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 8),
                stackView.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -8),
                stackView.topAnchor.constraint(equalTo: cellView.topAnchor, constant: 4),
                stackView.bottomAnchor.constraint(equalTo: cellView.bottomAnchor, constant: -4)
            ])
            
            return cellView
        } else if tableView == serverTableView {
            let server = servers[row]
            let columnId = tableColumn?.identifier.rawValue ?? ""
            
            let cellView = NSTableCellView()
            let textField = NSTextField(labelWithString: "")
            textField.font = NSFont.systemFont(ofSize: 12)
            textField.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(textField)
            
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 8),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -8),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])
            
            switch columnId {
            case "name":
                textField.stringValue = server.name
            case "host":
                textField.stringValue = server.hostname
            case "user":
                textField.stringValue = server.username
            case "auth":
                textField.stringValue = server.authenticationMethod.displayName
            case "status":
                textField.stringValue = server.isEnabled ? "Enabled" : "Disabled"
                textField.textColor = server.isEnabled ? .systemGreen : .systemRed
            default:
                textField.stringValue = ""
            }
            
            return cellView
        }
        
        return nil
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if notification.object as? NSTableView == sidebarTableView {
            let selectedRow = sidebarTableView.selectedRow
            if selectedRow >= 0 && selectedRow < SettingsTab.allCases.count {
                tabView?.selectTabViewItem(at: selectedRow)
            }
        }
    }
}