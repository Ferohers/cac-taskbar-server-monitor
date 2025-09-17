import Cocoa

class ServerConfigView: NSView {
    private var nameField: NSTextField!
    private var hostnameField: NSTextField!
    private var usernameField: NSTextField!
    private var passwordField: NSSecureTextField!
    private var keyPathField: NSTextField!
    private var portField: NSTextField!
    
    private let index: Int
    var onRemove: (() -> Void)?
    
    init(server: ServerConfig, index: Int) {
        self.index = index
        super.init(frame: .zero)
        setupUI(with: server)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI(with server: ServerConfig) {
        // Create title with remove button
        let titleContainer = NSView()
        let titleLabel = NSTextField(labelWithString: "Server \(index + 1)")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let removeButton = NSButton(title: "Remove", target: self, action: #selector(removeButtonClicked))
        removeButton.bezelStyle = .rounded
        removeButton.controlSize = .small
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        
        titleContainer.addSubview(titleLabel)
        titleContainer.addSubview(removeButton)
        titleContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleContainer)
        
        // Container box
        let box = NSBox()
        box.title = ""
        box.titlePosition = .noTitle
        box.translatesAutoresizingMaskIntoConstraints = false
        addSubview(box)
        
        let contentView = NSView()
        box.contentView = contentView
        
        // Create form fields
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 15
        stackView.alignment = .leading
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
        
        // Name field
        let nameRow = createFormRow(label: "Server Name:", placeholder: "My Server")
        nameField = nameRow.field
        nameField.stringValue = server.name
        stackView.addArrangedSubview(nameRow.container)
        
        // Hostname field
        let hostnameRow = createFormRow(label: "Hostname/IP:", placeholder: "192.168.1.100 or example.com")
        hostnameField = hostnameRow.field
        hostnameField.stringValue = server.hostname
        stackView.addArrangedSubview(hostnameRow.container)
        
        // Username field
        let usernameRow = createFormRow(label: "Username:", placeholder: "root")
        usernameField = usernameRow.field
        usernameField.stringValue = server.username
        stackView.addArrangedSubview(usernameRow.container)
        
        // Password field
        let passwordRow = createSecureFormRow(label: "Password:", placeholder: "Leave empty if using key")
        passwordField = passwordRow.field
        passwordField.stringValue = server.password ?? ""
        stackView.addArrangedSubview(passwordRow.container)
        
        // SSH Key Path field
        let keyPathRow = createFormRow(label: "SSH Key Path:", placeholder: "~/.ssh/id_rsa (optional)")
        keyPathField = keyPathRow.field
        keyPathField.stringValue = server.keyPath ?? ""
        stackView.addArrangedSubview(keyPathRow.container)
        
        // Port field
        let portRow = createFormRow(label: "Port:", placeholder: "22")
        portField = portRow.field
        portField.stringValue = "\(server.port)"
        portField.formatter = NumberFormatter()
        stackView.addArrangedSubview(portRow.container)
        
        // Browse button for SSH key
        let browseButton = NSButton(title: "Browse...", target: self, action: #selector(browseForKey))
        let browseRow = NSStackView()
        browseRow.orientation = .horizontal
        browseRow.addArrangedSubview(NSView()) // Spacer to align with other fields
        browseRow.addArrangedSubview(browseButton)
        browseRow.addArrangedSubview(NSView()) // Trailing spacer
        stackView.addArrangedSubview(browseRow)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            titleContainer.topAnchor.constraint(equalTo: topAnchor),
            titleContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            titleContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            titleContainer.heightAnchor.constraint(equalToConstant: 35),
            
            titleLabel.leadingAnchor.constraint(equalTo: titleContainer.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: titleContainer.centerYAnchor),
            removeButton.trailingAnchor.constraint(equalTo: titleContainer.trailingAnchor),
            removeButton.centerYAnchor.constraint(equalTo: titleContainer.centerYAnchor),
            
            box.topAnchor.constraint(equalTo: titleContainer.bottomAnchor, constant: 5),
            box.leadingAnchor.constraint(equalTo: leadingAnchor),
            box.trailingAnchor.constraint(equalTo: trailingAnchor),
            box.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func createFormRow(label: String, placeholder: String) -> (container: NSView, field: NSTextField) {
        let container = NSStackView()
        container.orientation = .horizontal
        container.spacing = 15
        container.alignment = .centerY
        
        let labelField = NSTextField(labelWithString: label)
        labelField.widthAnchor.constraint(equalToConstant: 140).isActive = true
        labelField.alignment = .right
        labelField.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.widthAnchor.constraint(greaterThanOrEqualToConstant: 300).isActive = true
        textField.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        
        container.addArrangedSubview(labelField)
        container.addArrangedSubview(textField)
        
        return (container, textField)
    }
    
    private func createSecureFormRow(label: String, placeholder: String) -> (container: NSView, field: NSSecureTextField) {
        let container = NSStackView()
        container.orientation = .horizontal
        container.spacing = 15
        container.alignment = .centerY
        
        let labelField = NSTextField(labelWithString: label)
        labelField.widthAnchor.constraint(equalToConstant: 140).isActive = true
        labelField.alignment = .right
        labelField.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        
        let textField = NSSecureTextField()
        textField.placeholderString = placeholder
        textField.widthAnchor.constraint(greaterThanOrEqualToConstant: 300).isActive = true
        textField.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        
        container.addArrangedSubview(labelField)
        container.addArrangedSubview(textField)
        
        return (container, textField)
    }
    
    @objc private func browseForKey() {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedContentTypes = [.data, .text]
        openPanel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh")
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            keyPathField.stringValue = url.path
        }
    }
    
    @objc private func removeButtonClicked() {
        // Show confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Remove Server"
        alert.informativeText = "Are you sure you want to remove this server configuration?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            onRemove?()
        }
    }
    
    func getServerConfig() -> ServerConfig {
        let port = Int(portField.stringValue) ?? 22
        let password = passwordField.stringValue.isEmpty ? nil : passwordField.stringValue
        let keyPath = keyPathField.stringValue.isEmpty ? nil : keyPathField.stringValue
        
        return ServerConfig(
            name: nameField.stringValue,
            hostname: hostnameField.stringValue,
            username: usernameField.stringValue,
            password: password,
            keyPath: keyPath,
            port: port
        )
    }
}