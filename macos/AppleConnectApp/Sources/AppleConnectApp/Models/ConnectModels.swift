import Foundation

struct UserSession: Codable, Equatable {
    var id: String
    var displayName: String?
    var email: String?
}

struct DeveloperConnection: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var keyID: String
    var issuerID: String
    var privateKeyPath: String
    var privateKeyPEM: String
    var status: ConnectionStatus
    var lastCheckedAt: Date?

    static let placeholder = DeveloperConnection(
        name: AppConstants.defaultConnectionName,
        keyID: "",
        issuerID: "",
        privateKeyPath: "",
        privateKeyPEM: "",
        status: .notVerified,
        lastCheckedAt: nil
    )

    static let demo = DeveloperConnection(
        name: "Demo Workspace",
        keyID: "DEMO-KEY-ID",
        issuerID: "DEMO-ISSUER-ID",
        privateKeyPath: "Built-in demo key",
        privateKeyPEM: "DEMO_PRIVATE_KEY",
        status: .notVerified,
        lastCheckedAt: nil
    )
}

enum ConnectionStatus: Codable, Equatable {
    case notVerified
    case verified(visibleAppCount: Int)
    case failed(message: String)
}

struct ConnectionCheckResult: Equatable {
    var visibleAppCount: Int
}

struct ConnectApp: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var bundleID: String
    var sku: String
    var primaryLocale: String
    var primaryCategory: String? = nil
    var iconURL: URL? = nil
}

struct AppStoreVersion: Identifiable, Hashable, Codable {
    var id: String
    var platform: String
    var versionString: String
    var appVersionState: String
    var appStoreState: String
    var createdDate: Date
}

struct AppInfoSummary: Identifiable, Hashable, Codable {
    var id: String
    var state: String
    var appStoreState: String
}

enum SidebarSelection: Hashable {
    case dashboard
    case connection
    case copyWorkspace
    case mediaAssets
    case pricingAvailability
    case appPrivacy
    case submissionSetup
    case ratingsCompliance
    case reviewPrep
    case llmSettings
    case settings
    case app(String)
}

enum RootScreen: Hashable {
    case home
    case appDetail
}

enum AppListViewMode: String, CaseIterable, Identifiable {
    case grid
    case list

    var id: String { rawValue }
}

enum AppDataSourceMode: String, CaseIterable, Identifiable, Codable {
    case live
    case demo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .live:
            "Live API"
        case .demo:
            "Demo"
        }
    }

    var detail: String {
        switch self {
        case .live:
            "App Store Connect"
        case .demo:
            "Sample workspace"
        }
    }

    var systemImage: String {
        switch self {
        case .live:
            "key"
        case .demo:
            "play.circle"
        }
    }
}

enum AppDetailSelection: Hashable {
    case overview
    case appInformation
    case localizedCopy
    case version(String)
}
