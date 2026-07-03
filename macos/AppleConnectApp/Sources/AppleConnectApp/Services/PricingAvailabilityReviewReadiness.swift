import Foundation

enum PricingAvailabilityReviewReadiness {
    static func releaseItems(
        configuration: AppPricingAvailability?,
        issues: [PricingAvailabilityIssue]
    ) -> [ReleaseReadinessItem] {
        guard configuration != nil else {
            return [
                ReleaseReadinessItem(
                    level: .warning,
                    title: "Pricing not loaded",
                    detail: "Select an app and version before checking pricing and availability.",
                    systemImage: "tag"
                )
            ]
        }

        var items: [ReleaseReadinessItem] = []
        let blockingCount = issues.filter { $0.severity == .blocking }.count
        let warningCount = issues.filter { $0.severity == .warning }.count

        if blockingCount > 0 {
            items.append(
                ReleaseReadinessItem(
                    level: .blocking,
                    title: "Pricing and availability blockers",
                    detail: "\(blockingCount) commercial setup items must be resolved before submission.",
                    systemImage: "tag"
                )
            )
        }

        if warningCount > 0 {
            items.append(
                ReleaseReadinessItem(
                    level: .warning,
                    title: "Pricing and availability warnings",
                    detail: "\(warningCount) storefront settings should be reviewed before handoff.",
                    systemImage: "storefront"
                )
            )
        }

        return items
    }

    static func checklistItem(
        configuration: AppPricingAvailability?,
        issues: [PricingAvailabilityIssue]
    ) -> ReviewChecklistItem {
        guard let configuration else {
            return ReviewChecklistItem(
                level: .warning,
                title: "Pricing And Availability",
                detail: "No pricing and availability state is loaded for this version.",
                remediation: "Open Pricing and Availability after selecting a version.",
                systemImage: "tag",
                affectedLocales: [],
                affectedLabel: "Territories"
            )
        }

        let blockingCount = issues.filter { $0.severity == .blocking }.count
        if blockingCount > 0 {
            return ReviewChecklistItem(
                level: .blocking,
                title: "Pricing And Availability",
                detail: "\(blockingCount) pricing or storefront settings block release prep.",
                remediation: "Set the price, tax category, distribution method, and at least one available country or region.",
                systemImage: "tag",
                affectedLocales: affectedTerritories(for: issues, severity: .blocking),
                affectedLabel: "Territories"
            )
        }

        let warningCount = issues.filter { $0.severity == .warning }.count
        if warningCount > 0 {
            return ReviewChecklistItem(
                level: .warning,
                title: "Pricing And Availability",
                detail: "\(warningCount) pricing or storefront settings need review.",
                remediation: "Review limited availability, pre-order, education discount, and compatible platform options.",
                systemImage: "storefront",
                affectedLocales: affectedTerritories(for: issues, severity: .warning),
                affectedLabel: "Territories"
            )
        }

        return ReviewChecklistItem(
            level: .ready,
            title: "Pricing And Availability",
            detail: "\(configuration.priceDisplay) across \(configuration.customerVisibleTerritoryCount) storefronts.",
            remediation: "Confirm regional launch timing before final submission.",
            systemImage: "checkmark.circle",
            affectedLocales: configuration.territories.map(\.code),
            affectedLabel: "Territories"
        )
    }

    private static func affectedTerritories(
        for issues: [PricingAvailabilityIssue],
        severity: PricingAvailabilityIssueSeverity
    ) -> [String] {
        Array(Set(issues.filter { $0.severity == severity }.flatMap(\.affectedTerritories)))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}
