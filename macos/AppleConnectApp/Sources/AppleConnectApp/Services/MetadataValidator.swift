import Foundation

enum MetadataValidator {
    static func validate(document: MetadataDocument) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        var seenLocales = Set<String>()

        for localization in document.localizations {
            if localization.locale.isEmpty {
                issues.append(error(localization.locale, "locale", "Locale is required."))
                continue
            }

            if seenLocales.contains(localization.locale) {
                issues.append(error(localization.locale, "locale", "Locale is duplicated."))
            }
            seenLocales.insert(localization.locale)

            validateAppInfo(localization, into: &issues)
            validateVersion(localization, into: &issues)
            validatePolicyGuidance(localization, into: &issues)
        }

        return issues
    }

    static func plan(
        document: MetadataDocument,
        baseline: MetadataDocument?,
        validationIssues: [ValidationIssue]
    ) -> MetadataPlan {
        let baselineByLocale = Dictionary(
            uniqueKeysWithValues: (baseline?.localizations ?? []).map { ($0.locale, $0) }
        )

        let actions = document.localizations.flatMap { localization -> [MetadataChangeAction] in
            let current = baselineByLocale[localization.locale]
            return [
                action(
                    locale: localization.locale,
                    resource: .appInfoLocalization,
                    fields: changedAppInfoFields(localization.appInfo, current?.appInfo),
                    exists: current != nil
                ),
                action(
                    locale: localization.locale,
                    resource: .appStoreVersionLocalization,
                    fields: changedVersionFields(localization.version, current?.version),
                    exists: current != nil
                )
            ]
        }

        return MetadataPlan(issues: validationIssues, actions: actions)
    }

    private static func validateAppInfo(_ localization: LocaleMetadata, into issues: inout [ValidationIssue]) {
        let appInfo = localization.appInfo

        if !appInfo.name.isEmpty {
            let count = characterCount(appInfo.name)
            if count < 2 || count > 30 {
                issues.append(error(localization.locale, "appInfo.name", "App name must be 2-30 characters."))
            }
        }

        if characterCount(appInfo.subtitle) > 30 {
            issues.append(error(localization.locale, "appInfo.subtitle", "Subtitle must be 30 characters or fewer."))
        }

        validateURL(appInfo.privacyPolicyURL, locale: localization.locale, field: "appInfo.privacyPolicyUrl", into: &issues)
        validateURL(appInfo.privacyChoicesURL, locale: localization.locale, field: "appInfo.privacyChoicesUrl", into: &issues)
    }

    private static func validateVersion(_ localization: LocaleMetadata, into issues: inout [ValidationIssue]) {
        let version = localization.version

        if characterCount(version.promotionalText) > 170 {
            issues.append(error(localization.locale, "version.promotionalText", "Promotional text must be 170 characters or fewer."))
        }

        if characterCount(version.description) > 4_000 {
            issues.append(error(localization.locale, "version.description", "Description must be 4000 characters or fewer."))
        }

        if characterCount(version.whatsNew) > 4_000 {
            issues.append(error(localization.locale, "version.whatsNew", "What's new must be 4000 characters or fewer."))
        }

        if version.keywords.lengthOfBytes(using: .utf8) > 100 {
            issues.append(error(localization.locale, "version.keywords", "Keywords must be 100 UTF-8 bytes or fewer."))
        }

        if !version.description.isEmpty {
            if version.keywords.isEmpty {
                issues.append(warning(localization.locale, "version.keywords", "Keywords are required before App Store submission."))
            }

            if version.supportURL.isEmpty {
                issues.append(warning(localization.locale, "version.supportUrl", "Support URL is required before App Store submission."))
            }
        }

        validateURL(version.marketingURL, locale: localization.locale, field: "version.marketingUrl", into: &issues)
        validateURL(version.supportURL, locale: localization.locale, field: "version.supportUrl", into: &issues)
    }

    private static func validateURL(
        _ value: String,
        locale: String,
        field: String,
        into issues: inout [ValidationIssue]
    ) {
        guard !value.isEmpty else {
            return
        }

        guard let url = URL(string: value), ["http", "https"].contains(url.scheme?.lowercased()) else {
            issues.append(error(locale, field, "URL must be a full http(s) URL."))
            return
        }

        if url.scheme?.lowercased() == "http" {
            issues.append(warning(locale, field, "Use HTTPS for customer-facing App Store URLs."))
        }
    }

    private static func validatePolicyGuidance(_ localization: LocaleMetadata, into issues: inout [ValidationIssue]) {
        let policyFields = [
            ("appInfo.name", localization.appInfo.name),
            ("appInfo.subtitle", localization.appInfo.subtitle),
            ("version.description", localization.version.description),
            ("version.promotionalText", localization.version.promotionalText),
            ("version.whatsNew", localization.version.whatsNew)
        ]

        for (field, value) in policyFields {
            let normalizedValue = value.lowercased()
            guard !normalizedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            if containsAny(normalizedValue, terms: placeholderTerms) {
                issues.append(warning(localization.locale, field, "Replace placeholder copy before App Review."))
            }

            if containsAny(normalizedValue, terms: prereleaseTerms) {
                issues.append(warning(localization.locale, field, "Remove beta, TestFlight, or internal-testing language from App Store metadata."))
            }

            if containsAny(normalizedValue, terms: unsubstantiatedClaimTerms) {
                issues.append(warning(localization.locale, field, "Substantiate ranking or guarantee claims before submission."))
            }
        }
    }

    private static let placeholderTerms = [
        "lorem ipsum",
        "placeholder",
        "todo",
        "tbd",
        "coming soon"
    ]

    private static let prereleaseTerms = [
        "beta",
        "testflight",
        "internal test",
        "qa build"
    ]

    private static let unsubstantiatedClaimTerms = [
        "#1",
        "number one",
        "best app",
        "guaranteed"
    ]

    private static func containsAny(_ value: String, terms: [String]) -> Bool {
        terms.contains { value.contains($0) }
    }

    private static func action(
        locale: String,
        resource: MetadataResource,
        fields: [String],
        exists: Bool
    ) -> MetadataChangeAction {
        MetadataChangeAction(
            locale: locale,
            resource: resource,
            kind: fields.isEmpty ? .skip : (exists ? .update : .create),
            fields: fields
        )
    }

    private static func changedAppInfoFields(_ value: AppInfoMetadata, _ baseline: AppInfoMetadata?) -> [String] {
        guard let baseline else {
            return ["name", "subtitle", "privacyPolicyUrl", "privacyChoicesUrl", "privacyPolicyText"]
                .filter { !fieldValue($0, from: value).isEmpty }
        }

        return [
            ("name", value.name, baseline.name),
            ("subtitle", value.subtitle, baseline.subtitle),
            ("privacyPolicyUrl", value.privacyPolicyURL, baseline.privacyPolicyURL),
            ("privacyChoicesUrl", value.privacyChoicesURL, baseline.privacyChoicesURL),
            ("privacyPolicyText", value.privacyPolicyText, baseline.privacyPolicyText)
        ]
        .filter { $0.1 != $0.2 }
        .map(\.0)
    }

    private static func changedVersionFields(_ value: VersionMetadata, _ baseline: VersionMetadata?) -> [String] {
        guard let baseline else {
            return ["description", "keywords", "marketingUrl", "promotionalText", "supportUrl", "whatsNew"]
                .filter { !fieldValue($0, from: value).isEmpty }
        }

        return [
            ("description", value.description, baseline.description),
            ("keywords", value.keywords, baseline.keywords),
            ("marketingUrl", value.marketingURL, baseline.marketingURL),
            ("promotionalText", value.promotionalText, baseline.promotionalText),
            ("supportUrl", value.supportURL, baseline.supportURL),
            ("whatsNew", value.whatsNew, baseline.whatsNew)
        ]
        .filter { $0.1 != $0.2 }
        .map(\.0)
    }

    private static func fieldValue(_ field: String, from appInfo: AppInfoMetadata) -> String {
        switch field {
        case "name":
            appInfo.name
        case "subtitle":
            appInfo.subtitle
        case "privacyPolicyUrl":
            appInfo.privacyPolicyURL
        case "privacyChoicesUrl":
            appInfo.privacyChoicesURL
        case "privacyPolicyText":
            appInfo.privacyPolicyText
        default:
            ""
        }
    }

    private static func fieldValue(_ field: String, from version: VersionMetadata) -> String {
        switch field {
        case "description":
            version.description
        case "keywords":
            version.keywords
        case "marketingUrl":
            version.marketingURL
        case "promotionalText":
            version.promotionalText
        case "supportUrl":
            version.supportURL
        case "whatsNew":
            version.whatsNew
        default:
            ""
        }
    }

    private static func characterCount(_ value: String) -> Int {
        value.count
    }

    private static func error(_ locale: String, _ field: String, _ message: String) -> ValidationIssue {
        ValidationIssue(severity: .error, locale: locale, field: field, message: message)
    }

    private static func warning(_ locale: String, _ field: String, _ message: String) -> ValidationIssue {
        ValidationIssue(severity: .warning, locale: locale, field: field, message: message)
    }
}
