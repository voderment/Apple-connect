import Foundation

enum RatingsComplianceReviewReadiness {
    static func releaseItems(
        configuration: AppRatingsCompliance?,
        issues: [RatingsComplianceIssue]
    ) -> [ReleaseReadinessItem] {
        guard configuration != nil else {
            return [
                ReleaseReadinessItem(
                    level: .warning,
                    title: "Ratings and compliance not loaded",
                    detail: "Select an app and version before checking age rating and regional compliance.",
                    systemImage: "shield.lefthalf.filled"
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
                    title: "Ratings and compliance blockers",
                    detail: "\(blockingCount) App Information settings must be resolved before submission.",
                    systemImage: "shield.lefthalf.filled"
                )
            )
        }

        if warningCount > 0 {
            items.append(
                ReleaseReadinessItem(
                    level: .warning,
                    title: "Ratings and compliance review",
                    detail: "\(warningCount) App Information or regional settings should be reviewed.",
                    systemImage: "globe.badge.chevron.backward"
                )
            )
        }

        return items
    }

    static func checklistItem(
        configuration: AppRatingsCompliance?,
        issues: [RatingsComplianceIssue]
    ) -> ReviewChecklistItem {
        guard let configuration else {
            return ReviewChecklistItem(
                level: .warning,
                title: "Ratings And Compliance",
                detail: "No age rating or regional compliance state is loaded.",
                remediation: "Open Ratings and Compliance after selecting a version.",
                systemImage: "shield.lefthalf.filled",
                affectedLocales: [],
                affectedLabel: "Items"
            )
        }

        let blockingCount = issues.filter { $0.severity == .blocking }.count
        if blockingCount > 0 {
            return ReviewChecklistItem(
                level: .blocking,
                title: "Ratings And Compliance",
                detail: "\(blockingCount) rating or compliance items block release prep.",
                remediation: "Complete age rating, category, Kids, and region-specific compliance fields.",
                systemImage: "shield.lefthalf.filled",
                affectedLocales: affectedAreas(for: issues, severity: .blocking),
                affectedLabel: "Items"
            )
        }

        let warningCount = issues.filter { $0.severity == .warning }.count
        if warningCount > 0 {
            return ReviewChecklistItem(
                level: .warning,
                title: "Ratings And Compliance",
                detail: "\(warningCount) rating or regional compliance items need review.",
                remediation: "Review Kids safeguards, regional availability, and content-rights notes before handoff.",
                systemImage: "globe.badge.chevron.backward",
                affectedLocales: affectedAreas(for: issues, severity: .warning),
                affectedLabel: "Items"
            )
        }

        return ReviewChecklistItem(
            level: .ready,
            title: "Ratings And Compliance",
            detail: "Estimated Apple age rating \(configuration.estimatedAppleAgeRating) with required App Information present.",
            remediation: "Confirm the final App Store Connect questionnaire matches the submitted binary.",
            systemImage: "checkmark.circle",
            affectedLocales: ["Age Rating", "Category", "Regional Compliance"],
            affectedLabel: "Items"
        )
    }

    private static func affectedAreas(
        for issues: [RatingsComplianceIssue],
        severity: RatingsComplianceIssueSeverity
    ) -> [String] {
        Array(Set(issues.filter { $0.severity == severity }.map { $0.area.title }))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}
