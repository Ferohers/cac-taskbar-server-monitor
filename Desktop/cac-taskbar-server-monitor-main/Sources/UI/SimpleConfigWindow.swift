import Cocoa

class SimpleConfigWindow: NSWindowController {
    private var serverListView: NSTableView!
    private var servers: [ServerConfig] = []
    private let serverRepository: ServerRepository
    
    private var addServerWindow: SimpleAddServerWindow?
    private var editServerWindow: SimpleEditServerWindow?

    init(window: NSWindow?, serverRepository: ServerRepository) {
        self.serverRepository = serverRepository
        super.init(window: window)
        setupWindow()
        loadServers()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    convenience init(serverRepository: ServerRepository) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        self.init(window: window, serverRepository: serverRepository)
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
        nameColumn.width = 140
        
        let hostColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("host"))
        hostColumn.title = "Hostname"
        hostColumn.width = 175
        
        let userColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("user"))
        userColumn.title = "Username"
        userColumn.width = 100
        
        let statusColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("status"))
        statusColumn.title = "Status"
        statusColumn.width = 100
        
        serverListView.addTableColumn(nameColumn)
        serverListView.addTableColumn(hostColumn)
        serverListView.addTableColumn(userColumn)
        serverListView.addTableColumn(statusColumn)
        
        serverListView.dataSource = self
        serverListView.delegate = self
        
        let scrollView = NSScrollView()
        scrollView.documentView = serverListView
        scrollView.hasVerticalScroller = true
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
        servers = serverRepository.getAllServers()
        serverListView?.reloadData()
        print("🔄 Loaded \(servers.count) servers for display")
    }
    
    @objc private func addButtonClicked() {
        print("🔧 Add Server button clicked in config window")
        
        // Pass the shared repository to the Add Server window
        addServerWindow = SimpleAddServerWindow(serverRepository: self.serverRepository)
        addServerWindow?.onServerAdded = { [weak self] in
            print("📡 Server added callback received in config window")
            self?.loadServers()
            
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.restartMonitoring()
            }
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
            if serverRepository.removeServer(withID: server.id) {
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
        editServerWindow = SimpleEditServerWindow(serverRepository: self.serverRepository, serverToEdit: server)
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
            if serverRepository.toggleServerEnabled(withID: server.id) {
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
