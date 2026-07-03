import Foundation

struct MetadataReviewHandoffContext {
    var appName: String
    var versionString: String
    var sourceMode: String
    var generatedAt: Date
    var document: MetadataDocument
    var baseline: MetadataDocument?
    var readinessItems: [ReleaseReadinessItem]
    var checklistItems: [ReviewChecklistItem]
    var fixProposals: [ReviewFixProposal]
    var validationIssues: [ValidationIssue]
    var mediaValidationIssues: [StoreMediaValidationIssue] = []
    var pricingAvailabilityIssues: [PricingAvailabilityIssue] = []
    var appPrivacyIssues: [AppPrivacyIssue] = []
    var submissionSetupIssues: [SubmissionSetupIssue] = []
    var ratingsComplianceIssues: [RatingsComplianceIssue] = []
    var plan: MetadataPlan
}

struct MetadataReviewHandoffManifest: Equatable, Codable {
    var schemaVersion: Int
    var generatedAt: Date
    var appName: String
    var versionString: String
    var sourceMode: String
    var localeCount: Int
    var validationIssueCount: Int
    var mediaValidationIssueCount: Int
    var pricingAvailabilityIssueCount: Int
    var appPrivacyIssueCount: Int
    var submissionSetupIssueCount: Int
    var ratingsComplianceIssueCount: Int
    var proposedFixCount: Int
    var draftActionCount: Int
    var reviewStatus: String
}

enum MetadataReviewHandoffPackage {
    static func write(context: MetadataReviewHandoffContext, to directoryURL: URL) throws -> URL {
        let packageURL = directoryURL.appendingPathComponent(packageFolderName(context), isDirectory: true)
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)

        try MetadataDocumentFileTransfer.write(
            document: context.document,
            to: packageURL.appendingPathComponent("metadata.json")
        )
        try reviewReport(context)
            .write(to: packageURL.appendingPathComponent("review-report.md"), atomically: true, encoding: .utf8)
        try changeSummary(context)
            .write(to: packageURL.appendingPathComponent("change-summary.md"), atomically: true, encoding: .utf8)
        try manifestJSON(context)
            .write(to: packageURL.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)

        return packageURL
    }

    static func manifest(for context: MetadataReviewHandoffContext) -> MetadataReviewHandoffManifest {
        MetadataReviewHandoffManifest(
            schemaVersion: 6,
            generatedAt: context.generatedAt,
            appName: context.appName,
            versionString: context.versionString,
            sourceMode: context.sourceMode,
            localeCount: context.document.localizations.count,
            validationIssueCount: context.validationIssues.count,
            mediaValidationIssueCount: context.mediaValidationIssues.count,
            pricingAvailabilityIssueCount: context.pricingAvailabilityIssues.count,
            appPrivacyIssueCount: context.appPrivacyIssues.count,
            submissionSetupIssueCount: context.submissionSetupIssues.count,
            ratingsComplianceIssueCount: context.ratingsComplianceIssues.count,
            proposedFixCount: context.fixProposals.count,
            draftActionCount: context.plan.visibleActions.count,
            reviewStatus: reviewStatus(context)
        )
    }

    private static func reviewReport(_ context: MetadataReviewHandoffContext) -> String {
        MetadataReviewReportFormatter.markdown(
            appName: context.appName,
            versionString: context.versionString,
            generatedAt: context.generatedAt,
            readinessItems: context.readinessItems,
            checklistItems: context.checklistItems,
            fixProposals: context.fixProposals,
            validationIssues: context.validationIssues,
            mediaValidationIssues: context.mediaValidationIssues,
            pricingAvailabilityIssues: context.pricingAvailabilityIssues,
            appPrivacyIssues: context.appPrivacyIssues,
            submissionSetupIssues: context.submissionSetupIssues,
            ratingsComplianceIssues: context.ratingsComplianceIssues,
            plan: context.plan
        )
    }

    private static func changeSummary(_ context: MetadataReviewHandoffContext) -> String {
        MetadataChangeSummaryFormatter.markdown(
            appName: context.appName,
            versionString: context.versionString,
            plan: context.plan,
            issues: context.validationIssues,
            document: context.document,
            baseline: context.baseline
        )
    }

    private static func manifestJSON(_ context: MetadataReviewHandoffContext) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest(for: context))
        return String(decoding: data, as: UTF8.self)
    }

    private static func reviewStatus(_ context: MetadataReviewHandoffContext) -> String {
        let levels = context.readinessItems.map(\.level) + context.checklistItems.map(\.level)
        if levels.contains(.blocking) || context.mediaValidationIssues.contains(where: { $0.severity == .blocking }) {
            return "blocked"
        }

        if context.pricingAvailabilityIssues.contains(where: { $0.severity == .blocking }) {
            return "blocked"
        }

        if context.appPrivacyIssues.contains(where: { $0.severity == .blocking }) {
            return "blocked"
        }

        if context.submissionSetupIssues.contains(where: { $0.severity == .blocking }) {
            return "blocked"
        }

        if context.ratingsComplianceIssues.contains(where: { $0.severity == .blocking }) {
            return "blocked"
        }

        if levels.contains(.warning) || context.mediaValidationIssues.contains(where: { $0.severity == .warning }) {
            return "review"
        }

        if context.pricingAvailabilityIssues.contains(where: { $0.severity == .warning }) {
            return "review"
        }

        if context.appPrivacyIssues.contains(where: { $0.severity == .warning }) {
            return "review"
        }

        if context.submissionSetupIssues.contains(where: { $0.severity == .warning }) {
            return "review"
        }

        if context.ratingsComplianceIssues.contains(where: { $0.severity == .warning }) {
            return "review"
        }

        return "ready"
    }

    private static func packageFolderName(_ context: MetadataReviewHandoffContext) -> String {
        let appPart = sanitizedFileNameComponent(context.appName, fallback: "metadata")
        let versionPart = sanitizedFileNameComponent(context.versionString, fallback: "version")
        return "\(appPart)-\(versionPart)-review-handoff"
    }

    private static func sanitizedFileNameComponent(_ value: String, fallback: String) -> String {
        let sanitized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^A-Za-z0-9_-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return sanitized.isEmpty ? fallback : sanitized
    }
}
