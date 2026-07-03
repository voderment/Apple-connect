import Foundation

enum MetadataReviewFixPlanner {
    static func proposals(document: MetadataDocument?) -> [ReviewFixProposal] {
        guard let document else {
            return []
        }

        return proposals(document: document)
    }

    static func proposals(document: MetadataDocument) -> [ReviewFixProposal] {
        document.localizations.flatMap { localization in
            var proposals: [ReviewFixProposal] = []

            appendHTTPSProposal(
                value: localization.appInfo.privacyPolicyURL,
                locale: localization.locale,
                field: "appInfo.privacyPolicyUrl",
                title: "Upgrade Privacy Policy URL",
                into: &proposals
            )
            appendHTTPSProposal(
                value: localization.appInfo.privacyChoicesURL,
                locale: localization.locale,
                field: "appInfo.privacyChoicesUrl",
                title: "Upgrade Privacy Choices URL",
                into: &proposals
            )
            appendHTTPSProposal(
                value: localization.version.marketingURL,
                locale: localization.locale,
                field: "version.marketingUrl",
                title: "Upgrade Marketing URL",
                into: &proposals
            )
            appendHTTPSProposal(
                value: localization.version.supportURL,
                locale: localization.locale,
                field: "version.supportUrl",
                title: "Upgrade Support URL",
                into: &proposals
            )
            appendKeywordProposal(localization, into: &proposals)

            return proposals
        }
    }

    private static func appendHTTPSProposal(
        value: String,
        locale: String,
        field: String,
        title: String,
        into proposals: inout [ReviewFixProposal]
    ) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.lowercased().hasPrefix("http://") else {
            return
        }

        proposals.append(
            ReviewFixProposal(
                kind: .upgradeHTTPS,
                locale: locale,
                field: field,
                title: title,
                detail: "Use HTTPS for this customer-facing App Store URL.",
                before: value,
                after: "https://\(trimmedValue.dropFirst(7))"
            )
        )
    }

    private static func appendKeywordProposal(
        _ localization: LocaleMetadata,
        into proposals: inout [ReviewFixProposal]
    ) {
        let normalized = MetadataKeywordNormalizer.normalized(localization.version.keywords)
        guard !normalized.isEmpty,
              normalized != localization.version.keywords else {
            return
        }

        proposals.append(
            ReviewFixProposal(
                kind: .normalizeKeywords,
                locale: localization.locale,
                field: "version.keywords",
                title: "Normalize Keywords",
                detail: "Trim separators, remove duplicates, and keep the keyword list comma-separated.",
                before: localization.version.keywords,
                after: normalized
            )
        )
    }
}
