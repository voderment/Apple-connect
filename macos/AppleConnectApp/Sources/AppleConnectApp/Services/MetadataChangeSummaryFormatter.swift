import Foundation

enum MetadataChangeSummaryFormatter {
    static func markdown(
        appName: String,
        versionString: String,
        plan: MetadataPlan,
        issues: [ValidationIssue],
        document: MetadataDocument?,
        baseline: MetadataDocument?
    ) -> String {
        var lines: [String] = ["# Metadata Change Summary", ""]

        if !appName.isEmpty {
            lines.append("App: \(appName)")
        }
        if !versionString.isEmpty {
            lines.append("Version: \(versionString)")
        }
        if !appName.isEmpty || !versionString.isEmpty {
            lines.append("")
        }

        if issues.isEmpty {
            lines.append("## Validation")
            lines.append("- No validation issues.")
            lines.append("")
        } else {
            lines.append("## Validation")
            for issue in issues {
                lines.append("- [\(issue.severity.rawValue)] \(issue.locale) \(fieldTitle(issue.field)): \(issue.message)")
            }
            lines.append("")
        }

        lines.append("## Draft Changes")
        let actions = plan.visibleActions
        if actions.isEmpty {
            lines.append("- No draft changes.")
        } else {
            for action in actions {
                lines.append("")
                lines.append("### \(action.locale) · \(resourceTitle(action.resource)) · \(action.kind.rawValue.capitalized)")
                for field in action.fields {
                    lines.append("- \(fieldTitle(field)): \(compact(fieldValue(field, action: action, document: baseline))) -> \(compact(fieldValue(field, action: action, document: document)))")
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func resourceTitle(_ resource: MetadataResource) -> String {
        switch resource {
        case .appInfoLocalization:
            "App Info"
        case .appStoreVersionLocalization:
            "Version"
        }
    }

    private static func fieldTitle(_ field: String) -> String {
        switch field {
        case "appInfo.name", "name":
            "Name"
        case "appInfo.subtitle", "subtitle":
            "Subtitle"
        case "appInfo.privacyPolicyUrl", "privacyPolicyUrl":
            "Privacy Policy URL"
        case "appInfo.privacyChoicesUrl", "privacyChoicesUrl":
            "Privacy Choices URL"
        case "appInfo.privacyPolicyText", "privacyPolicyText":
            "Privacy Policy Text"
        case "version.description", "description":
            "Description"
        case "version.keywords", "keywords":
            "Keywords"
        case "version.marketingUrl", "marketingUrl":
            "Marketing URL"
        case "version.promotionalText", "promotionalText":
            "Promotional Text"
        case "version.supportUrl", "supportUrl":
            "Support URL"
        case "version.whatsNew", "whatsNew":
            "What's New"
        default:
            field
                .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
                .capitalized
        }
    }

    private static func fieldValue(
        _ field: String,
        action: MetadataChangeAction,
        document: MetadataDocument?
    ) -> String? {
        guard let localization = document?.localizations.first(where: { $0.locale == action.locale }) else {
            return nil
        }

        switch action.resource {
        case .appInfoLocalization:
            switch field {
            case "name":
                return localization.appInfo.name
            case "subtitle":
                return localization.appInfo.subtitle
            case "privacyPolicyUrl":
                return localization.appInfo.privacyPolicyURL
            case "privacyChoicesUrl":
                return localization.appInfo.privacyChoicesURL
            case "privacyPolicyText":
                return localization.appInfo.privacyPolicyText
            default:
                return nil
            }
        case .appStoreVersionLocalization:
            switch field {
            case "description":
                return localization.version.description
            case "keywords":
                return localization.version.keywords
            case "marketingUrl":
                return localization.version.marketingURL
            case "promotionalText":
                return localization.version.promotionalText
            case "supportUrl":
                return localization.version.supportURL
            case "whatsNew":
                return localization.version.whatsNew
            default:
                return nil
            }
        }
    }

    private static func compact(_ value: String?) -> String {
        guard let value else {
            return "Not present"
        }

        let compacted = value
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !compacted.isEmpty else {
            return "Empty"
        }

        if compacted.count > 280 {
            return "\(compacted.prefix(280))..."
        }

        return compacted
    }
}
