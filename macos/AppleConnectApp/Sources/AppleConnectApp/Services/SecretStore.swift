import Foundation
import Security

protocol SecretStoring {
    func save(_ value: String, account: String, service: String) throws
    func read(account: String, service: String) throws -> String?
    func delete(account: String, service: String) throws
}

protocol ConnectionPersisting {
    func loadConnection() throws -> DeveloperConnection?
    func saveConnection(_ connection: DeveloperConnection) throws
    func deleteConnection(_ connection: DeveloperConnection) throws
}

protocol LLMProviderPersisting {
    func loadConfiguration() throws -> LLMProviderConfiguration?
    func saveConfiguration(_ configuration: LLMProviderConfiguration) throws
    func deleteConfiguration() throws
}

struct KeychainConnectionStore: ConnectionPersisting {
    private let secretStore: any SecretStoring
    private let userDefaults: UserDefaults

    init(
        secretStore: any SecretStoring = KeychainSecretStore(),
        userDefaults: UserDefaults = .standard
    ) {
        self.secretStore = secretStore
        self.userDefaults = userDefaults
    }

    func loadConnection() throws -> DeveloperConnection? {
        guard let data = userDefaults.data(forKey: AppConstants.connectionDefaultsKey) else {
            return nil
        }

        let record = try JSONDecoder().decode(DeveloperConnectionRecord.self, from: data)
        let privateKey = try secretStore.read(
            account: record.id.uuidString,
            service: AppConstants.keychainPrivateKeyService
        ) ?? ""

        return DeveloperConnection(
            id: record.id,
            name: record.name,
            keyID: record.keyID,
            issuerID: record.issuerID,
            privateKeyPath: record.privateKeyPath,
            privateKeyPEM: privateKey,
            status: restoredStatus(from: record, privateKey: privateKey),
            lastCheckedAt: record.lastCheckedAt
        )
    }

    func saveConnection(_ connection: DeveloperConnection) throws {
        let privateKey = try privateKeyValue(from: connection)
        guard !privateKey.isEmpty else {
            throw ServiceError.missingCredentials
        }

        try secretStore.save(
            privateKey,
            account: connection.id.uuidString,
            service: AppConstants.keychainPrivateKeyService
        )

        let record = DeveloperConnectionRecord(
            id: connection.id,
            name: connection.name,
            keyID: connection.keyID,
            issuerID: connection.issuerID,
            privateKeyPath: connection.privateKeyPath,
            lastCheckedAt: connection.lastCheckedAt,
            verifiedVisibleAppCount: connection.verifiedVisibleAppCount
        )
        let data = try JSONEncoder().encode(record)
        userDefaults.set(data, forKey: AppConstants.connectionDefaultsKey)
    }

    func deleteConnection(_ connection: DeveloperConnection) throws {
        try secretStore.delete(
            account: connection.id.uuidString,
            service: AppConstants.keychainPrivateKeyService
        )
        userDefaults.removeObject(forKey: AppConstants.connectionDefaultsKey)
    }

    private func privateKeyValue(from connection: DeveloperConnection) throws -> String {
        if !connection.privateKeyPEM.isEmpty {
            return connection.privateKeyPEM
        }

        guard !connection.privateKeyPath.isEmpty else {
            return ""
        }

        return try String(contentsOfFile: connection.privateKeyPath, encoding: .utf8)
    }

    private func restoredStatus(from record: DeveloperConnectionRecord, privateKey: String) -> ConnectionStatus {
        guard !privateKey.isEmpty, record.lastCheckedAt != nil else {
            return .notVerified
        }

        return .verified(visibleAppCount: record.verifiedVisibleAppCount ?? 0)
    }
}

private struct DeveloperConnectionRecord: Codable {
    var id: UUID
    var name: String
    var keyID: String
    var issuerID: String
    var privateKeyPath: String
    var lastCheckedAt: Date?
    var verifiedVisibleAppCount: Int?
}

private extension DeveloperConnection {
    var verifiedVisibleAppCount: Int? {
        if case let .verified(visibleAppCount) = status {
            return visibleAppCount
        }

        return nil
    }
}

struct KeychainLLMProviderStore: LLMProviderPersisting {
    private let secretStore: any SecretStoring
    private let userDefaults: UserDefaults
    private let account = "default"

    init(
        secretStore: any SecretStoring = KeychainSecretStore(),
        userDefaults: UserDefaults = .standard
    ) {
        self.secretStore = secretStore
        self.userDefaults = userDefaults
    }

    func loadConfiguration() throws -> LLMProviderConfiguration? {
        guard let data = userDefaults.data(forKey: AppConstants.llmProviderDefaultsKey) else {
            return nil
        }

        let record = try JSONDecoder().decode(LLMProviderConfigurationRecord.self, from: data)
        let apiKey = try secretStore.read(
            account: account,
            service: AppConstants.keychainLLMAPIKeyService
        ) ?? ""

        return LLMProviderConfiguration(
            kind: record.kind,
            apiKey: apiKey,
            baseURL: record.baseURL,
            model: record.model,
            temperature: record.temperature,
            isEnabled: record.isEnabled
        )
    }

    func saveConfiguration(_ configuration: LLMProviderConfiguration) throws {
        if configuration.apiKey.isEmpty {
            try secretStore.delete(
                account: account,
                service: AppConstants.keychainLLMAPIKeyService
            )
        } else {
            try secretStore.save(
                configuration.apiKey,
                account: account,
                service: AppConstants.keychainLLMAPIKeyService
            )
        }

        let record = LLMProviderConfigurationRecord(
            kind: configuration.kind,
            baseURL: configuration.baseURL,
            model: configuration.model,
            temperature: configuration.temperature,
            isEnabled: configuration.isEnabled
        )
        let data = try JSONEncoder().encode(record)
        userDefaults.set(data, forKey: AppConstants.llmProviderDefaultsKey)
    }

    func deleteConfiguration() throws {
        try secretStore.delete(
            account: account,
            service: AppConstants.keychainLLMAPIKeyService
        )
        userDefaults.removeObject(forKey: AppConstants.llmProviderDefaultsKey)
    }
}

private struct LLMProviderConfigurationRecord: Codable {
    var kind: LLMProviderKind
    var baseURL: String
    var model: String
    var temperature: Double
    var isEnabled: Bool
}

struct KeychainSecretStore: SecretStoring {
    func save(_ value: String, account: String, service: String) throws {
        let data = Data(value.utf8)
        let query = baseQuery(account: account, service: service)

        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError(status: status)
        }
    }

    func read(account: String, service: String) throws -> String? {
        var query = baseQuery(account: account, service: service)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError(status: status)
        }

        return String(data: data, encoding: .utf8)
    }

    func delete(account: String, service: String) throws {
        let status = SecItemDelete(baseQuery(account: account, service: service) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    private func baseQuery(account: String, service: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service
        ]
    }
}

struct KeychainError: LocalizedError {
    var status: OSStatus

    var errorDescription: String? {
        if let message = SecCopyErrorMessageString(status, nil) as String? {
            return message
        }

        return "Keychain error \(status)."
    }
}
