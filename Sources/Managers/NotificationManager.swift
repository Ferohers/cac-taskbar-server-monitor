
import Foundation
import UserNotifications
import Cocoa

class NotificationManager: NSObject {
    static let shared = NotificationManager()
    
    private var lastNotificationTimes: [String: Date] = [:]
    
    // Notification system capabilities
    private var canUseUNNotifications = false
    private var canUseLegacyNotifications = false
    private var useVisualAlerts = false
    
    private override init() {
        super.init()
        setupNotificationSystem()
    }
    
    // MARK: - Notification System Setup
    
    private func setupNotificationSystem() {
        print("📱 Setting up notification system...")
        
        // Check if we have a bundle identifier (required for most notification systems)
        let hasBundleId = Bundle.main.bundleIdentifier != nil
        print("📱 Bundle identifier available: \(hasBundleId)")
        
        if hasBundleId {
            // Try modern UNUserNotificationCenter first
            setupModernNotifications()
        } else {
            print("📱 No bundle identifier - using fallback notification systems")
            setupFallbackNotifications()
        }
    }
    
    private func setupModernNotifications() {
        // Check if we have a valid bundle identifier first
        guard let bundleId = Bundle.main.bundleIdentifier, !bundleId.isEmpty else {
            print("📱 No bundle identifier - skipping UNUserNotificationCenter")
            canUseUNNotifications = false
            setupFallbackNotifications()
            return
        }
        
        UNUserNotificationCenter.current().delegate = self
        canUseUNNotifications = true
        print("📱 Modern notification system (UNUserNotificationCenter) initialized")
    }
    
    private func setupFallbackNotifications() {
        print("📱 Setting up fallback notification systems...")
        
        // For unsigned apps or when UNUserNotificationCenter fails, use alternative methods
        useVisualAlerts = true
        print("📱 Visual alerts enabled: \(useVisualAlerts)")
        
        // Try legacy NSUserNotification as secondary fallback
        if NSClassFromString("NSUserNotification") != nil {
            canUseLegacyNotifications = true
            print("📱 Legacy notification system (NSUserNotification) available")
            
            // Test legacy notifications immediately
            testLegacyNotifications()
        } else {
            print("📱 Legacy notification system not available")
        }
        
        print("📱 Fallback notification systems initialized - Visual alerts: \(useVisualAlerts), Legacy: \(canUseLegacyNotifications)")
    }
    
    private func testLegacyNotifications() {
        guard canUseLegacyNotifications else { return }
        
        if let centerClass = NSClassFromString("NSUserNotificationCenter") as? NSUserNotificationCenter.Type {
            let center = centerClass.default
            center.delegate = self as? NSUserNotificationCenterDelegate
            print("📱 Legacy notification center delegate set")
        }
    }
    
    
    
    // MARK: - Permission Management
    
    func requestPermissions() {
        guard canUseUNNotifications else {
            print("📱 Skipping permission request - using fallback notification systems")
            return
        }
        
        let center = UNUserNotificationCenter.current()
        
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .notDetermined:
                    print("📱 Requesting notification permissions...")
                    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                        DispatchQueue.main.async {
                            if let error = error {
                                let nsError = error as NSError
                                print("📱 Notification permission error: \(error.localizedDescription)")
                                if nsError.domain == "UNErrorDomain" && nsError.code == 1 {
                                    print("📱 UNErrorDomain error 1 detected - likely entitlement or signing issue")
                                    print("📱 This is common for unsigned/development apps")
                                    print("📱 Falling back to alternative notification methods")
                                } else {
                                    print("📱 Other notification error (\(nsError.domain) \(nsError.code)) - falling back to alternative methods")
                                }
                                self?.canUseUNNotifications = false
                                print("📱 Initializing fallback notification systems...")
                                self?.setupFallbackNotifications()
                            } else if granted {
                                print("📱 Modern notification permissions granted")
                                self?.setupNotificationCategories()
                            } else {
                                print("📱 Modern notification permissions denied by user")
                                self?.canUseUNNotifications = false
                                self?.setupFallbackNotifications()
                            }
                        }
                    }
                case .denied:
                    print("📱 Modern notifications denied - using fallback systems")
                    self?.canUseUNNotifications = false
                    self?.setupFallbackNotifications()
                case .authorized, .provisional, .ephemeral:
                    print("📱 Modern notifications authorized")
                    self?.setupNotificationCategories()
                @unknown default:
                    print("📱 Unknown notification authorization status - using fallback systems")
                    self?.canUseUNNotifications = false
                    self?.setupFallbackNotifications()
                }
            }
        }
    }
    
    private func setupNotificationCategories() {
        guard canUseUNNotifications else { return }
        
        let center = UNUserNotificationCenter.current()
        
        // Server alert actions
        let viewAction = UNNotificationAction(
            identifier: "VIEW_SERVER",
            title: "View Server",
            options: [.foreground]
        )
        
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: []
        )
        
        // Server alert category
        let serverAlertCategory = UNNotificationCategory(
            identifier: "SERVER_ALERT",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Connection alert category
        let connectionAlertCategory = UNNotificationCategory(
            identifier: "CONNECTION_ALERT",
            actions: [dismissAction],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([serverAlertCategory, connectionAlertCategory])
        print("📱 Notification categories configured")
    }
    
    // MARK: - Notification Sending (Multi-tier System)
    
    func sendServerAlert(title: String, message: String, serverName: String, serverID: UUID, alertType: String) {
        let notificationKey = "\(serverID.uuidString)_\(alertType)"
        
        
        // Try notification systems in order of preference
        if canUseUNNotifications {
            sendModernNotification(title: title, message: message, category: "SERVER_ALERT", userInfo: [
                "serverName": serverName,
                "serverID": serverID.uuidString,
                "alertType": alertType
            ]) { [weak self] success in
                if success {
                    self?.lastNotificationTimes[notificationKey] = Date()
                } else {
                    // Fallback to next method
                    self?.sendLegacyNotification(title: title, message: message, notificationKey: notificationKey)
                }
            }
        } else if canUseLegacyNotifications {
            sendLegacyNotification(title: title, message: message, notificationKey: notificationKey)
        } else if useVisualAlerts {
            sendVisualAlert(title: title, message: message, notificationKey: notificationKey)
        } else {
            // Final fallback - console with visual indicator
            sendConsoleNotification(title: title, message: message, notificationKey: notificationKey)
        }
    }
    
    func sendConnectionAlert(serverName: String, serverID: UUID, isConnected: Bool) {
        let notificationKey = "\(serverID.uuidString)_connection_\(isConnected)"
        
        
        let title = isConnected ? "Server Connected" : "Server Disconnected"
        let message = isConnected ? 
            "Connection to '\(serverName)' has been restored" :
            "Lost connection to '\(serverName)'"
        
        // Try notification systems in order of preference
        if canUseUNNotifications {
            sendModernNotification(title: title, message: message, category: "CONNECTION_ALERT", userInfo: [
                "serverName": serverName,
                "serverID": serverID.uuidString,
                "isConnected": isConnected
            ]) { [weak self] success in
                if success {
                    self?.lastNotificationTimes[notificationKey] = Date()
                } else {
                    // Fallback to next method
                    self?.sendLegacyNotification(title: title, message: message, notificationKey: notificationKey)
                }
            }
        } else if canUseLegacyNotifications {
            sendLegacyNotification(title: title, message: message, notificationKey: notificationKey)
        } else if useVisualAlerts {
            sendVisualAlert(title: title, message: message, notificationKey: notificationKey)
        } else {
            // Final fallback - console with visual indicator
            sendConsoleNotification(title: title, message: message, notificationKey: notificationKey)
        }
    }
    
    func sendSystemAlert(title: String, message: String) {
        let notificationKey = "system_\(Date().timeIntervalSince1970)"
        
        // Try notification systems in order of preference
        if canUseUNNotifications {
            sendModernNotification(title: title, message: message, category: nil, userInfo: [:]) { [weak self] success in
                if !success {
                    // Fallback to next method
                    self?.sendLegacyNotification(title: title, message: message, notificationKey: notificationKey)
                }
            }
        } else if canUseLegacyNotifications {
            sendLegacyNotification(title: title, message: message, notificationKey: notificationKey)
        } else if useVisualAlerts {
            sendVisualAlert(title: title, message: message, notificationKey: notificationKey)
        } else {
            // Final fallback - console with visual indicator
            sendConsoleNotification(title: title, message: message, notificationKey: notificationKey)
        }
    }
    
    // MARK: - Modern Notifications (UNUserNotificationCenter)
    
    private func sendModernNotification(title: String, message: String, category: String?, userInfo: [String: Any], completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = message
            content.sound = UNNotificationSound.default
            content.userInfo = userInfo
            
            if let category = category {
                content.categoryIdentifier = category
            }
            
            // Add badge count
            content.badge = NSNumber(value: 1)
            
            let identifier = "notification-\(Date().timeIntervalSince1970)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            
            UNUserNotificationCenter.current().add(request) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("📱 Failed to send modern notification: \(error.localizedDescription)")
                        completion(false)
                    } else {
                        print("📱 Modern notification sent: \(title)")
                        completion(true)
                    }
                }
            }
        }
    }
    
    // MARK: - Legacy Notifications (NSUserNotification)
    
    private func sendLegacyNotification(title: String, message: String, notificationKey: String) {
        print("📱 Attempting to send legacy notification: \(title)")
        
        guard canUseLegacyNotifications else {
            print("📱 Legacy notifications not available, falling back to visual alert")
            sendVisualAlert(title: title, message: message, notificationKey: notificationKey)
            return
        }
        
        // Use NSUserNotification for older systems or unsigned apps
        if let notificationClass = NSClassFromString("NSUserNotification") as? NSUserNotification.Type,
           let centerClass = NSClassFromString("NSUserNotificationCenter") as? NSUserNotificationCenter.Type {
            
            print("📱 Creating legacy notification...")
            let notification = notificationClass.init()
            notification.title = title
            notification.informativeText = message
            notification.soundName = NSUserNotificationDefaultSoundName
            
            let center = centerClass.default
            
            // Deliver the legacy notification
            center.deliver(notification)
            lastNotificationTimes[notificationKey] = Date()
            print("📱 Legacy notification sent: \(title)")
        } else {
            print("📱 Legacy notification classes not found, falling back to visual alert")
            // Fallback to visual alert
            sendVisualAlert(title: title, message: message, notificationKey: notificationKey)
        }
    }
    
    // MARK: - Visual Alert System (Always Works)
    
    private func sendVisualAlert(title: String, message: String, notificationKey: String) {
        DispatchQueue.main.async { [weak self] in
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            
            // For system notifications, show less intrusively
            if title.contains("Duman Server Monitor") {
                // For system startup notifications, just run modal briefly
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let response = alert.runModal()
                    if response == .alertFirstButtonReturn {
                        print("📱 User acknowledged system notification")
                    }
                }
            } else {
                // For server alerts, show appropriately
                if let window = NSApp.mainWindow {
                    alert.beginSheetModal(for: window) { _ in
                        // Alert dismissed
                    }
                } else {
                    let response = alert.runModal()
                    if response == .alertFirstButtonReturn {
                        print("📱 User acknowledged alert: \(title)")
                    }
                }
            }
            
            self?.lastNotificationTimes[notificationKey] = Date()
            print("📱 Visual alert shown: \(title)")
        }
    }
    
    // MARK: - Console Notification (Final Fallback)
    
    private func sendConsoleNotification(title: String, message: String, notificationKey: String) {
        // Enhanced console output with visual indicators
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let separator = String(repeating: "=", count: 60)
        
        print("")
        print(separator)
        print("🚨 DUMAN NOTIFICATION ALERT 🚨")
        print("Time: \(timestamp)")
        print("Title: \(title)")
        print("Message: \(message)")
        print(separator)
        print("")
        
        // Try to show notification in menu bar title
        DispatchQueue.main.async {
            // Look for menu bar controller
            if let appDelegate = NSApp.delegate as? AppDelegate,
               let menuBarController = appDelegate.value(forKey: "menuBarController") as? AnyObject,
               let statusItem = menuBarController.value(forKey: "statusItem") as? NSStatusItem {
                
                // Flash the menu bar icon
                statusItem.button?.title = "🚨"
                
                // Reset after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    statusItem.button?.title = ""
                }
            }
        }
        
        lastNotificationTimes[notificationKey] = Date()
        print("📱 Console notification logged and menu bar updated: \(title)")
    }
    
    // MARK: - Notification Management
    
    func clearAllNotifications() {
        if canUseUNNotifications {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        }
        
        // Clear legacy notifications if available
        if canUseLegacyNotifications,
           let centerClass = NSClassFromString("NSUserNotificationCenter") as? NSUserNotificationCenter.Type {
            let center = centerClass.default
            center.removeAllDeliveredNotifications()
        }
        
        lastNotificationTimes.removeAll()
        print("📱 All notifications cleared")
    }
    
    func clearNotifications(for serverID: UUID) {
        if canUseUNNotifications {
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                let identifiersToRemove = requests.compactMap { request in
                    if let userInfo = request.content.userInfo as? [String: Any],
                       let id = userInfo["serverID"] as? String,
                       id == serverID.uuidString {
                        return request.identifier
                    }
                    return nil
                }
                
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
            }
            
            UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
                let identifiersToRemove = notifications.compactMap { notification in
                    if let userInfo = notification.request.content.userInfo as? [String: Any],
                       let id = userInfo["serverID"] as? String,
                       id == serverID.uuidString {
                        return notification.request.identifier
                    }
                    return nil
                }
                
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiersToRemove)
            }
        }
        
        // Remove notification tracking entries for this server
        lastNotificationTimes = lastNotificationTimes.filter { !$0.key.hasPrefix(serverID.uuidString) }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is active
        if #available(macOS 11.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }
    
    // Handle notification interactions
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "VIEW_SERVER":
            if let serverName = userInfo["serverName"] as? String {
                print("📱 User requested to view server: \(serverName)")
                // Bring app to foreground and show server details
                NSApp.activate(ignoringOtherApps: true)
            }
            
        case "DISMISS":
            print("📱 User dismissed notification")
            
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification
            NSApp.activate(ignoringOtherApps: true)
            
        default:
            break
        }
        
        completionHandler()
    }
}