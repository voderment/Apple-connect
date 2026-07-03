import Foundation

enum AppDistributionMethod: String, CaseIterable, Identifiable, Codable {
    case publicAppStore
    case privateBusiness
    case unlistedDirectLink

    var id: String { rawValue }

    var title: String {
        switch self {
        case .publicAppStore:
            "Public"
        case .privateBusiness:
            "Private"
        case .unlistedDirectLink:
            "Unlisted"
        }
    }

    var detail: String {
        switch self {
        case .publicAppStore:
            "Available on the App Store in selected countries or regions."
        case .privateBusiness:
            "Available only to selected Apple Business or School Manager organizations."
        case .unlistedDirectLink:
            "Public distribution with discoverability limited to a direct link."
        }
    }

    var systemImage: String {
        switch self {
        case .publicAppStore:
            "storefront"
        case .privateBusiness:
            "building.2"
        case .unlistedDirectLink:
            "link"
        }
    }
}

enum StorefrontAvailabilityStatus: String, CaseIterable, Identifiable, Codable {
    case available
    case unavailable
    case preOrder

    var id: String { rawValue }

    var title: String {
        switch self {
        case .available:
            "Available"
        case .unavailable:
            "Unavailable"
        case .preOrder:
            "Pre-Order"
        }
    }

    var isCustomerVisible: Bool {
        self == .available || self == .preOrder
    }
}

struct TerritoryAvailability: Identifiable, Equatable, Codable {
    var code: String
    var name: String
    var status: StorefrontAvailabilityStatus
    var note: String

    var id: String { code }
}

struct AppPricingAvailability: Equatable, Codable {
    var appID: String
    var versionID: String
    var distributionMethod: AppDistributionMethod
    var priceTier: String
    var customerPrice: String
    var currency: String
    var proceeds: String
    var baseTerritoryCode: String
    var taxCategory: String
    var isPreOrderEnabled: Bool
    var preOrderReleaseDate: Date?
    var isPhasedReleaseEnabled: Bool
    var isEducationDiscountEnabled: Bool
    var isAppleSiliconMacAvailable: Bool
    var privateOrganizationCount: Int
    var territories: [TerritoryAvailability]

    var priceDisplay: String {
        priceTier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Not set" : "\(priceTier) · \(customerPrice) \(currency)"
    }

    var baseTerritoryName: String {
        territories.first { $0.code == baseTerritoryCode }?.name ?? baseTerritoryCode
    }

    var availableTerritoryCount: Int {
        territories.filter { $0.status == .available }.count
    }

    var territoryCount: Int {
        territories.count
    }

    var preOrderTerritoryCount: Int {
        territories.filter { $0.status == .preOrder }.count
    }

    var unavailableTerritoryCount: Int {
        territories.filter { $0.status == .unavailable }.count
    }

    var customerVisibleTerritoryCount: Int {
        territories.filter(\.status.isCustomerVisible).count
    }
}

enum PricingAvailabilityIssueSeverity: String, Codable {
    case blocking
    case warning
}

struct PricingAvailabilityIssue: Identifiable, Equatable, Codable {
    var severity: PricingAvailabilityIssueSeverity
    var title: String
    var detail: String
    var affectedTerritories: [String]

    var id: String {
        [severity.rawValue, title, detail, affectedTerritories.joined(separator: ",")].joined(separator: "|")
    }
}

struct PricingAvailabilitySummary: Equatable, Codable {
    var territoryCount: Int
    var customerVisibleTerritoryCount: Int
    var unavailableTerritoryCount: Int
    var preOrderTerritoryCount: Int
    var blockingCount: Int
    var warningCount: Int

    var isReady: Bool {
        blockingCount == 0
    }
}

enum PricingAvailabilityValidator {
    static func issues(for configuration: AppPricingAvailability?) -> [PricingAvailabilityIssue] {
        guard let configuration else {
            return [
                PricingAvailabilityIssue(
                    severity: .warning,
                    title: "Pricing not loaded",
                    detail: "Select an app and version before checking pricing and availability.",
                    affectedTerritories: []
                )
            ]
        }

        var issues: [PricingAvailabilityIssue] = []

        if configuration.priceTier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(
                PricingAvailabilityIssue(
                    severity: .blocking,
                    title: "Price not set",
                    detail: "Set an app price before preparing the version for submission.",
                    affectedTerritories: []
                )
            )
        }

        if configuration.taxCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(
                PricingAvailabilityIssue(
                    severity: .blocking,
                    title: "Tax category not set",
                    detail: "Choose the app's tax category before submission.",
                    affectedTerritories: []
                )
            )
        }

        if configuration.customerVisibleTerritoryCount == 0 {
            issues.append(
                PricingAvailabilityIssue(
                    severity: .blocking,
                    title: "No available territories",
                    detail: "Make the app available in at least one country or region.",
                    affectedTerritories: configuration.territories.map(\.code)
                )
            )
        }

        if configuration.distributionMethod == .privateBusiness, configuration.privateOrganizationCount == 0 {
            issues.append(
                PricingAvailabilityIssue(
                    severity: .blocking,
                    title: "No private organizations",
                    detail: "Private distribution needs at least one Apple Business or School Manager organization.",
                    affectedTerritories: []
                )
            )
        }

        if configuration.isPreOrderEnabled, configuration.preOrderReleaseDate == nil {
            issues.append(
                PricingAvailabilityIssue(
                    severity: .blocking,
                    title: "Pre-order date missing",
                    detail: "Choose a release date for the active pre-order.",
                    affectedTerritories: configuration.territories
                        .filter { $0.status == .preOrder }
                        .map(\.code)
                )
            )
        }

        if configuration.customerVisibleTerritoryCount > 0, configuration.customerVisibleTerritoryCount < max(2, configuration.territories.count / 2) {
            issues.append(
                PricingAvailabilityIssue(
                    severity: .warning,
                    title: "Limited storefront coverage",
                    detail: "\(configuration.customerVisibleTerritoryCount) of \(configuration.territoryCount) configured storefronts are customer-visible.",
                    affectedTerritories: configuration.territories
                        .filter(\.status.isCustomerVisible)
                        .map(\.code)
                )
            )
        }

        if !configuration.isAppleSiliconMacAvailable, configuration.distributionMethod != .privateBusiness {
            issues.append(
                PricingAvailabilityIssue(
                    severity: .warning,
                    title: "Apple Silicon Mac opted out",
                    detail: "Review whether this app should be available on Mac for compatible iPhone and iPad customers.",
                    affectedTerritories: []
                )
            )
        }

        if configuration.isEducationDiscountEnabled && configuration.customerPrice == "0.00" {
            issues.append(
                PricingAvailabilityIssue(
                    severity: .warning,
                    title: "Education discount unnecessary",
                    detail: "The app is free, so the reduced education price has no customer impact.",
                    affectedTerritories: []
                )
            )
        }

        return issues
    }

    static func summary(for configuration: AppPricingAvailability?) -> PricingAvailabilitySummary {
        guard let configuration else {
            return PricingAvailabilitySummary(
                territoryCount: 0,
                customerVisibleTerritoryCount: 0,
                unavailableTerritoryCount: 0,
                preOrderTerritoryCount: 0,
                blockingCount: 0,
                warningCount: 1
            )
        }

        let issues = issues(for: configuration)
        return PricingAvailabilitySummary(
            territoryCount: configuration.territories.count,
            customerVisibleTerritoryCount: configuration.customerVisibleTerritoryCount,
            unavailableTerritoryCount: configuration.unavailableTerritoryCount,
            preOrderTerritoryCount: configuration.preOrderTerritoryCount,
            blockingCount: issues.filter { $0.severity == .blocking }.count,
            warningCount: issues.filter { $0.severity == .warning }.count
        )
    }
}

enum MockPricingAvailabilityFactory {
    static func configuration(
        app: ConnectApp?,
        version: AppStoreVersion?,
        isDemoMode: Bool
    ) -> AppPricingAvailability? {
        guard let version else {
            return nil
        }

        if isDemoMode, app?.id == "2234567890" {
            return reviewDemoConfiguration(appID: app?.id ?? "demo-app", version: version)
        }

        return polishedConfiguration(appID: app?.id ?? "selected-app", version: version)
    }

    private static func polishedConfiguration(appID: String, version: AppStoreVersion) -> AppPricingAvailability {
        AppPricingAvailability(
            appID: appID,
            versionID: version.id,
            distributionMethod: .publicAppStore,
            priceTier: "Free",
            customerPrice: "0.00",
            currency: "USD",
            proceeds: "0.00",
            baseTerritoryCode: "US",
            taxCategory: "Software",
            isPreOrderEnabled: false,
            preOrderReleaseDate: nil,
            isPhasedReleaseEnabled: true,
            isEducationDiscountEnabled: false,
            isAppleSiliconMacAvailable: true,
            privateOrganizationCount: 0,
            territories: standardTerritories(status: .available)
        )
    }

    private static func reviewDemoConfiguration(appID: String, version: AppStoreVersion) -> AppPricingAvailability {
        AppPricingAvailability(
            appID: appID,
            versionID: version.id,
            distributionMethod: .publicAppStore,
            priceTier: "",
            customerPrice: "0.00",
            currency: "USD",
            proceeds: "0.00",
            baseTerritoryCode: "US",
            taxCategory: "",
            isPreOrderEnabled: true,
            preOrderReleaseDate: nil,
            isPhasedReleaseEnabled: false,
            isEducationDiscountEnabled: true,
            isAppleSiliconMacAvailable: false,
            privateOrganizationCount: 0,
            territories: [
                TerritoryAvailability(code: "US", name: "United States", status: .available, note: "Primary launch storefront"),
                TerritoryAvailability(code: "CA", name: "Canada", status: .preOrder, note: "Waiting for release date"),
                TerritoryAvailability(code: "GB", name: "United Kingdom", status: .unavailable, note: "Pending legal copy review"),
                TerritoryAvailability(code: "JP", name: "Japan", status: .unavailable, note: "Localization incomplete"),
                TerritoryAvailability(code: "DE", name: "Germany", status: .unavailable, note: "Support URL missing"),
                TerritoryAvailability(code: "AU", name: "Australia", status: .unavailable, note: "Launch decision pending")
            ]
        )
    }

    private static func standardTerritories(status: StorefrontAvailabilityStatus) -> [TerritoryAvailability] {
        [
            TerritoryAvailability(code: "US", name: "United States", status: status, note: "Primary storefront"),
            TerritoryAvailability(code: "CA", name: "Canada", status: status, note: ""),
            TerritoryAvailability(code: "GB", name: "United Kingdom", status: status, note: ""),
            TerritoryAvailability(code: "JP", name: "Japan", status: status, note: ""),
            TerritoryAvailability(code: "DE", name: "Germany", status: status, note: ""),
            TerritoryAvailability(code: "AU", name: "Australia", status: status, note: "")
        ]
    }
}
