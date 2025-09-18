import Cocoa

class SimpleConfigWindow: NSWindowController {
    private var serverListView: NSTableView!
    private var servers: [ServerConfig] = []
    private let serverManager: ServerManager
    
    private var addServerWindow: SimpleAddServerWindow?
    private var editServerWindow: SimpleEditServerWindow?

    init(window: NSWindow?, serverManager: ServerManager) {
        self.serverManager = serverManager
        super.init(window: window)
        setupWindow()
        loadServers()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    convenience init(serverManager: ServerManager) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        self.init(window: window, serverManager: serverManager)
    }
    
    private func setupWindow() {
        guard let window = window else { return }
        
        window.title = "Server Configuration"
        window.center()
        
        let contentView = NSView()
        window.contentView = contentView
        
        serverListView = NSTableView()
        
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
        
        serverListView.addTableColumn(nameColumn)
        serverListView.addTableColumn(hostColumn)
        serverListView.addTableColumn(userColumn)
        serverListView.addTableColumn(authColumn)
        serverListView.addTableColumn(statusColumn)
        
        serverListView.dataSource = self
        serverListView.delegate = self
        serverListView.columnAutoresizingStyle = .noColumnAutoresizing
        
        let scrollView = NSScrollView()
        scrollView.documentView = serverListView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(scrollView)
        
        let addButton = NSButton(title: "Add Server", target: self, action: #selector(addButtonClicked))
        addButton.bezelStyle = .rounded
        
        let removeButton = NSButton(title: "Remove", target: self, action: #selector(removeButtonClicked))
        removeButton.bezelStyle = .rounded
        
        let editButton = NSButton(title: "Edit", target: self, action: #selector(editButtonClicked))
        editButton.bezelStyle = .rounded
        
        let changeStatusButton = NSButton(title: "Toggle Status", target: self, action: #selector(changeStatusButtonClicked))
        changeStatusButton.bezelStyle = .rounded
        
        let buttons = [addButton, removeButton, editButton, changeStatusButton]
        buttons.forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: addButton.topAnchor, constant: -20),
            
            addButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            addButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            removeButton.leadingAnchor.constraint(equalTo: addButton.trailingAnchor, constant: 10),
            removeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            editButton.leadingAnchor.constraint(equalTo: removeButton.trailingAnchor, constant: 10),
            editButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            changeStatusButton.leadingAnchor.constraint(equalTo: editButton.trailingAnchor, constant: 10),
            changeStatusButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func loadServers() {
        servers = serverManager.getAllServers()
        updateColumnWidths()
        serverListView?.reloadData()
        print("🔄 Loaded \(servers.count) servers for display")
    }
    
    private func updateColumnWidths() {
        guard !servers.isEmpty else { return }
        
        // Calculate optimal widths for each column
        let nameWidth = calculateOptimalWidth(for: "name", minWidth: 100)
        let hostWidth = calculateOptimalWidth(for: "host", minWidth: 120)
        let userWidth = calculateOptimalWidth(for: "user", minWidth: 80)
        let authWidth = calculateOptimalWidth(for: "auth", minWidth: 90)
        let statusWidth = calculateOptimalWidth(for: "status", minWidth: 70)
        
        // Update column widths
        if let nameColumn = serverListView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier("name")) {
            nameColumn.width = nameWidth
        }
        if let hostColumn = serverListView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier("host")) {
            hostColumn.width = hostWidth
        }
        if let userColumn = serverListView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier("user")) {
            userColumn.width = userWidth
        }
        if let authColumn = serverListView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier("auth")) {
            authColumn.width = authWidth
        }
        if let statusColumn = serverListView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier("status")) {
            statusColumn.width = statusWidth
        }
    }
    
    private func calculateOptimalWidth(for columnIdentifier: String, minWidth: CGFloat) -> CGFloat {
        var maxWidth: CGFloat = minWidth
        let padding: CGFloat = 20 // Base padding
        let extraPadding: CGFloat = 4 // Additional padding per character for readability
        
        // Check header width first
        let headerWidth = getTextWidth(getColumnTitle(for: columnIdentifier)) + padding
        maxWidth = max(maxWidth, headerWidth)
        
        // Check content width
        for server in servers {
            let content = getColumnContent(for: columnIdentifier, server: server)
            let contentWidth = getTextWidth(content) + padding + (CGFloat(content.count) * extraPadding / 10)
            maxWidth = max(maxWidth, contentWidth)
        }
        
        return maxWidth
    }
    
    private func getColumnTitle(for identifier: String) -> String {
        switch identifier {
        case "name": return "Server Name"
        case "host": return "Hostname"
        case "user": return "Username"
        case "auth": return "Auth Method"
        case "status": return "Status"
        default: return ""
        }
    }
    
    private func getColumnContent(for identifier: String, server: ServerConfig) -> String {
        switch identifier {
        case "name": return server.name
        case "host": return server.hostname
        case "user": return server.username
        case "auth": return server.authenticationMethod.displayName
        case "status": return server.isEnabled ? "Enabled" : "Disabled"
        default: return ""
        }
    }
    
    private func getTextWidth(_ text: String) -> CGFloat {
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let attributes = [NSAttributedString.Key.font: font]
        let size = text.size(withAttributes: attributes)
        return size.width
    }
    
    @objc private func addButtonClicked() {
        print("🔧 Add Server button clicked in config window")
        
        // Pass the shared manager to the Add Server window
        addServerWindow = SimpleAddServerWindow(serverManager: self.serverManager)
        addServerWindow?.onServerAdded = { [weak self] in
            print("📡 Server added callback received in config window")
            self?.loadServers()
            
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.restartMonitoring()
            }
            self?.addServerWindow = nil
        }
        addServerWindow?.onWindowClosed = { [weak self] in
            print("📡 Add server window closed callback received in config window")
            self?.addServerWindow = nil
        }
        addServerWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func removeButtonClicked() {
        let selectedRow = serverListView.selectedRow
        guard selectedRow >= 0 && selectedRow < servers.count else {
            showAlert("Error", "Please select a server to remove")
            return
        }
        
        let server = servers[selectedRow]
        
        let alert = NSAlert()
        alert.messageText = "Remove Server"
        alert.informativeText = "Are you sure you want to remove '\(server.name)'?"
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            if serverManager.removeServer(withID: server.id) {
                print("✅ Server '\(server.name)' removed successfully")
                loadServers()
                
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.restartMonitoring()
                }
            } else {
                showAlert("Error", "Failed to remove server")
            }
        }
    }
    
    @objc private func editButtonClicked() {
        let selectedRow = serverListView.selectedRow
        guard selectedRow >= 0 && selectedRow < servers.count else {
            showAlert("Error", "Please select a server to edit")
            return
        }
        
        // Prevent multiple edit windows
        if editServerWindow != nil {
            showAlert("Error", "An edit window is already open. Please close it before opening another.")
            return
        }
        
        let server = servers[selectedRow]
        
        print("🔧 Edit Server button clicked for server: \(server.name)")
        
        // Create and show the edit server window
        editServerWindow = SimpleEditServerWindow(serverManager: self.serverManager, serverToEdit: server)
        editServerWindow?.onServerUpdated = { [weak self] in
            print("📡 Server updated callback received in config window")
            self?.loadServers()
            
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.restartMonitoring()
            }
            self?.editServerWindow = nil
        }
        editServerWindow?.onWindowClosed = { [weak self] in
            print("📡 Edit window closed callback received in config window")
            self?.editServerWindow = nil
        }
        editServerWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func changeStatusButtonClicked() {
        let selectedRow = serverListView.selectedRow
        guard selectedRow >= 0 && selectedRow < servers.count else {
            showAlert("Error", "Please select a server to change status")
            return
        }
        
        let server = servers[selectedRow]
        let currentStatus = server.isEnabled ? "enabled" : "disabled"
        let newStatus = server.isEnabled ? "disabled" : "enabled"
        
        let alert = NSAlert()
        alert.messageText = "Change Server Status"
        alert.informativeText = "Server '\(server.name)' is currently \(currentStatus). Do you want to change it to \(newStatus)?"
        alert.addButton(withTitle: "Change Status")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            if serverManager.toggleServerEnabled(withID: server.id) {
                print("✅ Server '\(server.name)' status changed to \(newStatus)")
                loadServers()
                
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.restartMonitoring()
                }
            } else {
                showAlert("Error", "Failed to change server status")
            }
        }
    }
    
    private func showAlert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}

// MARK: - Table View Data Source & Delegate
extension SimpleConfigWindow: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return servers.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < servers.count else { return nil }
        
        let server = servers[row]
        let cellView = NSTableCellView()
        let textField = NSTextField()
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.isEditable = false
        
        switch tableColumn?.identifier.rawValue {
        case "name":
            textField.stringValue = server.name
        case "host":
            textField.stringValue = server.hostname
        case "user":
            textField.stringValue = server.username
        case "auth":
            textField.stringValue = server.authenticationMethod.displayName
            // Color code authentication methods
            switch server.authenticationMethod {
            case .sshKey:
                textField.textColor = .systemBlue
            case .password:
                textField.textColor = .systemOrange
            case .none:
                textField.textColor = .systemRed
            }
        case "status":
            textField.stringValue = server.isEnabled ? "Enabled" : "Disabled"
            textField.textColor = server.isEnabled ? .systemGreen : .systemRed
        default:
            textField.stringValue = ""
        }
        
        cellView.addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 5),
            textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -5),
            textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
        ])
        
        return cellView
    }
}
