import Foundation

enum AppError: LocalizedError, Equatable {
    case serverConnectionFailed(String)
    case credentialError(CredentialError)
    case configurationError(String)
    case networkError(String)
    case validationError([String])
    case fileSystemError(String)
    case authenticationFailed(String)
    case sshError(SSHError)
    case monitoringError(String)
    case notificationError(String)
    case serverOperationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .serverConnectionFailed(let message):
            return "Failed to connect to server: \(message)"
        case .credentialError(let error):
            return "Credential error: \(error.localizedDescription ?? "Unknown credential error")"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .validationError(let errors):
            return "Validation failed: \(errors.joined(separator: ", "))"
        case .fileSystemError(let message):
            return "File system error: \(message)"
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .sshError(let error):
            return "SSH error: \(error.localizedDescription ?? "Unknown SSH error")"
        case .monitoringError(let message):
            return "Monitoring error: \(message)"
        case .notificationError(let message):
            return "Notification error: \(message)"
        case .serverOperationFailed(let message):
            return "Server operation failed: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .serverConnectionFailed:
            return "Check network connection and server address. Verify the server is running and accessible."
        case .credentialError:
            return "Verify username, password, or SSH key. Check that credentials are properly configured."
        case .configurationError:
            return "Review server configuration settings. Ensure all required fields are filled correctly."
        case .networkError:
            return "Check internet connection and try again. Verify firewall settings if the problem persists."
        case .validationError:
            return "Correct the highlighted fields and try again."
        case .fileSystemError:
            return "Check file permissions and available disk space."
        case .authenticationFailed:
            return "Verify credentials and server access. Check SSH key permissions (should be 600)."
        case .sshError:
            return "Check SSH configuration and server accessibility. Verify SSH service is running on the target server."
        case .monitoringError:
            return "Check server monitoring configuration and restart monitoring if needed."
        case .notificationError:
            return "Check notification permissions in System Preferences."
        case .serverOperationFailed:
            return "Review server configuration and try the operation again."
        }
    }
    
    var failureReason: String? {
        switch self {
        case .serverConnectionFailed:
            return "Unable to establish connection to the remote server."
        case .credentialError:
            return "Invalid or corrupted credential data."
        case .configurationError:
            return "Invalid server configuration parameters."
        case .networkError:
            return "Network connectivity issue."
        case .validationError:
            return "Input validation failed."
        case .fileSystemError:
            return "File system operation failed."
        case .authenticationFailed:
            return "Server rejected authentication attempt."
        case .sshError:
            return "SSH protocol error occurred."
        case .monitoringError:
            return "Server monitoring process failed."
        case .notificationError:
            return "Notification system error."
        case .serverOperationFailed:
            return "Server operation could not be completed."
        }
    }
}

// MARK: - Equatable Implementation
extension AppError {
    static func == (lhs: AppError, rhs: AppError) -> Bool {
        switch (lhs, rhs) {
        case (.serverConnectionFailed(let lhsMessage), .serverConnectionFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.credentialError(let lhsError), .credentialError(let rhsError)):
            return lhsError == rhsError
        case (.configurationError(let lhsMessage), .configurationError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.networkError(let lhsMessage), .networkError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.validationError(let lhsErrors), .validationError(let rhsErrors)):
            return lhsErrors == rhsErrors
        case (.fileSystemError(let lhsMessage), .fileSystemError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.authenticationFailed(let lhsMessage), .authenticationFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.sshError(let lhsError), .sshError(let rhsError)):
            return lhsError == rhsError
        case (.monitoringError(let lhsMessage), .monitoringError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.notificationError(let lhsMessage), .notificationError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.serverOperationFailed(let lhsMessage), .serverOperationFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}