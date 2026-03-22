import SwiftUI

// MARK: - KeyVaultManager Environment Key

private struct KeyVaultManagerKey: EnvironmentKey {
    static let defaultValue = KeyVaultManager()
}

extension EnvironmentValues {
    var keyVaultManager: KeyVaultManager {
        get { self[KeyVaultManagerKey.self] }
        set { self[KeyVaultManagerKey.self] = newValue }
    }
}

// MARK: - KeychainManager Environment Key

private struct KeychainManagerKey: EnvironmentKey {
    static let defaultValue = KeychainManager()
}

extension EnvironmentValues {
    var keychainManager: KeychainManager {
        get { self[KeychainManagerKey.self] }
        set { self[KeychainManagerKey.self] = newValue }
    }
}
