import Foundation
import Security

enum KeychainError: Error, LocalizedError {
    case itemNotFound
    case duplicateItem
    case invalidData
    case unexpectedError(OSStatus)
    case keyFileReadError
    
    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Item not found in keychain"
        case .duplicateItem:
            return "Item already exists in keychain"
        case .invalidData:
            return "Invalid data format"
        case .unexpectedError(let status):
            return "Keychain error: \(status)"
        case .keyFileReadError:
            return "Failed to read SSH key file"
        }
    }
}

class KeychainManager {
    private let serviceName = "Duman"
    
    // MARK: - Password Management
    
    func storePassword(for serverID: String, password: String) throws {
        let passwordData = password.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "password_\(serverID)",
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Try to add the item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            // Item exists, update it
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: "password_\(serverID)"
            ]
            
            let updateAttributes: [String: Any] = [
                kSecValueData as String: passwordData
            ]
            
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
            if updateStatus != errSecSuccess {
                throw KeychainError.unexpectedError(updateStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.unexpectedError(status)
        }
    }
    
    func retrievePassword(for serverID: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "password_\(serverID)",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedError(status)
        }
        
        guard let passwordData = result as? Data,
              let password = String(data: passwordData, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        
        return password
    }
    
    func deletePassword(for serverID: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "password_\(serverID)"
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.unexpectedError(status)
        }
    }
    
    // MARK: - SSH Key Management
    
    func storeSSHKey(for serverID: String, keyPath: String) throws {
        // Read the SSH key file
        let expandedPath = NSString(string: keyPath).expandingTildeInPath
        let keyURL = URL(fileURLWithPath: expandedPath)
        
        guard let keyData = try? Data(contentsOf: keyURL) else {
            throw KeychainError.keyFileReadError
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "sshkey_\(serverID)",
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrComment as String: "SSH private key for server \(serverID)"
        ]
        
        // Try to add the item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            // Item exists, update it
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: "sshkey_\(serverID)"
            ]
            
            let updateAttributes: [String: Any] = [
                kSecValueData as String: keyData,
                kSecAttrComment as String: "SSH private key for server \(serverID)"
            ]
            
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
            if updateStatus != errSecSuccess {
                throw KeychainError.unexpectedError(updateStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.unexpectedError(status)
        }
    }
    
    func retrieveSSHKey(for serverID: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "sshkey_\(serverID)",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedError(status)
        }
        
        guard let keyData = result as? Data else {
            throw KeychainError.invalidData
        }
        
        return keyData
    }
    
    func writeSSHKeyToTempFile(for serverID: String) throws -> String {
        let keyData = try retrieveSSHKey(for: serverID)
        
        // Create a temporary file for the SSH key
        let tempDir = NSTemporaryDirectory()
        let tempFileName = "altanmon_key_\(serverID)_\(UUID().uuidString)"
        let tempFilePath = (tempDir as NSString).appendingPathComponent(tempFileName)
        
        // Write key data to temporary file
        try keyData.write(to: URL(fileURLWithPath: tempFilePath))
        
        // Set proper permissions (600 - read/write for owner only)
        let attributes = [FileAttributeKey.posixPermissions: 0o600]
        try FileManager.default.setAttributes(attributes, ofItemAtPath: tempFilePath)
        
        return tempFilePath
    }
    
    func deleteSSHKey(for serverID: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "sshkey_\(serverID)"
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.unexpectedError(status)
        }
    }
    
    // MARK: - Utility Methods
    
    func hasPassword(for serverID: String) -> Bool {
        do {
            _ = try retrievePassword(for: serverID)
            return true
        } catch {
            return false
        }
    }
    
    func hasSSHKey(for serverID: String) -> Bool {
        do {
            _ = try retrieveSSHKey(for: serverID)
            return true
        } catch {
            return false
        }
    }
    
    func cleanupCredentials(for serverID: String) {
        try? deletePassword(for: serverID)
        try? deleteSSHKey(for: serverID)
    }
    
}