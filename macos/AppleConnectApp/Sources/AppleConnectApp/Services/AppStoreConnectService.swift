import Foundation

@MainActor
protocol AppStoreConnectServicing {
    func validateConnection(_ connection: DeveloperConnection) async throws -> ConnectionCheckResult
    func listApps(connection: DeveloperConnection) async throws -> [ConnectApp]
    func listAppInfos(connection: DeveloperConnection, appID: String) async throws -> [AppInfoSummary]
    func listVersions(connection: DeveloperConnection, appID: String) async throws -> [AppStoreVersion]
    func pullMetadata(
        connection: DeveloperConnection,
        appID: String,
        versionID: String
    ) async throws -> MetadataDocument
    func saveMetadata(
        connection: DeveloperConnection,
        appID: String,
        versionID: String,
        document: MetadataDocument,
        plan: MetadataPlan
    ) async throws -> MetadataSaveResult
}

struct MetadataSaveResult: Equatable {
    var appliedActionCount: Int
}

enum ServiceError: LocalizedError {
    case missingCredentials
    case missingMetadata

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            String(localized: "Add an App Store Connect API key before validating the connection.")
        case .missingMetadata:
            String(localized: "No metadata document is loaded.")
        }
    }
}
