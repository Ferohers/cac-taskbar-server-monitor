import Foundation

protocol CredentialManaging {
    func encryptString(_ plaintext: String) throws -> String
    func decryptString(_ encryptedString: String) throws -> String
    func writeSSHKeyToTempFile(_ sshKey: String) throws -> String
    func cleanupTempFile(_ filePath: String?)
    func migrateFromKeychain()
}