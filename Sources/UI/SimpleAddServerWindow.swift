import Cocoa

class SimpleAddServerWindow: NSWindowController, NSWindowDelegate {
    private var nameField: NSTextField!
    private var hostField: NSTextField!
    private var userField: NSTextField!
    private var passField: NSSecureTextField!
    private var keyField: NSTextField!
    private var portField: NSTextField!
    
    private let serverManager: ServerManager
    
    var onServerAdded: (() -> Void)?
    var onWindowClosed: (() -> Void)?
    
    init(window: NSWindow?, serverManager: ServerManager) {
        self.serverManager = serverManager
        super.init(window: window)
        setupWindow()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    convenience init(serverManager: ServerManager) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        self.init(window: window, serverManager: serverManager)
    }
    
    private func setupWindow() {
        guard let window = window else { return }
        
        window.title = "Add Server"
        window.center()
        window.delegate = self
        
        let contentView = NSView()
        window.contentView = contentView
        
        nameField = NSTextField()
        nameField.placeholderString = "Server Name"
        
        hostField = NSTextField()
        hostField.placeholderString = "Hostname or IP"
        
        userField = NSTextField()
        userField.placeholderString = "Username"
        
        passField = NSSecureTextField()
        passField.placeholderString = "Password (optional)"
        
        keyField = NSTextField()
        keyField.placeholderString = "SSH Key Path (optional)"
        
        portField = NSTextField()
        portField.stringValue = "22"
        portField.placeholderString = "Port"
        
        let browseButton = NSButton(title: "Browse...", target: self, action: #selector(browseButtonClicked))
        browseButton.bezelStyle = .rounded
        
        let addButton = NSButton(title: "Add Server", target: self, action: #selector(addButtonClicked))
        addButton.bezelStyle = .rounded
        
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelButtonClicked))
        cancelButton.bezelStyle = .rounded
        
        let allViews: [NSView] = [nameField, hostField, userField, passField, keyField, browseButton, portField, addButton, cancelButton]
        allViews.forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            nameField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            nameField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            nameField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            hostField.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 10),
            hostField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            hostField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            userField.topAnchor.constraint(equalTo: hostField.bottomAnchor, constant: 10),
            userField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            userField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            passField.topAnchor.constraint(equalTo: userField.bottomAnchor, constant: 10),
            passField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            passField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            keyField.topAnchor.constraint(equalTo: passField.bottomAnchor, constant: 10),
            keyField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            keyField.trailingAnchor.constraint(equalTo: browseButton.leadingAnchor, constant: -10),
            
            browseButton.topAnchor.constraint(equalTo: passField.bottomAnchor, constant: 10),
            browseButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            browseButton.widthAnchor.constraint(equalToConstant: 80),
            
            portField.topAnchor.constraint(equalTo: keyField.bottomAnchor, constant: 10),
            portField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            portField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            cancelButton.topAnchor.constraint(equalTo: portField.bottomAnchor, constant: 20),
            cancelButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            
            addButton.topAnchor.constraint(equalTo: portField.bottomAnchor, constant: 20),
            addButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            addButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    @objc private func addButtonClicked() {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = hostField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let user = userField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let pass = passField.stringValue.isEmpty ? nil : passField.stringValue
        let keyPath = keyField.stringValue.isEmpty ? nil : keyField.stringValue
        let port = Int(portField.stringValue) ?? 22
        
        guard !name.isEmpty, !host.isEmpty, !user.isEmpty else {
            showAlert("Error", "Please fill in Name, Hostname, and Username")
            return
        }
        
        // Validate that at least one authentication method is provided
        guard pass != nil || keyPath != nil else {
            showAlert("Error", "Please provide either a password or SSH key path for authentication")
            return
        }
        
        // Create server config without plain text credentials
        let server = ServerConfig(
            name: name,
            hostname: host,
            username: user,
            port: port
        )
        
        // Use the new method that handles keychain storage
        if serverManager.addServerWithCredentials(server, password: pass, keyPath: keyPath) {
            print("✅ Server '\(server.name)' saved successfully with credentials in keychain.")
            onServerAdded?()
            self.close()
        } else {
            print("❌ Failed to save server.")
            showAlert("Error", "Failed to save server or store credentials securely.")
        }
    }
    
    @objc private func browseButtonClicked() {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedContentTypes = [.data, .text, .item]
        openPanel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh")
        openPanel.title = "Select SSH Private Key"
        openPanel.message = "Choose your SSH private key file (usually id_rsa, id_ed25519, etc.)"
        openPanel.prompt = "Select"
        
        openPanel.begin { [weak self] response in
            if response == .OK, let url = openPanel.url {
                DispatchQueue.main.async {
                    self?.keyField.stringValue = url.path
                }
            }
        }
    }
    
    @objc private func cancelButtonClicked() {
        onWindowClosed?()
        self.close()
    }
    
    private func showAlert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        onWindowClosed?()
    }
}
