import Foundation

enum AppConstants {
    static let productName = "Fact"
    static let bundleIdentifier = "com.infinity.factory.mac"
    static let appGroupIdentifier = "group.com.infinity.factory.mac"
    static let defaultConnectionName = "Infinity Factory"
    static let themeDefaultsKey = "\(bundleIdentifier).theme"
    static let languageDefaultsKey = "\(bundleIdentifier).language"
    static let dataSourceDefaultsKey = "\(bundleIdentifier).data-source"
    static let userSessionDefaultsKey = "\(bundleIdentifier).user-session"
    static let connectionDefaultsKey = "\(bundleIdentifier).app-store-connect.connection"
    static let llmProviderDefaultsKey = "\(bundleIdentifier).llm-provider.configuration"
    static let keychainPrivateKeyService = "\(bundleIdentifier).app-store-connect.private-key"
    static let keychainLLMAPIKeyService = "\(bundleIdentifier).llm-provider.api-key"
}
