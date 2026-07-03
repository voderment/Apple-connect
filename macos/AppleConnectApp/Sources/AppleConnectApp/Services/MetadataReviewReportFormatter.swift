import Foundation

enum MetadataReviewReportFormatter {
    static func markdown(
        appName: String,
        versionString: String,
        generatedAt: Date = .now,
        readinessItems: [ReleaseReadinessItem],
        checklistItems: [ReviewChecklistItem],
        fixProposals: [ReviewFixProposal] = [],
        validationIssues: [ValidationIssue],
        mediaValidationIssues: [StoreMediaValidationIssue] = [],
        pricingAvailabilityIssues: [PricingAvailabilityIssue] = [],
        appPrivacyIssues: [AppPrivacyIssue] = [],
        submissionSetupIssues: [SubmissionSetupIssue] = [],
        ratingsComplianceIssues: [RatingsComplianceIssue] = [],
        plan: MetadataPlan
    ) -> String {
        var lines: [String] = ["# App Store Review Prep Report", ""]

        if !appName.isEmpty {
            lines.append("App: \(appName)")
        }
        if !versionString.isEmpty {
            lines.append("Version: \(versionString)")
        }
        lines.append("Generated: \(ISO8601DateFormatter().string(from: generatedAt))")
        lines.append("")

        appendReleaseReadiness(readinessItems, to: &lines)
        appendReviewChecklist(checklistItems, to: &lines)
        appendProposedFixes(fixProposals, to: &lines)
        appendValidation(validationIssues, to: &lines)
        appendMediaValidation(mediaValidationIssues, to: &lines)
        appendPricingValidation(pricingAvailabilityIssues, to: &lines)
        appendAppPrivacyValidation(appPrivacyIssues, to: &lines)
        appendSubmissionSetupValidation(submissionSetupIssues, to: &lines)
        appendRatingsComplianceValidation(ratingsComplianceIssues, to: &lines)
        appendDraftChanges(plan.visibleActions, to: &lines)

        return lines.joined(separator: "\n")
    }

    private static func appendReleaseReadiness(
        _ items: [ReleaseReadinessItem],
        to lines: inout [String]
    ) {
        lines.append("## Release Readiness")

        if items.isEmpty {
            lines.append("- No readiness items.")
        } else {
            for item in items {
                lines.append("- [\(item.level.rawValue)] \(item.title): \(item.detail)")
            }
        }

        lines.append("")
    }

    private static func appendReviewChecklist(
        _ items: [ReviewChecklistItem],
        to lines: inout [String]
    ) {
        lines.append("## Review Checklist")

        if items.isEmpty {
            lines.append("- No checklist items.")
        } else {
            for item in items {
                lines.append("- [\(item.level.rawValue)] \(item.title): \(item.detail)")
                lines.append("  - Action: \(item.remediation)")
                if !item.affectedLocales.isEmpty {
                    lines.append("  - \(item.affectedLabel): \(item.affectedLocales.joined(separator: ", "))")
                }
            }
        }

        lines.append("")
    }

    private static func appendProposedFixes(
        _ proposals: [ReviewFixProposal],
        to lines: inout [String]
    ) {
        lines.append("## Proposed Fixes")

        if proposals.isEmpty {
            lines.append("- No proposed safe fixes.")
        } else {
            for proposal in proposals {
                lines.append("- \(proposal.locale) \(fieldTitle(proposal.field)): \(proposal.detail)")
                lines.append("  - Before: \(compact(proposal.before))")
                lines.append("  - After: \(compact(proposal.after))")
            }
        }

        lines.append("")
    }

    private static func appendValidation(
        _ issues: [ValidationIssue],
        to lines: inout [String]
    ) {
        lines.append("## Validation")

        if issues.isEmpty {
            lines.append("- No validation issues.")
        } else {
            for issue in issues {
                lines.append("- [\(issue.severity.rawValue)] \(issue.locale) \(fieldTitle(issue.field)): \(issue.message)")
                lines.append("  - Fix: \(issue.remediation)")
            }
        }

        lines.append("")
    }

    private static func appendMediaValidation(
        _ issues: [StoreMediaValidationIssue],
        to lines: inout [String]
    ) {
        lines.append("## Media Validation")

        if issues.isEmpty {
            lines.append("- No media validation issues.")
        } else {
            for issue in issues {
                lines.append("- [\(issue.severity.rawValue)] \(issue.locale) \(deviceTitle(issue.deviceID)) \(issue.kind.title): \(issue.title)")
                lines.append("  - Detail: \(issue.detail)")
            }
        }

        lines.append("")
    }

    private static func appendPricingValidation(
        _ issues: [PricingAvailabilityIssue],
        to lines: inout [String]
    ) {
        lines.append("## Pricing and Availability")

        if issues.isEmpty {
            lines.append("- No pricing or availability issues.")
        } else {
            for issue in issues {
                lines.append("- [\(issue.severity.rawValue)] \(issue.title): \(issue.detail)")
                if !issue.affectedTerritories.isEmpty {
                    lines.append("  - Territories: \(issue.affectedTerritories.joined(separator: ", "))")
                }
            }
        }

        lines.append("")
    }

    private static func appendAppPrivacyValidation(
        _ issues: [AppPrivacyIssue],
        to lines: inout [String]
    ) {
        lines.append("## App Privacy")

        if issues.isEmpty {
            lines.append("- No App Privacy issues.")
        } else {
            for issue in issues {
                lines.append("- [\(issue.severity.rawValue)] \(issue.title): \(issue.detail)")
                if !issue.affectedDataTypes.isEmpty {
                    lines.append("  - Data Types: \(issue.affectedDataTypes.map(\.title).joined(separator: ", "))")
                }
            }
        }

        lines.append("")
    }

    private static func appendSubmissionSetupValidation(
        _ issues: [SubmissionSetupIssue],
        to lines: inout [String]
    ) {
        lines.append("## Submission Setup")

        if issues.isEmpty {
            lines.append("- No submission setup issues.")
        } else {
            for issue in issues {
                lines.append("- [\(issue.severity.rawValue)] \(issue.area.title) · \(issue.title): \(issue.detail)")
            }
        }

        lines.append("")
    }

    private static func appendRatingsComplianceValidation(
        _ issues: [RatingsComplianceIssue],
        to lines: inout [String]
    ) {
        lines.append("## Ratings and Compliance")

        if issues.isEmpty {
            lines.append("- No ratings or compliance issues.")
        } else {
            for issue in issues {
                lines.append("- [\(issue.severity.rawValue)] \(issue.area.title) · \(issue.title): \(issue.detail)")
            }
        }

        lines.append("")
    }

    private static func appendDraftChanges(
        _ actions: [MetadataChangeAction],
        to lines: inout [String]
    ) {
        lines.append("## Draft Changes")

        if actions.isEmpty {
            lines.append("- No draft changes.")
            return
        }

        for action in actions {
            lines.append("- \(action.locale) \(resourceTitle(action.resource)) \(action.kind.rawValue): \(fieldList(action.fields))")
        }
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

    private static func fieldList(_ fields: [String]) -> String {
        guard !fields.isEmpty else {
            return "No changed fields"
        }

        return fields.map(fieldTitle).joined(separator: ", ")
    }

    private static func deviceTitle(_ deviceID: String) -> String {
        deviceID
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }

    private static func compact(_ value: String) -> String {
        let compacted = value
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !compacted.isEmpty else {
            return "Empty"
        }

        if compacted.count > 220 {
            return "\(compacted.prefix(220))..."
        }

        return compacted
    }
}
