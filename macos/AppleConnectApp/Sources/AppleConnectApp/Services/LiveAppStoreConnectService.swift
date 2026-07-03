import Foundation

@MainActor
struct LiveAppStoreConnectService: AppStoreConnectServicing {
    private var clientFactory: @MainActor (DeveloperConnection) throws -> AppStoreConnectAPIClient
    private var iconLookupClient: AppIconLookupClient

    init(
        clientFactory: @escaping @MainActor (DeveloperConnection) throws -> AppStoreConnectAPIClient = Self.makeClient,
        iconLookupClient: AppIconLookupClient = AppIconLookupClient()
    ) {
        self.clientFactory = clientFactory
        self.iconLookupClient = iconLookupClient
    }

    func validateConnection(_ connection: DeveloperConnection) async throws -> ConnectionCheckResult {
        let client = try clientFactory(connection)
        let apps = try await client.listApps()
        return ConnectionCheckResult(visibleAppCount: apps.count)
    }

    func listApps(connection: DeveloperConnection) async throws -> [ConnectApp] {
        let client = try clientFactory(connection)
        let apps = try await client.listApps()

        let connectApps = apps.map { resource in
            ConnectApp(
                id: resource.id,
                name: resource.attributes.name,
                bundleID: resource.attributes.bundleId,
                sku: resource.attributes.sku,
                primaryLocale: resource.attributes.primaryLocale
            )
        }

        let buildIconURLs = await buildIconURLsByAppID(client: client, appIDs: connectApps.map(\.id))
        let appsWithBuildIcons = connectApps.map { app in
            var enrichedApp = app
            enrichedApp.iconURL = buildIconURLs[app.id]
            return enrichedApp
        }

        return await iconLookupClient.applyingIconURLs(to: appsWithBuildIcons)
    }

    func listAppInfos(connection: DeveloperConnection, appID: String) async throws -> [AppInfoSummary] {
        let client = try clientFactory(connection)
        let appInfos = try await client.listAppInfos(appID: appID)

        return appInfos.map { resource in
            AppInfoSummary(
                id: resource.id,
                state: resource.attributes.state ?? "",
                appStoreState: resource.attributes.appStoreState ?? ""
            )
        }
    }

    func listVersions(connection: DeveloperConnection, appID: String) async throws -> [AppStoreVersion] {
        let client = try clientFactory(connection)
        let versions = try await client.listVersions(appID: appID)

        return versions.map { resource in
            AppStoreVersion(
                id: resource.id,
                platform: resource.attributes.platform,
                versionString: resource.attributes.versionString,
                appVersionState: resource.attributes.appVersionState,
                appStoreState: resource.attributes.appStoreState,
                createdDate: resource.attributes.createdDate
            )
        }
    }

    func pullMetadata(
        connection: DeveloperConnection,
        appID: String,
        versionID: String
    ) async throws -> MetadataDocument {
        let client = try clientFactory(connection)
        let appInfoID = try await resolveAppInfoID(client: client, appID: appID)
        let appInfoLocalizations = try await client.listAppInfoLocalizations(appInfoID: appInfoID)
        let versionLocalizations = try await client.listVersionLocalizations(versionID: versionID)

        var byLocale: [String: LocaleMetadata] = [:]

        for resource in appInfoLocalizations {
            let attributes = resource.attributes
            byLocale[attributes.locale] = LocaleMetadata(
                locale: attributes.locale,
                appInfo: AppInfoMetadata(
                    name: attributes.name ?? "",
                    subtitle: attributes.subtitle ?? "",
                    privacyPolicyURL: attributes.privacyPolicyUrl ?? "",
                    privacyChoicesURL: attributes.privacyChoicesUrl ?? "",
                    privacyPolicyText: attributes.privacyPolicyText ?? ""
                ),
                version: VersionMetadata(
                    description: "",
                    keywords: "",
                    marketingURL: "",
                    promotionalText: "",
                    supportURL: "",
                    whatsNew: ""
                )
            )
        }

        for resource in versionLocalizations {
            let attributes = resource.attributes
            var localization = byLocale[attributes.locale] ?? LocaleMetadata(
                locale: attributes.locale,
                appInfo: AppInfoMetadata(name: "", subtitle: "", privacyPolicyURL: "", privacyChoicesURL: "", privacyPolicyText: ""),
                version: VersionMetadata(description: "", keywords: "", marketingURL: "", promotionalText: "", supportURL: "", whatsNew: "")
            )

            localization.version = VersionMetadata(
                description: attributes.description ?? "",
                keywords: attributes.keywords ?? "",
                marketingURL: attributes.marketingUrl ?? "",
                promotionalText: attributes.promotionalText ?? "",
                supportURL: attributes.supportUrl ?? "",
                whatsNew: attributes.whatsNew ?? ""
            )
            byLocale[attributes.locale] = localization
        }

        return MetadataDocument(
            localizations: byLocale.values.sorted { $0.locale < $1.locale },
            pulledAt: .now
        )
    }

    func saveMetadata(
        connection: DeveloperConnection,
        appID: String,
        versionID: String,
        document: MetadataDocument,
        plan: MetadataPlan
    ) async throws -> MetadataSaveResult {
        guard !plan.hasBlockingIssues else {
            throw ServiceError.missingMetadata
        }

        let client = try clientFactory(connection)
        let appInfoID = try await resolveAppInfoID(client: client, appID: appID)
        let locales = document.localizations.map(\.locale)
        var existingAppInfo = Dictionary(
            uniqueKeysWithValues: try await client.listAppInfoLocalizations(appInfoID: appInfoID, locales: locales)
                .map { ($0.attributes.locale, $0) }
        )
        var existingVersion = Dictionary(
            uniqueKeysWithValues: try await client.listVersionLocalizations(versionID: versionID, locales: locales)
                .map { ($0.attributes.locale, $0) }
        )
        var appliedCount = 0

        for action in plan.visibleActions where action.resource == .appInfoLocalization {
            guard let localization = document.localizations.first(where: { $0.locale == action.locale }) else {
                continue
            }

            let attributes = appInfoRequestAttributes(
                locale: action.kind == .create ? action.locale : nil,
                value: localization.appInfo,
                fields: action.kind == .create ? nil : action.fields
            )

            if let existing = existingAppInfo[action.locale] {
                let response = try await client.updateAppInfoLocalization(
                    localizationID: existing.id,
                    attributes: attributes
                )
                existingAppInfo[action.locale] = response.data
            } else {
                let response = try await client.createAppInfoLocalization(
                    appInfoID: appInfoID,
                    attributes: attributes
                )
                existingAppInfo[action.locale] = response.data
            }
            appliedCount += 1
        }

        for action in plan.visibleActions where action.resource == .appStoreVersionLocalization {
            guard let localization = document.localizations.first(where: { $0.locale == action.locale }) else {
                continue
            }

            let attributes = versionRequestAttributes(
                locale: action.kind == .create ? action.locale : nil,
                value: localization.version,
                fields: action.kind == .create ? nil : action.fields
            )

            if let existing = existingVersion[action.locale] {
                let response = try await client.updateVersionLocalization(
                    localizationID: existing.id,
                    attributes: attributes
                )
                existingVersion[action.locale] = response.data
            } else {
                let response = try await client.createVersionLocalization(
                    versionID: versionID,
                    attributes: attributes
                )
                existingVersion[action.locale] = response.data
            }
            appliedCount += 1
        }

        return MetadataSaveResult(appliedActionCount: appliedCount)
    }

    private static func makeClient(connection: DeveloperConnection) throws -> AppStoreConnectAPIClient {
        let privateKey = try privateKeyValue(from: connection)
        let configuration = ASCAuthConfiguration(
            keyID: connection.keyID,
            issuerID: connection.issuerID,
            privateKeyPEM: privateKey
        )
        return AppStoreConnectAPIClient(tokenProvider: ASCJWTTokenProvider(configuration: configuration))
    }

    private static func privateKeyValue(from connection: DeveloperConnection) throws -> String {
        if !connection.privateKeyPEM.isEmpty {
            return connection.privateKeyPEM
        }

        guard !connection.privateKeyPath.isEmpty else {
            throw ServiceError.missingCredentials
        }

        return try String(contentsOfFile: connection.privateKeyPath, encoding: .utf8)
    }

    private func resolveAppInfoID(client: AppStoreConnectAPIClient, appID: String) async throws -> String {
        let appInfos = try await client.listAppInfos(appID: appID)
        guard !appInfos.isEmpty else {
            throw ServiceError.missingMetadata
        }

        return appInfos.first { $0.attributes.state == "PREPARE_FOR_SUBMISSION" }?.id ?? appInfos[0].id
    }

    private func buildIconURLsByAppID(client: AppStoreConnectAPIClient, appIDs: [String]) async -> [String: URL] {
        var iconURLs: [String: URL] = [:]

        for appID in appIDs {
            guard let builds = try? await client.listBuilds(appID: appID),
                  let iconURL = builds.compactMap(\.attributes.iconAssetToken?.resolvedURL).first else {
                continue
            }

            iconURLs[appID] = iconURL
        }

        return iconURLs
    }

    private func appInfoRequestAttributes(
        locale: String?,
        value: AppInfoMetadata,
        fields: [String]?
    ) -> ASCAppInfoLocalizationRequestAttributes {
        ASCAppInfoLocalizationRequestAttributes(
            locale: locale,
            name: include("name", fields) ? value.name : nil,
            subtitle: include("subtitle", fields) ? value.subtitle : nil,
            privacyPolicyUrl: include("privacyPolicyUrl", fields) ? value.privacyPolicyURL : nil,
            privacyChoicesUrl: include("privacyChoicesUrl", fields) ? value.privacyChoicesURL : nil,
            privacyPolicyText: include("privacyPolicyText", fields) ? value.privacyPolicyText : nil
        )
    }

    private func versionRequestAttributes(
        locale: String?,
        value: VersionMetadata,
        fields: [String]?
    ) -> ASCVersionLocalizationRequestAttributes {
        ASCVersionLocalizationRequestAttributes(
            locale: locale,
            description: include("description", fields) ? value.description : nil,
            keywords: include("keywords", fields) ? value.keywords : nil,
            marketingUrl: include("marketingUrl", fields) ? value.marketingURL : nil,
            promotionalText: include("promotionalText", fields) ? value.promotionalText : nil,
            supportUrl: include("supportUrl", fields) ? value.supportURL : nil,
            whatsNew: include("whatsNew", fields) ? value.whatsNew : nil
        )
    }

    private func include(_ field: String, _ fields: [String]?) -> Bool {
        fields?.contains(field) ?? true
    }
}
