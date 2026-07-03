import Foundation

enum StoreMediaReviewReadiness {
    static func releaseItems(
        catalog: StoreMediaCatalog?,
        issues: [StoreMediaValidationIssue]
    ) -> [ReleaseReadinessItem] {
        guard let catalog else {
            return [
                ReleaseReadinessItem(
                    level: .warning,
                    title: "Media assets not loaded",
                    detail: "Select an app and version before checking localized screenshots and previews.",
                    systemImage: "photo.on.rectangle"
                )
            ]
        }

        let summary = StoreMediaRequirementValidator.summary(for: catalog)
        var items: [ReleaseReadinessItem] = []

        if summary.blockingCount > 0 {
            let locales = affectedLocales(for: issues, severity: .blocking)
            items.append(
                ReleaseReadinessItem(
                    level: .blocking,
                    title: "Media asset blockers",
                    detail: "\(summary.blockingCount) screenshot or preview requirements need fixes. Locales: \(localeDetail(locales)).",
                    systemImage: "photo.badge.exclamationmark"
                )
            )
        }

        if summary.warningCount > 0 {
            let locales = affectedLocales(for: issues, severity: .warning)
            items.append(
                ReleaseReadinessItem(
                    level: .warning,
                    title: "Media asset warnings",
                    detail: "\(summary.warningCount) media warnings should be reviewed. Locales: \(localeDetail(locales)).",
                    systemImage: "play.rectangle"
                )
            )
        }

        return items
    }

    static func checklistItem(
        catalog: StoreMediaCatalog?,
        issues: [StoreMediaValidationIssue]
    ) -> ReviewChecklistItem {
        guard let catalog else {
            return ReviewChecklistItem(
                level: .warning,
                title: "Localized Media",
                detail: "No media asset catalog is loaded for this version.",
                remediation: "Open Media Assets after selecting a version to check screenshots and app previews.",
                systemImage: "photo.on.rectangle",
                affectedLocales: []
            )
        }

        let summary = StoreMediaRequirementValidator.summary(for: catalog)
        let blockingLocales = affectedLocales(for: issues, severity: .blocking)
        let warningLocales = affectedLocales(for: issues, severity: .warning)

        if summary.blockingCount > 0 {
            return ReviewChecklistItem(
                level: .blocking,
                title: "Localized Media",
                detail: "\(summary.blockingCount) required screenshot or app preview checks are blocking release prep.",
                remediation: "Open Media Assets and fix missing, oversized, or mismatched localized media.",
                systemImage: "photo.badge.exclamationmark",
                affectedLocales: blockingLocales
            )
        }

        if summary.warningCount > 0 {
            return ReviewChecklistItem(
                level: .warning,
                title: "Localized Media",
                detail: "\(summary.warningCount) localized media warnings are active.",
                remediation: "Review optional screenshots and app previews before handoff.",
                systemImage: "play.rectangle",
                affectedLocales: warningLocales
            )
        }

        return ReviewChecklistItem(
            level: .ready,
            title: "Localized Media",
            detail: "\(summary.screenshotCount) screenshots and \(summary.previewCount) app previews are available.",
            remediation: "Keep screenshots and previews aligned with the submitted build and locale.",
            systemImage: "photo.on.rectangle",
            affectedLocales: catalog.locales
        )
    }

    private static func affectedLocales(
        for issues: [StoreMediaValidationIssue],
        severity: StoreMediaValidationSeverity
    ) -> [String] {
        Array(Set(issues.filter { $0.severity == severity }.map(\.locale)))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private static func localeDetail(_ locales: [String]) -> String {
        guard !locales.isEmpty else {
            return "none"
        }

        let visible = locales.prefix(4).joined(separator: ", ")
        let remaining = max(0, locales.count - 4)
        if remaining == 0 {
            return visible
        }

        return "\(visible) and \(remaining) more"
    }
}
