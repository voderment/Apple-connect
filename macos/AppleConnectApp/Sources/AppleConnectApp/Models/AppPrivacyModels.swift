import Foundation

enum AppPrivacyDataType: String, CaseIterable, Identifiable, Codable, Hashable {
    case contactInfo
    case healthFitness
    case financialInfo
    case location
    case sensitiveInfo
    case contacts
    case userContent
    case browsingHistory
    case searchHistory
    case identifiers
    case purchases
    case usageData
    case diagnostics
    case otherData

    var id: String { rawValue }

    var title: String {
        switch self {
        case .contactInfo:
            "Contact Info"
        case .healthFitness:
            "Health & Fitness"
        case .financialInfo:
            "Financial Info"
        case .location:
            "Location"
        case .sensitiveInfo:
            "Sensitive Info"
        case .contacts:
            "Contacts"
        case .userContent:
            "User Content"
        case .browsingHistory:
            "Browsing History"
        case .searchHistory:
            "Search History"
        case .identifiers:
            "Identifiers"
        case .purchases:
            "Purchases"
        case .usageData:
            "Usage Data"
        case .diagnostics:
            "Diagnostics"
        case .otherData:
            "Other Data"
        }
    }

    var systemImage: String {
        switch self {
        case .contactInfo:
            "person.text.rectangle"
        case .healthFitness:
            "heart.text.square"
        case .financialInfo:
            "creditcard"
        case .location:
            "location"
        case .sensitiveInfo:
            "lock.shield"
        case .contacts:
            "person.2"
        case .userContent:
            "doc.text"
        case .browsingHistory:
            "safari"
        case .searchHistory:
            "magnifyingglass"
        case .identifiers:
            "number"
        case .purchases:
            "cart"
        case .usageData:
            "chart.xyaxis.line"
        case .diagnostics:
            "stethoscope"
        case .otherData:
            "ellipsis.circle"
        }
    }
}

enum AppPrivacyPurpose: String, CaseIterable, Identifiable, Codable, Hashable {
    case thirdPartyAdvertising
    case developerAdvertising
    case analytics
    case productPersonalization
    case appFunctionality
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .thirdPartyAdvertising:
            "Third-Party Advertising"
        case .developerAdvertising:
            "Developer Advertising"
        case .analytics:
            "Analytics"
        case .productPersonalization:
            "Product Personalization"
        case .appFunctionality:
            "App Functionality"
        case .other:
            "Other Purposes"
        }
    }
}

struct AppPrivacyDataDisclosure: Identifiable, Equatable, Codable {
    var dataType: AppPrivacyDataType
    var purposes: Set<AppPrivacyPurpose>
    var isLinkedToUser: Bool
    var isUsedForTracking: Bool
    var note: String

    var id: AppPrivacyDataType { dataType }

    var purposeSummary: String {
        guard !purposes.isEmpty else {
            return "No purposes"
        }

        return purposes
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            .map(\.title)
            .joined(separator: ", ")
    }
}

struct AppPrivacyDisclosure: Equatable, Codable {
    var appID: String
    var versionID: String
    var privacyPolicyURL: String
    var privacyChoicesURL: String
    var appleTVPrivacyPolicyText: String
    var doesCollectData: Bool
    var dataDisclosures: [AppPrivacyDataDisclosure]
    var lastPublishedAt: Date?

    var dataTypeCount: Int {
        dataDisclosures.count
    }

    var linkedDataTypeCount: Int {
        dataDisclosures.filter(\.isLinkedToUser).count
    }

    var trackingDataTypeCount: Int {
        dataDisclosures.filter(\.isUsedForTracking).count
    }

    func disclosure(for dataType: AppPrivacyDataType) -> AppPrivacyDataDisclosure? {
        dataDisclosures.first { $0.dataType == dataType }
    }
}

enum AppPrivacyIssueSeverity: String, Codable {
    case blocking
    case warning
}

struct AppPrivacyIssue: Identifiable, Equatable, Codable {
    var severity: AppPrivacyIssueSeverity
    var title: String
    var detail: String
    var affectedDataTypes: [AppPrivacyDataType]

    var id: String {
        [
            severity.rawValue,
            title,
            detail,
            affectedDataTypes.map(\.rawValue).joined(separator: ",")
        ].joined(separator: "|")
    }
}

struct AppPrivacySummary: Equatable, Codable {
    var dataTypeCount: Int
    var linkedDataTypeCount: Int
    var trackingDataTypeCount: Int
    var blockingCount: Int
    var warningCount: Int

    var isReady: Bool {
        blockingCount == 0
    }
}

enum AppPrivacyValidator {
    static func issues(for disclosure: AppPrivacyDisclosure?) -> [AppPrivacyIssue] {
        guard let disclosure else {
            return [
                AppPrivacyIssue(
                    severity: .warning,
                    title: "App privacy not loaded",
                    detail: "Select an app and version before checking App Privacy responses.",
                    affectedDataTypes: []
                )
            ]
        }

        var issues: [AppPrivacyIssue] = []
        let policyURL = disclosure.privacyPolicyURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let choicesURL = disclosure.privacyChoicesURL.trimmingCharacters(in: .whitespacesAndNewlines)

        if policyURL.isEmpty {
            issues.append(
                AppPrivacyIssue(
                    severity: .blocking,
                    title: "Privacy policy URL missing",
                    detail: "A public privacy policy URL is required before publishing privacy responses.",
                    affectedDataTypes: []
                )
            )
        } else if !isHTTPURL(policyURL) {
            issues.append(
                AppPrivacyIssue(
                    severity: .blocking,
                    title: "Privacy policy URL invalid",
                    detail: "Use a complete http(s) URL for the app privacy policy.",
                    affectedDataTypes: []
                )
            )
        } else if !isHTTPSURL(policyURL) {
            issues.append(
                AppPrivacyIssue(
                    severity: .warning,
                    title: "Privacy policy is not HTTPS",
                    detail: "Prefer an https:// privacy policy URL before publication.",
                    affectedDataTypes: []
                )
            )
        }

        if !choicesURL.isEmpty, !isHTTPURL(choicesURL) {
            issues.append(
                AppPrivacyIssue(
                    severity: .blocking,
                    title: "Privacy choices URL invalid",
                    detail: "Use a complete http(s) URL for user privacy choices.",
                    affectedDataTypes: []
                )
            )
        }

        if disclosure.doesCollectData, disclosure.dataDisclosures.isEmpty {
            issues.append(
                AppPrivacyIssue(
                    severity: .blocking,
                    title: "No data types selected",
                    detail: "Select every data type collected by the app or third-party partners.",
                    affectedDataTypes: []
                )
            )
        }

        if !disclosure.doesCollectData, !disclosure.dataDisclosures.isEmpty {
            issues.append(
                AppPrivacyIssue(
                    severity: .warning,
                    title: "Collection answer mismatch",
                    detail: "The app is marked as not collecting data but still has selected data types.",
                    affectedDataTypes: disclosure.dataDisclosures.map(\.dataType)
                )
            )
        }

        let incompleteTypes = disclosure.dataDisclosures
            .filter { $0.purposes.isEmpty }
            .map(\.dataType)
        if !incompleteTypes.isEmpty {
            issues.append(
                AppPrivacyIssue(
                    severity: .blocking,
                    title: "Data type purposes missing",
                    detail: "Each selected data type needs at least one collection purpose.",
                    affectedDataTypes: incompleteTypes
                )
            )
        }

        let trackingTypes = disclosure.dataDisclosures
            .filter(\.isUsedForTracking)
            .map(\.dataType)
        if !trackingTypes.isEmpty, choicesURL.isEmpty {
            issues.append(
                AppPrivacyIssue(
                    severity: .warning,
                    title: "Tracking without choices URL",
                    detail: "Add a user privacy choices URL when responses disclose tracking.",
                    affectedDataTypes: trackingTypes
                )
            )
        }

        let linkedTrackingTypes = disclosure.dataDisclosures
            .filter { $0.isLinkedToUser && $0.isUsedForTracking }
            .map(\.dataType)
        if !linkedTrackingTypes.isEmpty {
            issues.append(
                AppPrivacyIssue(
                    severity: .warning,
                    title: "Linked tracking data",
                    detail: "Review linked tracking responses carefully before publishing.",
                    affectedDataTypes: linkedTrackingTypes
                )
            )
        }

        return issues
    }

    static func summary(for disclosure: AppPrivacyDisclosure?) -> AppPrivacySummary {
        guard let disclosure else {
            return AppPrivacySummary(
                dataTypeCount: 0,
                linkedDataTypeCount: 0,
                trackingDataTypeCount: 0,
                blockingCount: 0,
                warningCount: 1
            )
        }

        let issues = issues(for: disclosure)
        return AppPrivacySummary(
            dataTypeCount: disclosure.dataTypeCount,
            linkedDataTypeCount: disclosure.linkedDataTypeCount,
            trackingDataTypeCount: disclosure.trackingDataTypeCount,
            blockingCount: issues.filter { $0.severity == .blocking }.count,
            warningCount: issues.filter { $0.severity == .warning }.count
        )
    }

    private static func isHTTPURL(_ value: String) -> Bool {
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              components.host?.isEmpty == false else {
            return false
        }

        return true
    }

    private static func isHTTPSURL(_ value: String) -> Bool {
        URLComponents(string: value)?.scheme?.lowercased() == "https"
    }
}

enum MockAppPrivacyFactory {
    static func disclosure(
        app: ConnectApp?,
        version: AppStoreVersion?,
        document: MetadataDocument?,
        isDemoMode: Bool
    ) -> AppPrivacyDisclosure? {
        guard let version else {
            return nil
        }

        if isDemoMode, app?.id == "2234567890" {
            return reviewDemoDisclosure(appID: app?.id ?? "demo-app", version: version, document: document)
        }

        return polishedDisclosure(appID: app?.id ?? "selected-app", version: version, document: document)
    }

    private static func polishedDisclosure(
        appID: String,
        version: AppStoreVersion,
        document: MetadataDocument?
    ) -> AppPrivacyDisclosure {
        AppPrivacyDisclosure(
            appID: appID,
            versionID: version.id,
            privacyPolicyURL: firstPrivacyPolicyURL(in: document, fallback: "https://example.com/privacy"),
            privacyChoicesURL: firstPrivacyChoicesURL(in: document, fallback: "https://example.com/privacy/choices"),
            appleTVPrivacyPolicyText: "",
            doesCollectData: true,
            dataDisclosures: [
                AppPrivacyDataDisclosure(
                    dataType: .diagnostics,
                    purposes: [.analytics, .appFunctionality],
                    isLinkedToUser: false,
                    isUsedForTracking: false,
                    note: "Crash logs and performance diagnostics."
                ),
                AppPrivacyDataDisclosure(
                    dataType: .usageData,
                    purposes: [.analytics],
                    isLinkedToUser: false,
                    isUsedForTracking: false,
                    note: "Aggregated feature usage for product improvement."
                )
            ],
            lastPublishedAt: .now
        )
    }

    private static func reviewDemoDisclosure(
        appID: String,
        version: AppStoreVersion,
        document: MetadataDocument?
    ) -> AppPrivacyDisclosure {
        AppPrivacyDisclosure(
            appID: appID,
            versionID: version.id,
            privacyPolicyURL: firstPrivacyPolicyURL(in: document, fallback: "http://example.com/privacy"),
            privacyChoicesURL: "",
            appleTVPrivacyPolicyText: "",
            doesCollectData: true,
            dataDisclosures: [
                AppPrivacyDataDisclosure(
                    dataType: .identifiers,
                    purposes: [],
                    isLinkedToUser: true,
                    isUsedForTracking: true,
                    note: "Advertising identifier usage needs confirmation."
                ),
                AppPrivacyDataDisclosure(
                    dataType: .diagnostics,
                    purposes: [.analytics],
                    isLinkedToUser: false,
                    isUsedForTracking: false,
                    note: "Crash reports and launch diagnostics."
                ),
                AppPrivacyDataDisclosure(
                    dataType: .userContent,
                    purposes: [.appFunctionality],
                    isLinkedToUser: true,
                    isUsedForTracking: false,
                    note: "Clipboard snippets and generated drafts stay customer-visible."
                )
            ],
            lastPublishedAt: nil
        )
    }

    private static func firstPrivacyPolicyURL(in document: MetadataDocument?, fallback: String) -> String {
        firstNonEmptyURL(document?.localizations.map(\.appInfo.privacyPolicyURL) ?? []) ?? fallback
    }

    private static func firstPrivacyChoicesURL(in document: MetadataDocument?, fallback: String) -> String {
        firstNonEmptyURL(document?.localizations.map(\.appInfo.privacyChoicesURL) ?? []) ?? fallback
    }

    private static func firstNonEmptyURL(_ values: [String]) -> String? {
        values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}
