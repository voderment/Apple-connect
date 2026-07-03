import Foundation

@MainActor
struct MockAppStoreConnectService: AppStoreConnectServicing {
    func validateConnection(_ connection: DeveloperConnection) async throws -> ConnectionCheckResult {
        if connection.keyID.isEmpty || connection.issuerID.isEmpty || connection.privateKeyPath.isEmpty {
            throw ServiceError.missingCredentials
        }

        return ConnectionCheckResult(visibleAppCount: sampleApps.count)
    }

    func listApps(connection: DeveloperConnection) async throws -> [ConnectApp] {
        sampleApps
    }

    func listAppInfos(connection: DeveloperConnection, appID: String) async throws -> [AppInfoSummary] {
        [
            AppInfoSummary(
                id: "app-info-\(appID)-1",
                state: "PREPARE_FOR_SUBMISSION",
                appStoreState: "DEVELOPER_REMOVED_FROM_SALE"
            )
        ]
    }

    func listVersions(connection: DeveloperConnection, appID: String) async throws -> [AppStoreVersion] {
        [
            AppStoreVersion(
                id: "version-\(appID)-1",
                platform: "MAC_OS",
                versionString: "1.2.0",
                appVersionState: "PREPARE_FOR_SUBMISSION",
                appStoreState: "DEVELOPER_REMOVED_FROM_SALE",
                createdDate: .now.addingTimeInterval(-86_400 * 2)
            ),
            AppStoreVersion(
                id: "version-\(appID)-2",
                platform: "IOS",
                versionString: "1.1.0",
                appVersionState: "READY_FOR_SALE",
                appStoreState: "READY_FOR_SALE",
                createdDate: .now.addingTimeInterval(-86_400 * 28)
            )
        ]
    }

    func pullMetadata(
        connection: DeveloperConnection,
        appID: String,
        versionID: String
    ) async throws -> MetadataDocument {
        if appID == "2234567890" {
            return reviewDemoDocument
        }

        return polishedDemoDocument
    }

    func saveMetadata(
        connection: DeveloperConnection,
        appID: String,
        versionID: String,
        document: MetadataDocument,
        plan: MetadataPlan
    ) async throws -> MetadataSaveResult {
        MetadataSaveResult(appliedActionCount: plan.visibleActions.count)
    }

    private var polishedDemoDocument: MetadataDocument {
        MetadataDocument(
            localizations: [
                LocaleMetadata(
                    locale: "en-US",
                    appInfo: AppInfoMetadata(
                        name: AppConstants.productName,
                        subtitle: "App Store release workspace",
                        privacyPolicyURL: "https://example.com/privacy",
                        privacyChoicesURL: "",
                        privacyPolicyText: ""
                    ),
                    version: VersionMetadata(
                        description: "\(AppConstants.productName) helps developers manage App Store release information with a focused native workflow.",
                        keywords: "app store,metadata,release,localization,developer",
                        marketingURL: "https://example.com",
                        promotionalText: "Manage App Store release information in a focused native workspace.",
                        supportURL: "https://example.com/support",
                        whatsNew: "\(AppConstants.productName) now includes a first native metadata workspace."
                    )
                ),
                LocaleMetadata(
                    locale: "zh-Hans",
                    appInfo: AppInfoMetadata(
                        name: AppConstants.productName,
                        subtitle: "App Store 发布工作台",
                        privacyPolicyURL: "https://example.com/privacy",
                        privacyChoicesURL: "",
                        privacyPolicyText: ""
                    ),
                    version: VersionMetadata(
                        description: "\(AppConstants.productName) 帮助开发者用原生工作流管理 App Store 发布信息。",
                        keywords: "应用商店,元数据,发布,本地化,开发者",
                        marketingURL: "https://example.com",
                        promotionalText: "用专注的原生工作台管理 App Store 发布信息。",
                        supportURL: "https://example.com/support",
                        whatsNew: "\(AppConstants.productName) 现在包含第一个原生元数据工作台。"
                    )
                ),
                LocaleMetadata(
                    locale: "fr-FR",
                    appInfo: AppInfoMetadata(
                        name: AppConstants.productName,
                        subtitle: "Espace de publication App Store",
                        privacyPolicyURL: "https://example.com/privacy",
                        privacyChoicesURL: "",
                        privacyPolicyText: ""
                    ),
                    version: VersionMetadata(
                        description: "\(AppConstants.productName) aide les developpeurs a gerer les informations de publication App Store dans un espace natif.",
                        keywords: "app store,metadata,publication,localisation,developpeur",
                        marketingURL: "https://example.com",
                        promotionalText: "Gerez vos informations de publication App Store dans un espace natif.",
                        supportURL: "https://example.com/support",
                        whatsNew: "\(AppConstants.productName) inclut maintenant un premier espace natif pour les metadonnees."
                    )
                )
            ],
            pulledAt: .now
        )
    }

    private var reviewDemoDocument: MetadataDocument {
        MetadataDocument(
            localizations: [
                LocaleMetadata(
                    locale: "en-US",
                    appInfo: AppInfoMetadata(
                        name: "\(AppConstants.productName) Demo",
                        subtitle: "#1 guaranteed beta helper",
                        privacyPolicyURL: "https://example.com/privacy",
                        privacyChoicesURL: "https://example.com/privacy/choices",
                        privacyPolicyText: ""
                    ),
                    version: VersionMetadata(
                        description: "A realistic demo workspace with release notes, localization gaps, and review-readiness checks.",
                        keywords: "release; metadata\nreview,release,localization",
                        marketingURL: "http://example.com/demo",
                        promotionalText: "The #1 guaranteed beta workspace for App Store release teams.",
                        supportURL: "https://example.com/support",
                        whatsNew: "Beta review workflow, placeholder localization, and missing URL examples."
                    )
                ),
                LocaleMetadata(
                    locale: "ja",
                    appInfo: AppInfoMetadata(
                        name: "",
                        subtitle: "リリース管理",
                        privacyPolicyURL: "",
                        privacyChoicesURL: "",
                        privacyPolicyText: ""
                    ),
                    version: VersionMetadata(
                        description: "",
                        keywords: "",
                        marketingURL: "",
                        promotionalText: "",
                        supportURL: "",
                        whatsNew: ""
                    )
                ),
                LocaleMetadata(
                    locale: "es-MX",
                    appInfo: AppInfoMetadata(
                        name: "\(AppConstants.productName) Demo",
                        subtitle: "Workspace de lanzamientos",
                        privacyPolicyURL: "",
                        privacyChoicesURL: "",
                        privacyPolicyText: ""
                    ),
                    version: VersionMetadata(
                        description: "Lorem ipsum copy pending localization review.",
                        keywords: "release,metadata",
                        marketingURL: "https://example.mx",
                        promotionalText: "Gestiona metadatos antes de enviar la app.",
                        supportURL: "",
                        whatsNew: "TBD"
                    )
                ),
                LocaleMetadata(
                    locale: "de-DE",
                    appInfo: AppInfoMetadata(
                        name: "\(AppConstants.productName) Demo",
                        subtitle: "Release-Arbeitsbereich",
                        privacyPolicyURL: "https://example.com/privacy",
                        privacyChoicesURL: "",
                        privacyPolicyText: ""
                    ),
                    version: VersionMetadata(
                        description: "Verwalte App Store Metadaten mit einem ruhigen nativen Arbeitsbereich.",
                        keywords: "",
                        marketingURL: "",
                        promotionalText: "Bereite lokalisierte Metadaten vor.",
                        supportURL: "",
                        whatsNew: "Interne Testnotizen fuer QA build."
                    )
                )
            ],
            pulledAt: .now
        )
    }

    private var sampleApps: [ConnectApp] {
        [
            ConnectApp(
                id: "1234567890",
                name: AppConstants.productName,
                bundleID: AppConstants.bundleIdentifier,
                sku: "FACT-MAC",
                primaryLocale: "en-US"
            ),
            ConnectApp(
                id: "2234567890",
                name: "\(AppConstants.productName) Demo",
                bundleID: "com.example.appleconnect.demo",
                sku: "FACT-DEMO",
                primaryLocale: "en-US"
            )
        ]
    }
}
