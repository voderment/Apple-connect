import Foundation

enum AppStoreCategory: String, CaseIterable, Identifiable, Codable, Hashable {
    case business
    case developerTools
    case education
    case entertainment
    case finance
    case games
    case healthFitness
    case lifestyle
    case photoVideo
    case productivity
    case socialNetworking
    case utilities

    var id: String { rawValue }

    var title: String {
        switch self {
        case .business:
            "Business"
        case .developerTools:
            "Developer Tools"
        case .education:
            "Education"
        case .entertainment:
            "Entertainment"
        case .finance:
            "Finance"
        case .games:
            "Games"
        case .healthFitness:
            "Health & Fitness"
        case .lifestyle:
            "Lifestyle"
        case .photoVideo:
            "Photo & Video"
        case .productivity:
            "Productivity"
        case .socialNetworking:
            "Social Networking"
        case .utilities:
            "Utilities"
        }
    }

    var systemImage: String {
        switch self {
        case .business:
            "briefcase"
        case .developerTools:
            "hammer"
        case .education:
            "graduationcap"
        case .entertainment:
            "sparkles.tv"
        case .finance:
            "chart.line.uptrend.xyaxis"
        case .games:
            "gamecontroller"
        case .healthFitness:
            "heart.text.square"
        case .lifestyle:
            "leaf"
        case .photoVideo:
            "photo.on.rectangle"
        case .productivity:
            "checklist"
        case .socialNetworking:
            "person.2"
        case .utilities:
            "wrench.and.screwdriver"
        }
    }
}

enum KidsAgeBand: String, CaseIterable, Identifiable, Codable {
    case fiveAndUnder
    case sixToEight
    case nineToEleven

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fiveAndUnder:
            "5 and under"
        case .sixToEight:
            "6-8"
        case .nineToEleven:
            "9-11"
        }
    }
}

enum AgeRatingFrequency: Int, CaseIterable, Identifiable, Codable, Comparable {
    case none = 0
    case infrequent = 1
    case frequent = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .none:
            "None"
        case .infrequent:
            "Infrequent"
        case .frequent:
            "Frequent"
        }
    }

    static func < (lhs: AgeRatingFrequency, rhs: AgeRatingFrequency) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum AgeRatingDescriptor: String, CaseIterable, Identifiable, Codable, Hashable {
    case cartoonViolence
    case realisticViolence
    case profanity
    case matureThemes
    case horrorFear
    case alcoholTobaccoDrugs
    case simulatedGambling
    case medicalTreatment

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cartoonViolence:
            "Cartoon or Fantasy Violence"
        case .realisticViolence:
            "Realistic Violence"
        case .profanity:
            "Profanity or Crude Humor"
        case .matureThemes:
            "Mature or Suggestive Themes"
        case .horrorFear:
            "Horror or Fear Themes"
        case .alcoholTobaccoDrugs:
            "Alcohol, Tobacco, or Drug References"
        case .simulatedGambling:
            "Simulated Gambling"
        case .medicalTreatment:
            "Medical or Treatment Information"
        }
    }

    var systemImage: String {
        switch self {
        case .cartoonViolence:
            "wand.and.stars"
        case .realisticViolence:
            "exclamationmark.shield"
        case .profanity:
            "text.bubble"
        case .matureThemes:
            "person.crop.rectangle.stack"
        case .horrorFear:
            "moon"
        case .alcoholTobaccoDrugs:
            "cross.case"
        case .simulatedGambling:
            "dice"
        case .medicalTreatment:
            "stethoscope"
        }
    }
}

struct AgeRatingResponse: Identifiable, Equatable, Codable {
    var descriptor: AgeRatingDescriptor
    var frequency: AgeRatingFrequency

    var id: AgeRatingDescriptor { descriptor }
}

struct AppRegionalCompliance: Equatable, Codable {
    var isAvailableInKorea: Bool
    var koreaRatingClassificationNumber: String
    var isAvailableInChinaMainland: Bool
    var chinaICPNumber: String
    var chinaGameApprovalNumber: String
    var containsThirdPartyContent: Bool
    var hasThirdPartyContentRights: Bool?
    var regionalNotes: String
}

struct AppRatingsCompliance: Equatable, Codable {
    var appID: String
    var versionID: String
    var primaryCategory: AppStoreCategory?
    var secondaryCategory: AppStoreCategory?
    var isMadeForKids: Bool
    var kidsAgeBand: KidsAgeBand?
    var isAgeQuestionnaireComplete: Bool
    var ageResponses: [AgeRatingResponse]
    var hasUnrestrictedWebAccess: Bool
    var hasUserGeneratedContent: Bool
    var hasLocationSharing: Bool
    var regionalCompliance: AppRegionalCompliance
    var updatedAt: Date

    var estimatedAppleAgeRating: String {
        RatingsComplianceValidator.estimatedAppleAgeRating(for: self)
    }

    func frequency(for descriptor: AgeRatingDescriptor) -> AgeRatingFrequency {
        ageResponses.first { $0.descriptor == descriptor }?.frequency ?? .none
    }
}

enum RatingsComplianceIssueSeverity: String, Codable {
    case blocking
    case warning
}

enum RatingsComplianceIssueArea: String, Codable {
    case category
    case ageRating
    case kids
    case regionalCompliance
    case contentRights

    var title: String {
        switch self {
        case .category:
            "Category"
        case .ageRating:
            "Age Rating"
        case .kids:
            "Kids"
        case .regionalCompliance:
            "Regional Compliance"
        case .contentRights:
            "Content Rights"
        }
    }
}

struct RatingsComplianceIssue: Identifiable, Equatable, Codable {
    var severity: RatingsComplianceIssueSeverity
    var area: RatingsComplianceIssueArea
    var title: String
    var detail: String

    var id: String {
        [severity.rawValue, area.rawValue, title, detail].joined(separator: "|")
    }
}

struct RatingsComplianceSummary: Equatable, Codable {
    var estimatedAgeRating: String
    var completedDescriptorCount: Int
    var totalDescriptorCount: Int
    var regionalItemCount: Int
    var blockingCount: Int
    var warningCount: Int

    var isReady: Bool {
        blockingCount == 0
    }
}

enum RatingsComplianceValidator {
    static func issues(for configuration: AppRatingsCompliance?) -> [RatingsComplianceIssue] {
        guard let configuration else {
            return [
                RatingsComplianceIssue(
                    severity: .warning,
                    area: .ageRating,
                    title: "Ratings not loaded",
                    detail: "Select an app and version before checking age ratings and regional compliance."
                )
            ]
        }

        var issues: [RatingsComplianceIssue] = []

        if configuration.primaryCategory == nil {
            issues.append(
                RatingsComplianceIssue(
                    severity: .blocking,
                    area: .category,
                    title: "Primary category missing",
                    detail: "Choose the App Store category that best describes this app."
                )
            )
        }

        if configuration.primaryCategory == configuration.secondaryCategory, configuration.secondaryCategory != nil {
            issues.append(
                RatingsComplianceIssue(
                    severity: .warning,
                    area: .category,
                    title: "Duplicate category",
                    detail: "Use a different secondary category or leave it empty."
                )
            )
        }

        if !configuration.isAgeQuestionnaireComplete {
            issues.append(
                RatingsComplianceIssue(
                    severity: .blocking,
                    area: .ageRating,
                    title: "Age rating questionnaire incomplete",
                    detail: "Complete the App Store Connect age rating questionnaire before submission."
                )
            )
        }

        appendKidsIssues(configuration, to: &issues)
        appendRegionalIssues(configuration, to: &issues)
        appendContentRightsIssues(configuration.regionalCompliance, to: &issues)

        return issues
    }

    static func summary(for configuration: AppRatingsCompliance?) -> RatingsComplianceSummary {
        let issues = issues(for: configuration)
        let responses = configuration?.ageResponses ?? []
        let regionalItemCount = regionalItemCount(for: configuration?.regionalCompliance)

        return RatingsComplianceSummary(
            estimatedAgeRating: configuration.map(estimatedAppleAgeRating(for:)) ?? "Not set",
            completedDescriptorCount: responses.filter { $0.frequency != .none }.count,
            totalDescriptorCount: AgeRatingDescriptor.allCases.count,
            regionalItemCount: regionalItemCount,
            blockingCount: issues.filter { $0.severity == .blocking }.count,
            warningCount: issues.filter { $0.severity == .warning }.count
        )
    }

    static func estimatedAppleAgeRating(for configuration: AppRatingsCompliance) -> String {
        let frequency = { (descriptor: AgeRatingDescriptor) in
            configuration.frequency(for: descriptor)
        }

        if frequency(.simulatedGambling) == .frequent
            || frequency(.realisticViolence) == .frequent
            || configuration.hasUnrestrictedWebAccess {
            return "17+"
        }

        if frequency(.realisticViolence) == .infrequent
            || frequency(.matureThemes) == .frequent
            || frequency(.alcoholTobaccoDrugs) == .frequent
            || frequency(.simulatedGambling) == .infrequent
            || configuration.hasUserGeneratedContent {
            return "12+"
        }

        if frequency(.cartoonViolence) == .infrequent
            || frequency(.cartoonViolence) == .frequent
            || frequency(.profanity) != .none
            || frequency(.horrorFear) != .none
            || frequency(.medicalTreatment) != .none {
            return "9+"
        }

        return "4+"
    }

    private static func appendKidsIssues(
        _ configuration: AppRatingsCompliance,
        to issues: inout [RatingsComplianceIssue]
    ) {
        guard configuration.isMadeForKids else {
            return
        }

        if configuration.kidsAgeBand == nil {
            issues.append(
                RatingsComplianceIssue(
                    severity: .blocking,
                    area: .kids,
                    title: "Kids age range missing",
                    detail: "Choose the Kids category age range before marking the app as Made for Kids."
                )
            )
        }

        if configuration.estimatedAppleAgeRating != "4+" {
            issues.append(
                RatingsComplianceIssue(
                    severity: .blocking,
                    area: .kids,
                    title: "Kids category conflicts with age rating",
                    detail: "Made for Kids apps should avoid content that raises the estimated Apple age rating."
                )
            )
        }

        if configuration.hasUnrestrictedWebAccess || configuration.hasUserGeneratedContent || configuration.hasLocationSharing {
            issues.append(
                RatingsComplianceIssue(
                    severity: .warning,
                    area: .kids,
                    title: "Kids safeguards need review",
                    detail: "Review unrestricted web access, user-generated content, and location-sharing controls for Kids guidelines."
                )
            )
        }
    }

    private static func appendRegionalIssues(
        _ configuration: AppRatingsCompliance,
        to issues: inout [RatingsComplianceIssue]
    ) {
        let regional = configuration.regionalCompliance
        let categories = [configuration.primaryCategory, configuration.secondaryCategory]
        let isGamesOrEntertainment = categories.contains(.games) || categories.contains(.entertainment)
        let isGame = categories.contains(.games)
        let hasMatureRegionalRisk = configuration.estimatedAppleAgeRating == "17+"
            || configuration.frequency(for: .simulatedGambling) == .frequent

        if regional.isAvailableInKorea, isGamesOrEntertainment, hasMatureRegionalRisk,
           regional.koreaRatingClassificationNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(
                RatingsComplianceIssue(
                    severity: .blocking,
                    area: .regionalCompliance,
                    title: "Korea rating number missing",
                    detail: "Games, entertainment, or simulated-gambling apps may need a GRAC rating classification number for Korea."
                )
            )
        }

        if regional.isAvailableInChinaMainland,
           configuration.hasUnrestrictedWebAccess,
           regional.chinaICPNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(
                RatingsComplianceIssue(
                    severity: .warning,
                    area: .regionalCompliance,
                    title: "China ICP filing missing",
                    detail: "Apps with network or web content may need a valid ICP filing number for China mainland availability."
                )
            )
        }

        if regional.isAvailableInChinaMainland, isGame,
           regional.chinaGameApprovalNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(
                RatingsComplianceIssue(
                    severity: .blocking,
                    area: .regionalCompliance,
                    title: "China game approval number missing",
                    detail: "Games distributed in China mainland need game approval information before release."
                )
            )
        }
    }

    private static func appendContentRightsIssues(
        _ regional: AppRegionalCompliance,
        to issues: inout [RatingsComplianceIssue]
    ) {
        guard regional.containsThirdPartyContent else {
            return
        }

        if regional.hasThirdPartyContentRights != true {
            issues.append(
                RatingsComplianceIssue(
                    severity: .blocking,
                    area: .contentRights,
                    title: "Third-party content rights not confirmed",
                    detail: "Confirm the app has rights to third-party content in every selected country or region."
                )
            )
        }
    }

    private static func regionalItemCount(for regional: AppRegionalCompliance?) -> Int {
        guard let regional else {
            return 0
        }

        var count = 0
        if regional.isAvailableInKorea {
            count += 1
        }
        if regional.isAvailableInChinaMainland {
            count += 1
        }
        if regional.containsThirdPartyContent {
            count += 1
        }
        return count
    }
}

enum MockRatingsComplianceFactory {
    static func configuration(
        app: ConnectApp?,
        version: AppStoreVersion?,
        isDemoMode: Bool
    ) -> AppRatingsCompliance {
        if isDemoMode, app?.id == "2234567890" {
            return reviewDemoConfiguration(app: app, version: version)
        }

        return polishedConfiguration(app: app, version: version)
    }

    private static func polishedConfiguration(
        app: ConnectApp?,
        version: AppStoreVersion?
    ) -> AppRatingsCompliance {
        AppRatingsCompliance(
            appID: app?.id ?? "demo-app",
            versionID: version?.id ?? "demo-version",
            primaryCategory: app?.primaryCategory.flatMap(categoryFromPrimaryCategory) ?? .developerTools,
            secondaryCategory: .productivity,
            isMadeForKids: false,
            kidsAgeBand: nil,
            isAgeQuestionnaireComplete: true,
            ageResponses: defaultResponses(),
            hasUnrestrictedWebAccess: false,
            hasUserGeneratedContent: false,
            hasLocationSharing: false,
            regionalCompliance: AppRegionalCompliance(
                isAvailableInKorea: true,
                koreaRatingClassificationNumber: "",
                isAvailableInChinaMainland: false,
                chinaICPNumber: "",
                chinaGameApprovalNumber: "",
                containsThirdPartyContent: false,
                hasThirdPartyContentRights: true,
                regionalNotes: ""
            ),
            updatedAt: .now
        )
    }

    private static func reviewDemoConfiguration(
        app: ConnectApp?,
        version: AppStoreVersion?
    ) -> AppRatingsCompliance {
        var responses = defaultResponses()
        set(.simulatedGambling, to: .frequent, in: &responses)
        set(.matureThemes, to: .infrequent, in: &responses)
        set(.profanity, to: .infrequent, in: &responses)

        return AppRatingsCompliance(
            appID: app?.id ?? "review-demo-app",
            versionID: version?.id ?? "review-demo-version",
            primaryCategory: .games,
            secondaryCategory: .games,
            isMadeForKids: true,
            kidsAgeBand: nil,
            isAgeQuestionnaireComplete: false,
            ageResponses: responses,
            hasUnrestrictedWebAccess: true,
            hasUserGeneratedContent: true,
            hasLocationSharing: false,
            regionalCompliance: AppRegionalCompliance(
                isAvailableInKorea: true,
                koreaRatingClassificationNumber: "",
                isAvailableInChinaMainland: true,
                chinaICPNumber: "",
                chinaGameApprovalNumber: "",
                containsThirdPartyContent: true,
                hasThirdPartyContentRights: nil,
                regionalNotes: "Demo app intentionally includes regional compliance gaps."
            ),
            updatedAt: .now
        )
    }

    private static func defaultResponses() -> [AgeRatingResponse] {
        AgeRatingDescriptor.allCases.map {
            AgeRatingResponse(descriptor: $0, frequency: .none)
        }
    }

    private static func set(
        _ descriptor: AgeRatingDescriptor,
        to frequency: AgeRatingFrequency,
        in responses: inout [AgeRatingResponse]
    ) {
        guard let index = responses.firstIndex(where: { $0.descriptor == descriptor }) else {
            return
        }

        responses[index].frequency = frequency
    }

    private static func categoryFromPrimaryCategory(_ value: String) -> AppStoreCategory? {
        AppStoreCategory.allCases.first {
            $0.rawValue.localizedCaseInsensitiveCompare(value) == .orderedSame
                || $0.title.localizedCaseInsensitiveCompare(value) == .orderedSame
        }
    }
}
