import Foundation

/// Adapter to make CredentialManager conform to CredentialManaging protocol
class CredentialManagerAdapter: CredentialManaging {
    private let originalManager: CredentialManager
    
    init(originalManager: CredentialManager) {
        self.originalManager = originalManager
    }
    
    // MARK: - CredentialManaging Implementation
    
    func encryptString(_ plaintext: String) throws -> String {
        return try originalManager.encryptString(plaintext)
    }
    
    func decryptString(_ encryptedString: String) throws -> String {
        return try originalManager.decryptString(encryptedString)
    }
    
    func writeSSHKeyToTempFile(_ sshKey: String) throws -> String {
        return try originalManager.writeSSHKeyToTempFile(sshKey)
    }
    
    func cleanupTempFile(_ filePath: String?) {
        originalManager.cleanupTempFile(filePath)
    }
    
    func migrateFromKeychain() {
        originalManager.migrateFromKeychain()
    }
}