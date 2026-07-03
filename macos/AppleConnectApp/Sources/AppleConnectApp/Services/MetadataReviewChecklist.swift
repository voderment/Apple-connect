import Foundation

enum MetadataReviewChecklist {
    static func evaluate(
        document: MetadataDocument?,
        validationIssues: [ValidationIssue],
        hasUnsavedChanges: Bool
    ) -> [ReviewChecklistItem] {
        guard let document else {
            return [
                ReviewChecklistItem(
                    level: .blocking,
                    title: "Metadata Loaded",
                    detail: "No metadata document is open for review.",
                    remediation: "Select an app and version before preparing App Store copy.",
                    systemImage: "doc.text.magnifyingglass",
                    affectedLocales: []
                )
            ]
        }

        return [
            localizationsItem(document),
            requiredCopyItem(document),
            privacyAndURLItem(document, validationIssues: validationIssues),
            reviewLanguageItem(validationIssues),
            releaseNotesItem(document),
            draftStateItem(hasUnsavedChanges)
        ]
    }

    private static func localizationsItem(_ document: MetadataDocument) -> ReviewChecklistItem {
        if document.localizations.isEmpty {
            return ReviewChecklistItem(
                level: .blocking,
                title: "Localizations",
                detail: "No App Store localizations are available for this version.",
                remediation: "Add at least one locale before preparing a release.",
                systemImage: "globe.badge.chevron.backward",
                affectedLocales: []
            )
        }

        return ReviewChecklistItem(
            level: .ready,
            title: "Localizations",
            detail: "\(document.localizations.count) locales are loaded for review.",
            remediation: "Use locale filters to inspect edited, incomplete, or issue-bearing copy.",
            systemImage: "globe",
            affectedLocales: document.localizations.map(\.locale).sortedByLocale()
        )
    }

    private static func requiredCopyItem(_ document: MetadataDocument) -> ReviewChecklistItem {
        let missingNames = document.localizations.filter { isBlank($0.appInfo.name) }.map(\.locale)
        let missingDescriptions = document.localizations.filter { isBlank($0.version.description) }.map(\.locale)
        let blockingLocales = uniqueLocales(missingNames + missingDescriptions)

        if !blockingLocales.isEmpty {
            return ReviewChecklistItem(
                level: .blocking,
                title: "Required Storefront Copy",
                detail: "\(blockingLocales.count) locales are missing an app name or description.",
                remediation: "Fill the app name and description before saving or submitting metadata.",
                systemImage: "text.alignleft",
                affectedLocales: blockingLocales
            )
        }

        let missingKeywords = document.localizations.filter { isBlank($0.version.keywords) }.map(\.locale)
        let missingSupport = document.localizations.filter { isBlank($0.version.supportURL) }.map(\.locale)
        let warningLocales = uniqueLocales(missingKeywords + missingSupport)

        if !warningLocales.isEmpty {
            return ReviewChecklistItem(
                level: .warning,
                title: "Required Storefront Copy",
                detail: "\(warningLocales.count) locales are missing keywords or a support URL.",
                remediation: "Add focused keywords and public support links for each customer-facing locale.",
                systemImage: "tag",
                affectedLocales: warningLocales
            )
        }

        return ReviewChecklistItem(
            level: .ready,
            title: "Required Storefront Copy",
            detail: "Names, descriptions, keywords, and support links are present.",
            remediation: "Keep the copy final and customer-facing before saving.",
            systemImage: "checkmark.circle",
            affectedLocales: []
        )
    }

    private static func privacyAndURLItem(
        _ document: MetadataDocument,
        validationIssues: [ValidationIssue]
    ) -> ReviewChecklistItem {
        let urlIssues = validationIssues.filter { issue in
            issue.field.localizedCaseInsensitiveContains("url")
                || issue.message.localizedCaseInsensitiveContains("url")
        }
        let blockingURLIssues = urlIssues.filter { $0.severity == .error }
        let warningURLIssues = urlIssues.filter { $0.severity == .warning }
        let missingPrivacyLocales = document.localizations
            .filter { isBlank($0.appInfo.privacyPolicyURL) }
            .map(\.locale)

        if !blockingURLIssues.isEmpty {
            return ReviewChecklistItem(
                level: .blocking,
                title: "Privacy And URLs",
                detail: "\(blockingURLIssues.count) URL fields are invalid.",
                remediation: "Use complete http(s) URLs before saving metadata.",
                systemImage: "link.badge.plus",
                affectedLocales: uniqueLocales(blockingURLIssues.map(\.locale))
            )
        }

        if !warningURLIssues.isEmpty || !missingPrivacyLocales.isEmpty {
            return ReviewChecklistItem(
                level: .warning,
                title: "Privacy And URLs",
                detail: "\(uniqueLocales(warningURLIssues.map(\.locale) + missingPrivacyLocales).count) locales need URL review.",
                remediation: "Prefer https:// links and add a privacy policy URL when the app needs public privacy disclosure.",
                systemImage: "lock.shield",
                affectedLocales: uniqueLocales(warningURLIssues.map(\.locale) + missingPrivacyLocales)
            )
        }

        return ReviewChecklistItem(
            level: .ready,
            title: "Privacy And URLs",
            detail: "Public URLs look complete and use HTTPS.",
            remediation: "Confirm linked pages are live before final submission.",
            systemImage: "lock.shield",
            affectedLocales: []
        )
    }

    private static func reviewLanguageItem(_ validationIssues: [ValidationIssue]) -> ReviewChecklistItem {
        let policyIssues = validationIssues.filter { issue in
            let message = issue.message.lowercased()
            return message.contains("placeholder")
                || message.contains("beta")
                || message.contains("testflight")
                || message.contains("internal-testing")
                || message.contains("ranking")
                || message.contains("guarantee")
        }

        if policyIssues.isEmpty {
            return ReviewChecklistItem(
                level: .ready,
                title: "Review-Sensitive Language",
                detail: "No placeholder, prerelease, or unsupported claim language was detected.",
                remediation: "Keep final copy specific, substantiated, and customer-facing.",
                systemImage: "quote.bubble",
                affectedLocales: []
            )
        }

        return ReviewChecklistItem(
            level: .warning,
            title: "Review-Sensitive Language",
            detail: "\(policyIssues.count) possible copy risks should be reviewed.",
            remediation: "Remove internal test wording, placeholder text, and unsubstantiated ranking or guarantee claims.",
            systemImage: "quote.bubble",
            affectedLocales: uniqueLocales(policyIssues.map(\.locale))
        )
    }

    private static func releaseNotesItem(_ document: MetadataDocument) -> ReviewChecklistItem {
        let missingReleaseNotes = document.localizations
            .filter { isBlank($0.version.whatsNew) }
            .map(\.locale)

        if !missingReleaseNotes.isEmpty {
            return ReviewChecklistItem(
                level: .warning,
                title: "Release Notes",
                detail: "\(missingReleaseNotes.count) locales are missing What's New copy.",
                remediation: "Draft concise release notes for customer-visible updates.",
                systemImage: "sparkles.rectangle.stack",
                affectedLocales: uniqueLocales(missingReleaseNotes)
            )
        }

        return ReviewChecklistItem(
            level: .ready,
            title: "Release Notes",
            detail: "What's New copy is present for every locale.",
            remediation: "Keep release notes concrete and aligned with the submitted build.",
            systemImage: "sparkles.rectangle.stack",
            affectedLocales: []
        )
    }

    private static func draftStateItem(_ hasUnsavedChanges: Bool) -> ReviewChecklistItem {
        if hasUnsavedChanges {
            return ReviewChecklistItem(
                level: .warning,
                title: "Draft State",
                detail: "Local edits have not been saved to the current baseline.",
                remediation: "Preview changes, resolve blockers, then save when the draft is ready.",
                systemImage: "tray.and.arrow.down",
                affectedLocales: []
            )
        }

        return ReviewChecklistItem(
            level: .ready,
            title: "Draft State",
            detail: "No unsaved metadata changes are pending.",
            remediation: "The current baseline is ready for another review pass.",
            systemImage: "checkmark.seal",
            affectedLocales: []
        )
    }

    private static func uniqueLocales(_ locales: [String]) -> [String] {
        Array(Set(locales)).sortedByLocale()
    }

    private static func isBlank(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private extension Array where Element == String {
    func sortedByLocale() -> [String] {
        sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}
