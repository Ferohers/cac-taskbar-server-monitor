import Cocoa

class NotificationsSettingsView: NSView {
    private let settingsManager = SettingsManager.shared
    private var servers: [ServerConfig] = []
    private var notificationSettings: [ServerNotificationSettings] = []
    
    // UI Components
    private var stackView: NSStackView!
    private var serverSelectionPopup: NSPopUpButton!
    private var contentContainer: NSStackView!
    
    // Current server settings controls
    private var enableNotificationsCheckbox: NSButton!
    private var connectionAlertsCheckbox: NSButton!
    private var performanceAlertsCheckbox: NSButton!
    private var systemAlertsCheckbox: NSButton!
    
    // Performance thresholds
    private var cpuThresholdSlider: NSSlider!
    private var cpuThresholdLabel: NSTextField!
    private var memoryThresholdSlider: NSSlider!
    private var memoryThresholdLabel: NSTextField!
    private var diskThresholdSlider: NSSlider!
    private var diskThresholdLabel: NSTextField!
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        // Main stack view
        stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 20
        stackView.alignment = .leading
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        
        setupHeader()
        setupServerSelection()
        setupNotificationControls()
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -20)
        ])
    }
    
    private func setupHeader() {
        let titleLabel = NSTextField(labelWithString: "Push Notifications")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = .labelColor
        stackView.addArrangedSubview(titleLabel)
        
        let subtitleLabel = NSTextField(wrappingLabelWithString: "Configure push notifications for server monitoring. Notifications will appear in macOS Notification Center.")
        subtitleLabel.font = NSFont.systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.maximumNumberOfLines = 0
        stackView.addArrangedSubview(subtitleLabel)
    }
    
    private func setupServerSelection() {
        let serverContainer = NSStackView()
        serverContainer.orientation = .horizontal
        serverContainer.spacing = 10
        serverContainer.alignment = .centerY
        
        let serverLabel = NSTextField(labelWithString: "Configure notifications for:")
        serverLabel.font = NSFont.systemFont(ofSize: 13)
        serverContainer.addArrangedSubview(serverLabel)
        
        serverSelectionPopup = NSPopUpButton(frame: NSRect.zero, pullsDown: false)
        serverSelectionPopup.target = self
        serverSelectionPopup.action = #selector(serverSelectionChanged)
        serverSelectionPopup.translatesAutoresizingMaskIntoConstraints = false
        serverContainer.addArrangedSubview(serverSelectionPopup)
        
        NSLayoutConstraint.activate([
            serverSelectionPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 200)
        ])
        
        stackView.addArrangedSubview(serverContainer)
        
        // Separator
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(separator)
        
        NSLayoutConstraint.activate([
            separator.widthAnchor.constraint(equalToConstant: 500)
        ])
    }
    
    private func setupNotificationControls() {
        contentContainer = NSStackView()
        contentContainer.orientation = .vertical
        contentContainer.spacing = 15
        contentContainer.alignment = .leading
        contentContainer.distribution = .fill
        stackView.addArrangedSubview(contentContainer)
    }
    
    private func refreshContent() {
        // Clear existing content
        contentContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Update server popup
        serverSelectionPopup.removeAllItems()
        
        if servers.isEmpty {
            let noServersLabel = NSTextField(labelWithString: "No servers configured.")
            noServersLabel.font = NSFont.systemFont(ofSize: 14)
            noServersLabel.textColor = .secondaryLabelColor
            contentContainer.addArrangedSubview(noServersLabel)
            
            serverSelectionPopup.isEnabled = false
            return
        }
        
        // Populate server popup
        serverSelectionPopup.isEnabled = true
        for server in servers {
            serverSelectionPopup.addItem(withTitle: server.name)
        }
        
        // Show settings for selected server
        if serverSelectionPopup.numberOfItems > 0 {
            showSettingsForSelectedServer()
        }
    }
    
    private func showSettingsForSelectedServer() {
        guard serverSelectionPopup.indexOfSelectedItem >= 0,
              serverSelectionPopup.indexOfSelectedItem < servers.count else { return }
        
        let selectedServer = servers[serverSelectionPopup.indexOfSelectedItem]
        
        // Find or create notification settings for this server
        var settings = notificationSettings.first { $0.serverID == selectedServer.id }
        if settings == nil {
            settings = settingsManager.createDefaultNotificationSettings(for: selectedServer)
            notificationSettings.append(settings!)
        }
        
        guard let currentSettings = settings else { return }
        
        // Clear previous content
        contentContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Create controls for the selected server
        createNotificationControls(for: currentSettings)
    }
    
    private func createNotificationControls(for settings: ServerNotificationSettings) {
        let notificationSettings = settings.settings
        
        // Enable notifications toggle
        enableNotificationsCheckbox = NSButton(checkboxWithTitle: "Enable notifications for this server", target: self, action: #selector(enableNotificationsChanged))
        enableNotificationsCheckbox.state = notificationSettings.isEnabled ? .on : .off
        contentContainer.addArrangedSubview(enableNotificationsCheckbox)
        
        // Only show other controls if notifications are enabled
        guard notificationSettings.isEnabled else {
            let disabledLabel = NSTextField(labelWithString: "Enable notifications above to configure specific alert types.")
            disabledLabel.font = NSFont.systemFont(ofSize: 12)
            disabledLabel.textColor = .secondaryLabelColor
            contentContainer.addArrangedSubview(disabledLabel)
            return
        }
        
        // Connection alerts with explanation
        connectionAlertsCheckbox = NSButton(checkboxWithTitle: "Connection status alerts", target: self, action: #selector(connectionAlertsChanged))
        connectionAlertsCheckbox.state = notificationSettings.connectionAlerts ? .on : .off
        connectionAlertsCheckbox.toolTip = "Get notified when server connection status changes"
        contentContainer.addArrangedSubview(connectionAlertsCheckbox)
        
        let connectionExplanation = NSTextField(wrappingLabelWithString: "Notifies you when servers become unreachable or when connection is restored, including authentication failures and network timeouts.")
        connectionExplanation.font = NSFont.systemFont(ofSize: 11)
        connectionExplanation.textColor = .secondaryLabelColor
        connectionExplanation.maximumNumberOfLines = 0
        contentContainer.addArrangedSubview(connectionExplanation)
        
        // System alerts with explanation
        systemAlertsCheckbox = NSButton(checkboxWithTitle: "System alerts", target: self, action: #selector(systemAlertsChanged))
        systemAlertsCheckbox.state = notificationSettings.systemAlerts ? .on : .off
        systemAlertsCheckbox.toolTip = "Get notified about important system events"
        contentContainer.addArrangedSubview(systemAlertsCheckbox)
        
        let systemExplanation = NSTextField(wrappingLabelWithString: "Notifies you about application events, server management changes, permission issues, and critical system errors.")
        systemExplanation.font = NSFont.systemFont(ofSize: 11)
        systemExplanation.textColor = .secondaryLabelColor
        systemExplanation.maximumNumberOfLines = 0
        contentContainer.addArrangedSubview(systemExplanation)
        
        // Performance alerts
        performanceAlertsCheckbox = NSButton(checkboxWithTitle: "Performance threshold alerts", target: self, action: #selector(performanceAlertsChanged))
        performanceAlertsCheckbox.state = notificationSettings.performanceAlerts ? .on : .off
        performanceAlertsCheckbox.toolTip = "Get notified when server metrics exceed configured thresholds"
        contentContainer.addArrangedSubview(performanceAlertsCheckbox)
        
        // Performance threshold controls (only if performance alerts are enabled)
        if notificationSettings.performanceAlerts {
            createPerformanceThresholdControls(for: notificationSettings)
        }
    }
    
    private func createPerformanceThresholdControls(for settings: NotificationSettings) {
        let thresholdContainer = NSStackView()
        thresholdContainer.orientation = .vertical
        thresholdContainer.spacing = 10
        thresholdContainer.alignment = .leading
        
        let thresholdLabel = NSTextField(labelWithString: "Performance Thresholds:")
        thresholdLabel.font = NSFont.boldSystemFont(ofSize: 13)
        thresholdContainer.addArrangedSubview(thresholdLabel)
        
        // CPU threshold (0-100 range per user request)
        let cpuContainer = createThresholdControl(
            title: "CPU Usage",
            value: settings.cpuThreshold,
            unit: "%",
            minValue: 0.0,
            maxValue: 100.0,
            action: #selector(cpuThresholdChanged)
        )
        cpuThresholdSlider = cpuContainer.arrangedSubviews[1] as? NSSlider
        cpuThresholdLabel = cpuContainer.arrangedSubviews[2] as? NSTextField
        thresholdContainer.addArrangedSubview(cpuContainer)
        
        // Memory threshold (0-100 range per user request)
        let memoryContainer = createThresholdControl(
            title: "Memory Usage",
            value: settings.memoryThreshold,
            unit: "%",
            minValue: 0.0,
            maxValue: 100.0,
            action: #selector(memoryThresholdChanged)
        )
        memoryThresholdSlider = memoryContainer.arrangedSubviews[1] as? NSSlider
        memoryThresholdLabel = memoryContainer.arrangedSubviews[2] as? NSTextField
        thresholdContainer.addArrangedSubview(memoryContainer)
        
        // Disk threshold
        let diskContainer = createThresholdControl(
            title: "Disk Space Remaining",
            value: settings.diskThreshold,
            unit: "GB",
            minValue: 0.5,
            maxValue: 20.0,
            action: #selector(diskThresholdChanged)
        )
        diskThresholdSlider = diskContainer.arrangedSubviews[1] as? NSSlider
        diskThresholdLabel = diskContainer.arrangedSubviews[2] as? NSTextField
        thresholdContainer.addArrangedSubview(diskContainer)
        
        contentContainer.addArrangedSubview(thresholdContainer)
    }
    
    private func createThresholdControl(title: String, value: Float, unit: String, minValue: Double, maxValue: Double, action: Selector) -> NSStackView {
        let container = NSStackView()
        container.orientation = .horizontal
        container.spacing = 10
        container.alignment = .centerY
        
        let titleLabel = NSTextField(labelWithString: title + ":")
        titleLabel.font = NSFont.systemFont(ofSize: 12)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addArrangedSubview(titleLabel)
        
        let slider = NSSlider()
        slider.minValue = minValue
        slider.maxValue = maxValue
        slider.doubleValue = Double(value)
        slider.target = self
        slider.action = action
        slider.translatesAutoresizingMaskIntoConstraints = false
        container.addArrangedSubview(slider)
        
        let valueLabel = NSTextField(labelWithString: String(format: "%.1f%@", value, unit))
        valueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        valueLabel.alignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addArrangedSubview(valueLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.widthAnchor.constraint(equalToConstant: 120),
            slider.widthAnchor.constraint(equalToConstant: 150),
            valueLabel.widthAnchor.constraint(equalToConstant: 60)
        ])
        
        return container
    }
    
    // MARK: - Action Methods
    
    @objc private func serverSelectionChanged() {
        showSettingsForSelectedServer()
    }
    
    @objc private func enableNotificationsChanged(_ sender: NSButton) {
        updateCurrentSettings { settings in
            settings.isEnabled = sender.state == .on
        }
        showSettingsForSelectedServer() // Refresh to show/hide controls
    }
    
    @objc private func connectionAlertsChanged(_ sender: NSButton) {
        updateCurrentSettings { settings in
            settings.connectionAlerts = sender.state == .on
        }
    }
    
    @objc private func performanceAlertsChanged(_ sender: NSButton) {
        updateCurrentSettings { settings in
            settings.performanceAlerts = sender.state == .on
        }
        showSettingsForSelectedServer() // Refresh to show/hide threshold controls
    }
    
    @objc private func systemAlertsChanged(_ sender: NSButton) {
        updateCurrentSettings { settings in
            settings.systemAlerts = sender.state == .on
        }
    }
    
    @objc private func cpuThresholdChanged(_ sender: NSSlider) {
        let value = Float(sender.doubleValue)
        updateCurrentSettings { settings in
            settings.cpuThreshold = value
        }
        cpuThresholdLabel?.stringValue = String(format: "%.0f%%", value)
    }
    
    @objc private func memoryThresholdChanged(_ sender: NSSlider) {
        let value = Float(sender.doubleValue)
        updateCurrentSettings { settings in
            settings.memoryThreshold = value
        }
        memoryThresholdLabel?.stringValue = String(format: "%.0f%%", value)
    }
    
    @objc private func diskThresholdChanged(_ sender: NSSlider) {
        let value = Float(sender.doubleValue)
        updateCurrentSettings { settings in
            settings.diskThreshold = value
        }
        diskThresholdLabel?.stringValue = String(format: "%.1fGB", value)
    }
    
    private func updateCurrentSettings(_ updateBlock: (inout NotificationSettings) -> Void) {
        guard serverSelectionPopup.indexOfSelectedItem >= 0,
              serverSelectionPopup.indexOfSelectedItem < servers.count else { return }
        
        let selectedServer = servers[serverSelectionPopup.indexOfSelectedItem]
        
        guard let index = notificationSettings.firstIndex(where: { $0.serverID == selectedServer.id }) else { return }
        
        var settings = notificationSettings[index]
        updateBlock(&settings.settings)
        
        notificationSettings[index] = settings
        settingsManager.saveNotificationSettings(settings)
    }
    
    // MARK: - Public Methods
    
    func loadData(servers: [ServerConfig]) {
        self.servers = servers
        self.notificationSettings = settingsManager.getAllNotificationSettings()
        
        // Create default settings for servers that don't have notification settings yet
        for server in servers {
            if !notificationSettings.contains(where: { $0.serverID == server.id }) {
                let defaultSettings = settingsManager.createDefaultNotificationSettings(for: server)
                notificationSettings.append(defaultSettings)
            }
        }
        
        refreshContent()
    }
}