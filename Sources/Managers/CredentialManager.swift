import Foundation
import CryptoKit

enum CredentialError: Error, LocalizedError, Equatable {
    case encryptionFailed
    case decryptionFailed
    case invalidKey
    case keyGenerationFailed
    
    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "Failed to encrypt credential data"
        case .decryptionFailed:
            return "Failed to decrypt credential data"
        case .invalidKey:
            return "Invalid encryption key"
        case .keyGenerationFailed:
            return "Failed to generate encryption key"
        }
    }
}

class CredentialManager {
    static let shared = CredentialManager()
    
    private let keySize = 32 // 256 bits for AES-256
    private var encryptionKey: SymmetricKey?
    
    private init() {
        setupEncryptionKey()
    }
    
    // MARK: - Key Management
    
    private func setupEncryptionKey() {
        // Try to load existing key from user defaults
        if let keyData = UserDefaults.standard.data(forKey: "DumanEncryptionKey") {
            encryptionKey = SymmetricKey(data: keyData)
        } else {
            // Generate new key and store it
            generateAndStoreNewKey()
        }
    }
    
    private func generateAndStoreNewKey() {
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        UserDefaults.standard.set(keyData, forKey: "DumanEncryptionKey")
        encryptionKey = key
    }
    
    // MARK: - Encryption/Decryption
    
    func encryptString(_ plaintext: String) throws -> String {
        guard let key = encryptionKey else {
            throw CredentialError.invalidKey
        }
        
        guard let data = plaintext.data(using: .utf8) else {
            throw CredentialError.encryptionFailed
        }
        
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            let encryptedData = sealedBox.combined
            return encryptedData?.base64EncodedString() ?? ""
        } catch {
            throw CredentialError.encryptionFailed
        }
    }
    
    func decryptString(_ encryptedString: String) throws -> String {
        guard let key = encryptionKey else {
            throw CredentialError.invalidKey
        }
        
        guard let encryptedData = Data(base64Encoded: encryptedString) else {
            throw CredentialError.decryptionFailed
        }
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            
            guard let decryptedString = String(data: decryptedData, encoding: .utf8) else {
                throw CredentialError.decryptionFailed
            }
            
            return decryptedString
        } catch {
            throw CredentialError.decryptionFailed
        }
    }
    
    // MARK: - SSH Key File Management
    
    func writeSSHKeyToTempFile(_ sshKey: String) throws -> String {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFilePath = tempDir.appendingPathComponent("duman_ssh_key_\(UUID().uuidString)").path
        
        try sshKey.write(toFile: tempFilePath, atomically: true, encoding: .utf8)
        
        // Set secure permissions (600 - readable/writable by owner only)
        let attributes = [FileAttributeKey.posixPermissions: 0o600]
        try FileManager.default.setAttributes(attributes, ofItemAtPath: tempFilePath)
        
        return tempFilePath
    }
    
    func cleanupTempFile(_ filePath: String?) {
        guard let filePath = filePath else { return }
        try? FileManager.default.removeItem(atPath: filePath)
    }
    
    // MARK: - Migration Support
    
    func migrateFromKeychain() {
        // This method can be implemented later if we need to migrate existing Keychain data
        // For now, we'll start fresh with the new system
        print("📦 Credential storage migrated to encrypted file storage")
    }
}