import Foundation

enum AppPrivacyReviewReadiness {
    static func releaseItems(
        disclosure: AppPrivacyDisclosure?,
        issues: [AppPrivacyIssue]
    ) -> [ReleaseReadinessItem] {
        guard disclosure != nil else {
            return [
                ReleaseReadinessItem(
                    level: .warning,
                    title: "App privacy not loaded",
                    detail: "Select an app and version before checking privacy responses.",
                    systemImage: "hand.raised"
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
                    title: "App privacy blockers",
                    detail: "\(blockingCount) privacy response items must be resolved before submission.",
                    systemImage: "hand.raised"
                )
            )
        }

        if warningCount > 0 {
            items.append(
                ReleaseReadinessItem(
                    level: .warning,
                    title: "App privacy review",
                    detail: "\(warningCount) privacy response items should be reviewed before publishing.",
                    systemImage: "lock.shield"
                )
            )
        }

        return items
    }

    static func checklistItem(
        disclosure: AppPrivacyDisclosure?,
        issues: [AppPrivacyIssue]
    ) -> ReviewChecklistItem {
        guard let disclosure else {
            return ReviewChecklistItem(
                level: .warning,
                title: "App Privacy",
                detail: "No App Privacy response state is loaded.",
                remediation: "Open App Privacy after selecting a version.",
                systemImage: "hand.raised",
                affectedLocales: [],
                affectedLabel: "Data Types"
            )
        }

        let blockingCount = issues.filter { $0.severity == .blocking }.count
        if blockingCount > 0 {
            return ReviewChecklistItem(
                level: .blocking,
                title: "App Privacy",
                detail: "\(blockingCount) App Privacy response items block release prep.",
                remediation: "Complete the privacy policy URL and every selected data type's purposes before publishing.",
                systemImage: "hand.raised",
                affectedLocales: affectedDataTypes(for: issues, severity: .blocking),
                affectedLabel: "Data Types"
            )
        }

        let warningCount = issues.filter { $0.severity == .warning }.count
        if warningCount > 0 {
            return ReviewChecklistItem(
                level: .warning,
                title: "App Privacy",
                detail: "\(warningCount) App Privacy response items need review.",
                remediation: "Review tracking, linked data, and user privacy choices before publishing responses.",
                systemImage: "lock.shield",
                affectedLocales: affectedDataTypes(for: issues, severity: .warning),
                affectedLabel: "Data Types"
            )
        }

        let dataTypeText = disclosure.dataTypeCount == 1 ? "1 data type" : "\(disclosure.dataTypeCount) data types"
        return ReviewChecklistItem(
            level: .ready,
            title: "App Privacy",
            detail: disclosure.doesCollectData ? "\(dataTypeText) disclosed for the privacy label." : "The app is marked as not collecting data.",
            remediation: "Confirm responses match the submitted binary and third-party SDK behavior.",
            systemImage: "checkmark.circle",
            affectedLocales: disclosure.dataDisclosures.map { $0.dataType.title },
            affectedLabel: "Data Types"
        )
    }

    private static func affectedDataTypes(
        for issues: [AppPrivacyIssue],
        severity: AppPrivacyIssueSeverity
    ) -> [String] {
        Array(Set(issues.filter { $0.severity == severity }.flatMap { $0.affectedDataTypes.map(\.title) }))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}
