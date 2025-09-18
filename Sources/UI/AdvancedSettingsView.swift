import Cocoa

class AdvancedSettingsView: NSView {
    private let settingsManager = SettingsManager.shared
    
    // UI Components
    private var stackView: NSStackView!
    
    // Advanced settings controls
    private var showInactiveContainersCheckbox: NSButton!
    private var customRefreshCheckbox: NSButton!
    private var refreshSlider: NSSlider!
    private var refreshValueLabel: NSTextField!
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        // Main stack view - using same pattern as NotificationsSettingsView
        stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 20
        stackView.alignment = .leading  // Left-aligned like Notifications tab
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        
        setupDockerSection()
        setupRefreshSection()
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -20)
        ])
        
        // Load current settings
        loadCurrentSettings()
    }
    
    private func setupDockerSection() {
        // Section header
        let dockerSectionLabel = NSTextField(labelWithString: "Docker Containers")
        dockerSectionLabel.font = NSFont.boldSystemFont(ofSize: 16)
        dockerSectionLabel.textColor = .labelColor
        stackView.addArrangedSubview(dockerSectionLabel)
        
        // Show inactive containers checkbox
        showInactiveContainersCheckbox = NSButton(checkboxWithTitle: "Show inactive docker containers", target: self, action: #selector(toggleInactiveContainers))
        showInactiveContainersCheckbox.toolTip = "When enabled, dead/stopped containers will be shown under a separate 'Dead Containers' section in the menu"
        stackView.addArrangedSubview(showInactiveContainersCheckbox)
        
        // Explanation text - left-aligned and properly constrained
        let explanationLabel = NSTextField(wrappingLabelWithString: "When this option is enabled, inactive (dead/stopped) Docker containers will be displayed under a separate 'Dead Containers' section in the taskbar menu. This allows you to see all containers on your servers, not just the running ones.")
        explanationLabel.textColor = .secondaryLabelColor
        explanationLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        explanationLabel.maximumNumberOfLines = 0
        explanationLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(explanationLabel)
        
        // Constrain explanation width to prevent it from expanding too wide
        NSLayoutConstraint.activate([
            explanationLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 500)
        ])
    }
    
    private func setupRefreshSection() {
        // Add spacing between sections
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 10).isActive = true
        stackView.addArrangedSubview(spacer)
        
        // Section header
        let refreshSectionLabel = NSTextField(labelWithString: "Custom Refresh Interval")
        refreshSectionLabel.font = NSFont.boldSystemFont(ofSize: 16)
        refreshSectionLabel.textColor = .labelColor
        stackView.addArrangedSubview(refreshSectionLabel)
        
        // Enable custom refresh checkbox
        customRefreshCheckbox = NSButton(checkboxWithTitle: "Enable custom refresh interval", target: self, action: #selector(toggleCustomRefresh))
        customRefreshCheckbox.toolTip = "Enable custom refresh interval for server metrics monitoring"
        stackView.addArrangedSubview(customRefreshCheckbox)
        
        // Refresh interval slider container
        let sliderContainer = NSView()
        sliderContainer.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(sliderContainer)
        
        // Refresh interval slider
        refreshSlider = NSSlider(target: self, action: #selector(refreshSliderChanged))
        refreshSlider.minValue = 7.0  // 7 seconds
        refreshSlider.maxValue = 600.0  // 10 minutes
        refreshSlider.doubleValue = 30.0  // Default 30 seconds
        refreshSlider.numberOfTickMarks = 0
        refreshSlider.isContinuous = true
        refreshSlider.translatesAutoresizingMaskIntoConstraints = false
        sliderContainer.addSubview(refreshSlider)
        
        // Labels for min/max values
        let minLabel = NSTextField(labelWithString: "7s")
        minLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        minLabel.textColor = .secondaryLabelColor
        minLabel.translatesAutoresizingMaskIntoConstraints = false
        sliderContainer.addSubview(minLabel)
        
        let maxLabel = NSTextField(labelWithString: "10m")
        maxLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        maxLabel.textColor = .secondaryLabelColor
        maxLabel.translatesAutoresizingMaskIntoConstraints = false
        sliderContainer.addSubview(maxLabel)
        
        // Current value label
        refreshValueLabel = NSTextField(labelWithString: "30 seconds")
        refreshValueLabel.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        refreshValueLabel.translatesAutoresizingMaskIntoConstraints = false
        sliderContainer.addSubview(refreshValueLabel)
        
        // Layout constraints for slider container
        NSLayoutConstraint.activate([
            sliderContainer.widthAnchor.constraint(equalToConstant: 400),
            sliderContainer.heightAnchor.constraint(equalToConstant: 60),
            
            minLabel.leadingAnchor.constraint(equalTo: sliderContainer.leadingAnchor),
            minLabel.centerYAnchor.constraint(equalTo: refreshSlider.centerYAnchor),
            
            maxLabel.trailingAnchor.constraint(equalTo: sliderContainer.trailingAnchor),
            maxLabel.centerYAnchor.constraint(equalTo: refreshSlider.centerYAnchor),
            
            refreshSlider.leadingAnchor.constraint(equalTo: minLabel.trailingAnchor, constant: 10),
            refreshSlider.trailingAnchor.constraint(equalTo: maxLabel.leadingAnchor, constant: -10),
            refreshSlider.topAnchor.constraint(equalTo: sliderContainer.topAnchor, constant: 5),
            
            refreshValueLabel.leadingAnchor.constraint(equalTo: refreshSlider.leadingAnchor),
            refreshValueLabel.topAnchor.constraint(equalTo: refreshSlider.bottomAnchor, constant: 5),
            refreshValueLabel.bottomAnchor.constraint(equalTo: sliderContainer.bottomAnchor, constant: -5)
        ])
        
        // Refresh explanation - left-aligned
        let refreshExplanationLabel = NSTextField(wrappingLabelWithString: "When enabled, you can customize how often the app checks your servers for updates. Lower values provide more real-time monitoring but may increase server load. Higher values reduce load but updates will be less frequent.")
        refreshExplanationLabel.textColor = .secondaryLabelColor
        refreshExplanationLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        refreshExplanationLabel.maximumNumberOfLines = 0
        refreshExplanationLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(refreshExplanationLabel)
        
        // Constrain explanation width
        NSLayoutConstraint.activate([
            refreshExplanationLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 500)
        ])
    }
    
    private func loadCurrentSettings() {
        let advancedSettings = settingsManager.getAdvancedSettings()
        showInactiveContainersCheckbox.state = advancedSettings.showInactiveDockerContainers ? .on : .off
        customRefreshCheckbox.state = advancedSettings.customRefreshEnabled ? .on : .off
        refreshSlider.doubleValue = advancedSettings.refreshIntervalSeconds
        updateRefreshControls()
        updateRefreshValueLabel()
    }
    
    // MARK: - Action Methods
    
    @objc private func toggleInactiveContainers(_ sender: NSButton) {
        var advancedSettings = settingsManager.getAdvancedSettings()
        advancedSettings.showInactiveDockerContainers = sender.state == .on
        settingsManager.saveAdvancedSettings(advancedSettings)
        
        // Notify app delegate to update menu
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.restartMonitoring()
        }
    }
    
    @objc private func toggleCustomRefresh(_ sender: NSButton) {
        var advancedSettings = settingsManager.getAdvancedSettings()
        advancedSettings.customRefreshEnabled = sender.state == .on
        settingsManager.saveAdvancedSettings(advancedSettings)
        
        updateRefreshControls()
        
        // Notify app delegate to restart monitoring with new interval
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.restartMonitoring()
        }
    }
    
    @objc private func refreshSliderChanged(_ sender: NSSlider) {
        var advancedSettings = settingsManager.getAdvancedSettings()
        advancedSettings.refreshIntervalSeconds = sender.doubleValue
        settingsManager.saveAdvancedSettings(advancedSettings)
        
        updateRefreshValueLabel()
        
        // Only restart monitoring if custom refresh is enabled
        if advancedSettings.customRefreshEnabled {
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.restartMonitoring()
            }
        }
    }
    
    private func updateRefreshControls() {
        let advancedSettings = settingsManager.getAdvancedSettings()
        let isEnabled = advancedSettings.customRefreshEnabled
        
        refreshSlider.isEnabled = isEnabled
        refreshValueLabel.textColor = isEnabled ? .labelColor : .disabledControlTextColor
    }
    
    private func updateRefreshValueLabel() {
        let value = refreshSlider.doubleValue
        let text: String
        
        if value < 60 {
            text = String(format: "%.0f seconds", value)
        } else {
            let minutes = value / 60
            if minutes < 10 {
                text = String(format: "%.1f minutes", minutes)
            } else {
                text = String(format: "%.0f minutes", minutes)
            }
        }
        
        refreshValueLabel.stringValue = text
    }
}