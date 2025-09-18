import Cocoa

class SimpleEditServerWindow: NSWindowController, NSWindowDelegate {
    private var nameField: NSTextField!
    private var hostField: NSTextField!
    private var userField: NSTextField!
    private var passField: NSSecureTextField!
    private var keyField: NSTextField!
    private var portField: NSTextField!
    
    private let serverManager: ServerManager
    private var serverToEdit: ServerConfig
    
    var onServerUpdated: (() -> Void)?
    var onWindowClosed: (() -> Void)?
    
    init(window: NSWindow?, serverManager: ServerManager, serverToEdit: ServerConfig) {
        self.serverManager = serverManager
        self.serverToEdit = serverToEdit
        super.init(window: window)
        setupWindow()
        populateFields()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    convenience init(serverManager: ServerManager, serverToEdit: ServerConfig) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        self.init(window: window, serverManager: serverManager, serverToEdit: serverToEdit)
    }
    
    private func setupWindow() {
        guard let window = window else { return }
        
        window.title = "Edit Server"
        window.center()
        window.delegate = self
        
        // Configure window for proper text editing
        window.makeFirstResponder(nil)
        window.acceptsMouseMovedEvents = true
        // Set delegate to handle window closing
        window.delegate = self
        
        let contentView = NSView()
        window.contentView = contentView
        
        nameField = NSTextField()
        nameField.placeholderString = "Server Name"
        configureTextField(nameField)
        
        hostField = NSTextField()
        hostField.placeholderString = "Hostname or IP"
        configureTextField(hostField)
        
        userField = NSTextField()
        userField.placeholderString = "Username"
        configureTextField(userField)
        
        passField = NSSecureTextField()
        passField.placeholderString = "Password (optional)"
        configureTextField(passField)
        
        keyField = NSTextField()
        keyField.placeholderString = "SSH Key Path (optional)"
        configureTextField(keyField)
        
        portField = NSTextField()
        portField.placeholderString = "Port"
        configureTextField(portField)
        
        let browseButton = NSButton(title: "Browse...", target: self, action: #selector(browseButtonClicked))
        browseButton.bezelStyle = .rounded
        
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveButtonClicked))
        saveButton.bezelStyle = .rounded
        
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelButtonClicked))
        cancelButton.bezelStyle = .rounded
        
        let allViews: [NSView] = [nameField, hostField, userField, passField, keyField, browseButton, portField, saveButton, cancelButton]
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
            
            saveButton.topAnchor.constraint(equalTo: portField.bottomAnchor, constant: 20),
            saveButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            saveButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func configureTextField(_ textField: NSTextField) {
        // Ensure we have a proper text field cell
        if !(textField.cell is NSTextFieldCell) {
            textField.cell = NSTextFieldCell()
        }
        
        // Configure the text field
        textField.isEditable = true
        textField.isSelectable = true
        textField.isBordered = true
        textField.isBezeled = true
        textField.bezelStyle = .roundedBezel
        textField.drawsBackground = true
        textField.backgroundColor = NSColor.textBackgroundColor
        textField.usesSingleLineMode = true
        textField.lineBreakMode = .byTruncatingTail
        textField.allowsEditingTextAttributes = false
        textField.importsGraphics = false
        textField.refusesFirstResponder = false
        
        // Configure the cell for proper text editing
        if let cell = textField.cell as? NSTextFieldCell {
            cell.isEditable = true
            cell.isSelectable = true
            cell.isScrollable = true
            cell.wraps = false
            cell.usesSingleLineMode = true
            cell.sendsActionOnEndEditing = true
        }
        
        // Enable standard editing menu items
        textField.target = nil
        textField.action = nil
    }
    
    private func populateFields() {
        nameField.stringValue = serverToEdit.name
        hostField.stringValue = serverToEdit.hostname
        userField.stringValue = serverToEdit.username
        portField.stringValue = String(serverToEdit.port)
        
        // Handle encrypted credential storage
        if serverToEdit.encryptedPassword != nil && !serverToEdit.encryptedPassword!.isEmpty {
            passField.placeholderString = "Password stored securely (leave empty to keep current)"
        }
        
        if serverToEdit.encryptedSSHKey != nil && !serverToEdit.encryptedSSHKey!.isEmpty {
            keyField.placeholderString = "SSH key stored securely (leave empty to keep current)"
        }
    }
    
    @objc private func saveButtonClicked() {
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
        
        // Create updated server config preserving encrypted credentials
        let updatedServer = ServerConfig(
            id: serverToEdit.id,
            name: name,
            hostname: host,
            username: user,
            port: port,
            isEnabled: serverToEdit.isEnabled,
            encryptedPassword: serverToEdit.encryptedPassword,
            encryptedSSHKey: serverToEdit.encryptedSSHKey
        )
        
        // Validate the updated server
        let validationErrors = serverManager.validateServer(updatedServer)
        if !validationErrors.isEmpty {
            showAlert("Validation Error", validationErrors.joined(separator: "\n"))
            return
        }
        
        // Use the new method that handles encrypted credential storage
        if serverManager.updateServerWithCredentials(updatedServer, password: pass, keyPath: keyPath) {
            print("✅ Server '\(updatedServer.name)' updated successfully with encrypted credentials.")
            onServerUpdated?()
            self.close()
        } else {
            print("❌ Failed to update server.")
            showAlert("Error", "Failed to update server or store credentials securely.")
        }
    }
    
    // MARK: - NSWindowDelegate
    func windowWillClose(_ notification: Notification) {
        onWindowClosed?()
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
}