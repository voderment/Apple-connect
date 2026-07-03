import Foundation

enum SubmissionSetupReviewReadiness {
    static func releaseItems(
        setup: AppSubmissionSetup?,
        issues: [SubmissionSetupIssue]
    ) -> [ReleaseReadinessItem] {
        guard setup != nil else {
            return [
                ReleaseReadinessItem(
                    level: .warning,
                    title: "Submission setup not loaded",
                    detail: "Select an app and version before checking build, review, and release settings.",
                    systemImage: "shippingbox"
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
                    title: "Submission setup blockers",
                    detail: "\(blockingCount) build or App Review settings must be resolved before submission.",
                    systemImage: "shippingbox"
                )
            )
        }

        if warningCount > 0 {
            items.append(
                ReleaseReadinessItem(
                    level: .warning,
                    title: "Submission setup review",
                    detail: "\(warningCount) submission settings should be reviewed before handoff.",
                    systemImage: "checklist"
                )
            )
        }

        return items
    }

    static func checklistItem(
        setup: AppSubmissionSetup?,
        issues: [SubmissionSetupIssue]
    ) -> ReviewChecklistItem {
        guard let setup else {
            return ReviewChecklistItem(
                level: .warning,
                title: "Submission Setup",
                detail: "No build or App Review setup state is loaded.",
                remediation: "Open Submission Setup after selecting a version.",
                systemImage: "shippingbox",
                affectedLocales: [],
                affectedLabel: "Items"
            )
        }

        let blockingCount = issues.filter { $0.severity == .blocking }.count
        if blockingCount > 0 {
            return ReviewChecklistItem(
                level: .blocking,
                title: "Submission Setup",
                detail: "\(blockingCount) build or App Review setup items block release prep.",
                remediation: "Select a valid build, complete review contact/demo account details, and confirm compliance answers.",
                systemImage: "shippingbox",
                affectedLocales: affectedAreas(for: issues, severity: .blocking),
                affectedLabel: "Items"
            )
        }

        let warningCount = issues.filter { $0.severity == .warning }.count
        if warningCount > 0 {
            return ReviewChecklistItem(
                level: .warning,
                title: "Submission Setup",
                detail: "\(warningCount) submission setup items need review.",
                remediation: "Review draft submission membership, release option, notes, and compliance context.",
                systemImage: "checklist",
                affectedLocales: affectedAreas(for: issues, severity: .warning),
                affectedLabel: "Items"
            )
        }

        return ReviewChecklistItem(
            level: .ready,
            title: "Submission Setup",
            detail: "Build \(setup.selectedBuild?.displayName ?? "selected") is ready with complete App Review information.",
            remediation: "Confirm the draft submission contains every item intended for this release.",
            systemImage: "checkmark.circle",
            affectedLocales: ["Build", "Review Info", "Compliance"],
            affectedLabel: "Items"
        )
    }

    private static func affectedAreas(
        for issues: [SubmissionSetupIssue],
        severity: SubmissionSetupIssueSeverity
    ) -> [String] {
        Array(Set(issues.filter { $0.severity == severity }.map { $0.area.title }))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}
