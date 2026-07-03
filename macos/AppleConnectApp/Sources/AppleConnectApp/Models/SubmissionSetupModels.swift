import Foundation

enum SubmissionBuildProcessingState: String, CaseIterable, Identifiable, Codable {
    case processing
    case valid
    case invalid
    case expired

    var id: String { rawValue }

    var title: String {
        switch self {
        case .processing:
            "Processing"
        case .valid:
            "Valid"
        case .invalid:
            "Invalid"
        case .expired:
            "Expired"
        }
    }
}

struct SubmissionBuildCandidate: Identifiable, Equatable, Codable {
    var id: String
    var version: String
    var buildNumber: String
    var platform: String
    var sdk: String
    var uploadedAt: Date
    var processingState: SubmissionBuildProcessingState
    var usesNonExemptEncryption: Bool?
    var minOSVersion: String

    var displayName: String {
        "\(version) (\(buildNumber))"
    }
}

struct SubmissionReviewContact: Equatable, Codable {
    var firstName: String
    var lastName: String
    var email: String
    var phone: String

    var displayName: String {
        [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

struct SubmissionDemoAccount: Equatable, Codable {
    var isRequired: Bool
    var username: String
    var password: String
    var notes: String
}

enum SubmissionReleaseOption: String, CaseIterable, Identifiable, Codable {
    case automaticAfterApproval
    case manualRelease
    case scheduledRelease

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automaticAfterApproval:
            "Automatic"
        case .manualRelease:
            "Manual"
        case .scheduledRelease:
            "Scheduled"
        }
    }

    var detail: String {
        switch self {
        case .automaticAfterApproval:
            "Release automatically after App Review approval."
        case .manualRelease:
            "Hold the approved version until you release it."
        case .scheduledRelease:
            "Release after approval on the selected date."
        }
    }
}

struct SubmissionExportCompliance: Equatable, Codable {
    var usesEncryption: Bool
    var isExempt: Bool?
    var complianceNotes: String
}

struct SubmissionContentRights: Equatable, Codable {
    var containsThirdPartyContent: Bool
    var hasRights: Bool?
    var notes: String
}

struct AppSubmissionSetup: Equatable, Codable {
    var appID: String
    var versionID: String
    var selectedBuildID: String?
    var builds: [SubmissionBuildCandidate]
    var reviewContact: SubmissionReviewContact
    var reviewNotes: String
    var demoAccount: SubmissionDemoAccount
    var releaseOption: SubmissionReleaseOption
    var scheduledReleaseDate: Date?
    var isPhasedReleaseEnabled: Bool
    var exportCompliance: SubmissionExportCompliance
    var contentRights: SubmissionContentRights
    var draftSubmissionItemCount: Int
    var updatedAt: Date

    var selectedBuild: SubmissionBuildCandidate? {
        guard let selectedBuildID else {
            return nil
        }

        return builds.first { $0.id == selectedBuildID }
    }
}

enum SubmissionSetupIssueSeverity: String, Codable {
    case blocking
    case warning
}

enum SubmissionSetupIssueArea: String, Codable {
    case build
    case reviewContact
    case demoAccount
    case reviewNotes
    case releaseOption
    case exportCompliance
    case contentRights
    case draftSubmission

    var title: String {
        switch self {
        case .build:
            "Build"
        case .reviewContact:
            "Review Contact"
        case .demoAccount:
            "Demo Account"
        case .reviewNotes:
            "Review Notes"
        case .releaseOption:
            "Release Option"
        case .exportCompliance:
            "Export Compliance"
        case .contentRights:
            "Content Rights"
        case .draftSubmission:
            "Draft Submission"
        }
    }
}

struct SubmissionSetupIssue: Identifiable, Equatable, Codable {
    var severity: SubmissionSetupIssueSeverity
    var area: SubmissionSetupIssueArea
    var title: String
    var detail: String

    var id: String {
        [severity.rawValue, area.rawValue, title, detail].joined(separator: "|")
    }
}

struct SubmissionSetupSummary: Equatable, Codable {
    var buildCount: Int
    var hasSelectedBuild: Bool
    var draftSubmissionItemCount: Int
    var blockingCount: Int
    var warningCount: Int

    var isReady: Bool {
        blockingCount == 0
    }
}

enum SubmissionSetupValidator {
    static func issues(for setup: AppSubmissionSetup?) -> [SubmissionSetupIssue] {
        guard let setup else {
            return [
                SubmissionSetupIssue(
                    severity: .warning,
                    area: .draftSubmission,
                    title: "Submission setup not loaded",
                    detail: "Select an app and version before checking build and App Review settings."
                )
            ]
        }

        var issues: [SubmissionSetupIssue] = []

        if setup.builds.isEmpty {
            issues.append(
                SubmissionSetupIssue(
                    severity: .blocking,
                    area: .build,
                    title: "No builds uploaded",
                    detail: "Upload and process a build before preparing this version for review."
                )
            )
        } else if setup.selectedBuildID == nil {
            issues.append(
                SubmissionSetupIssue(
                    severity: .blocking,
                    area: .build,
                    title: "Build not selected",
                    detail: "Choose the build that should be associated with this App Store version."
                )
            )
        } else if let selectedBuild = setup.selectedBuild {
            switch selectedBuild.processingState {
            case .valid:
                break
            case .processing:
                issues.append(
                    SubmissionSetupIssue(
                        severity: .warning,
                        area: .build,
                        title: "Build still processing",
                        detail: "\(selectedBuild.displayName) needs to finish processing before submission."
                    )
                )
            case .invalid, .expired:
                issues.append(
                    SubmissionSetupIssue(
                        severity: .blocking,
                        area: .build,
                        title: "Selected build is not valid",
                        detail: "\(selectedBuild.displayName) is \(selectedBuild.processingState.title.lowercased()). Choose a valid build."
                    )
                )
            }
        } else {
            issues.append(
                SubmissionSetupIssue(
                    severity: .blocking,
                    area: .build,
                    title: "Selected build missing",
                    detail: "The selected build is no longer available in the build list."
                )
            )
        }

        appendReviewContactIssues(setup.reviewContact, to: &issues)
        appendDemoAccountIssues(setup.demoAccount, to: &issues)
        appendReviewNotesIssues(setup.reviewNotes, to: &issues)
        appendReleaseOptionIssues(setup, to: &issues)
        appendExportComplianceIssues(setup, to: &issues)
        appendContentRightsIssues(setup.contentRights, to: &issues)

        if setup.draftSubmissionItemCount == 0 {
            issues.append(
                SubmissionSetupIssue(
                    severity: .warning,
                    area: .draftSubmission,
                    title: "No draft submission item",
                    detail: "Create or update a draft submission that includes this app version before final handoff."
                )
            )
        }

        return issues
    }

    static func summary(for setup: AppSubmissionSetup?) -> SubmissionSetupSummary {
        let issues = issues(for: setup)
        return SubmissionSetupSummary(
            buildCount: setup?.builds.count ?? 0,
            hasSelectedBuild: setup?.selectedBuild != nil,
            draftSubmissionItemCount: setup?.draftSubmissionItemCount ?? 0,
            blockingCount: issues.filter { $0.severity == .blocking }.count,
            warningCount: issues.filter { $0.severity == .warning }.count
        )
    }

    private static func appendReviewContactIssues(
        _ contact: SubmissionReviewContact,
        to issues: inout [SubmissionSetupIssue]
    ) {
        if contact.displayName.isEmpty {
            issues.append(
                SubmissionSetupIssue(
                    severity: .blocking,
                    area: .reviewContact,
                    title: "Review contact name missing",
                    detail: "Provide the App Review contact's first and last name."
                )
            )
        }

        if !isEmail(contact.email) {
            issues.append(
                SubmissionSetupIssue(
                    severity: .blocking,
                    area: .reviewContact,
                    title: "Review contact email invalid",
                    detail: "Provide a reachable email address for the App Review team."
                )
            )
        }

        if contact.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(
                SubmissionSetupIssue(
                    severity: .blocking,
                    area: .reviewContact,
                    title: "Review contact phone missing",
                    detail: "Provide a phone number in case App Review needs more information."
                )
            )
        }
    }

    private static func appendDemoAccountIssues(
        _ account: SubmissionDemoAccount,
        to issues: inout [SubmissionSetupIssue]
    ) {
        guard account.isRequired else {
            return
        }

        if account.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(
                SubmissionSetupIssue(
                    severity: .blocking,
                    area: .demoAccount,
                    title: "Demo username missing",
                    detail: "Provide a demo account username for login-gated app review."
                )
            )
        }

        if account.password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(
                SubmissionSetupIssue(
                    severity: .blocking,
                    area: .demoAccount,
                    title: "Demo password missing",
                    detail: "Provide a non-expiring password or include access steps in the review notes."
                )
            )
        }
    }

    private static func appendReviewNotesIssues(
        _ notes: String,
        to issues: inout [SubmissionSetupIssue]
    ) {
        if notes.utf8.count > 4_000 {
            issues.append(
                SubmissionSetupIssue(
                    severity: .blocking,
                    area: .reviewNotes,
                    title: "Review notes too long",
                    detail: "Keep App Review notes at or below 4000 bytes."
                )
            )
        }

        if notes.localizedStandardContains("TBD") || notes.localizedStandardContains("TODO") {
            issues.append(
                SubmissionSetupIssue(
                    severity: .warning,
                    area: .reviewNotes,
                    title: "Review notes contain placeholder text",
                    detail: "Replace internal placeholders before submitting to App Review."
                )
            )
        }
    }

    private static func appendReleaseOptionIssues(
        _ setup: AppSubmissionSetup,
        to issues: inout [SubmissionSetupIssue]
    ) {
        if setup.releaseOption == .scheduledRelease, setup.scheduledReleaseDate == nil {
            issues.append(
                SubmissionSetupIssue(
                    severity: .blocking,
                    area: .releaseOption,
                    title: "Scheduled release date missing",
                    detail: "Choose a release date or switch to automatic/manual release."
                )
            )
        }

        if setup.releaseOption == .manualRelease, setup.isPhasedReleaseEnabled {
            issues.append(
                SubmissionSetupIssue(
                    severity: .warning,
                    area: .releaseOption,
                    title: "Manual release with phased rollout",
                    detail: "Confirm the team expects to start the phased rollout manually after approval."
                )
            )
        }
    }

    private static func appendExportComplianceIssues(
        _ setup: AppSubmissionSetup,
        to issues: inout [SubmissionSetupIssue]
    ) {
        let buildRequiresAnswer = setup.selectedBuild?.usesNonExemptEncryption == true
        if setup.exportCompliance.usesEncryption || buildRequiresAnswer {
            guard let isExempt = setup.exportCompliance.isExempt else {
                issues.append(
                    SubmissionSetupIssue(
                        severity: .blocking,
                        area: .exportCompliance,
                        title: "Export compliance not confirmed",
                        detail: "Answer the encryption/export compliance question before submission."
                    )
                )
                return
            }

            if !isExempt && setup.exportCompliance.complianceNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(
                    SubmissionSetupIssue(
                        severity: .warning,
                        area: .exportCompliance,
                        title: "Export compliance notes missing",
                        detail: "Add CCATS or exemption context for the reviewer and release owner."
                    )
                )
            }
        }
    }

    private static func appendContentRightsIssues(
        _ rights: SubmissionContentRights,
        to issues: inout [SubmissionSetupIssue]
    ) {
        guard rights.containsThirdPartyContent else {
            return
        }

        if rights.hasRights != true {
            issues.append(
                SubmissionSetupIssue(
                    severity: .blocking,
                    area: .contentRights,
                    title: "Content rights not confirmed",
                    detail: "Confirm the app has rights to third-party content in every selected storefront."
                )
            )
        }
    }

    private static func isEmail(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("@") && trimmed.contains(".") && !trimmed.contains(" ")
    }
}

enum MockSubmissionSetupFactory {
    static func setup(
        app: ConnectApp?,
        version: AppStoreVersion?,
        isDemoMode: Bool
    ) -> AppSubmissionSetup {
        if isDemoMode, app?.id == "2234567890" {
            return reviewDemoSetup(app: app, version: version)
        }

        return polishedSetup(app: app, version: version)
    }

    private static func polishedSetup(app: ConnectApp?, version: AppStoreVersion?) -> AppSubmissionSetup {
        let build = SubmissionBuildCandidate(
            id: "build-\(version?.id ?? "current")-142",
            version: version?.versionString ?? "1.0.0",
            buildNumber: "142",
            platform: version?.platform ?? "MAC_OS",
            sdk: "macOS 26 SDK",
            uploadedAt: .now.addingTimeInterval(-86_400),
            processingState: .valid,
            usesNonExemptEncryption: false,
            minOSVersion: "26.0"
        )

        return AppSubmissionSetup(
            appID: app?.id ?? "demo-app",
            versionID: version?.id ?? "demo-version",
            selectedBuildID: build.id,
            builds: [build],
            reviewContact: SubmissionReviewContact(
                firstName: "Apple",
                lastName: "Developer",
                email: "review@example.com",
                phone: "+1 408 555 0100"
            ),
            reviewNotes: "No special setup is required. The app opens to the release workspace in demo mode.",
            demoAccount: SubmissionDemoAccount(isRequired: false, username: "", password: "", notes: ""),
            releaseOption: .automaticAfterApproval,
            scheduledReleaseDate: nil,
            isPhasedReleaseEnabled: true,
            exportCompliance: SubmissionExportCompliance(
                usesEncryption: false,
                isExempt: true,
                complianceNotes: ""
            ),
            contentRights: SubmissionContentRights(
                containsThirdPartyContent: false,
                hasRights: true,
                notes: ""
            ),
            draftSubmissionItemCount: 1,
            updatedAt: .now
        )
    }

    private static func reviewDemoSetup(app: ConnectApp?, version: AppStoreVersion?) -> AppSubmissionSetup {
        let processingBuild = SubmissionBuildCandidate(
            id: "build-\(version?.id ?? "review")-98",
            version: version?.versionString ?? "1.2.0",
            buildNumber: "98",
            platform: version?.platform ?? "MAC_OS",
            sdk: "macOS 26 SDK",
            uploadedAt: .now.addingTimeInterval(-3_600),
            processingState: .processing,
            usesNonExemptEncryption: true,
            minOSVersion: "26.0"
        )
        let expiredBuild = SubmissionBuildCandidate(
            id: "build-\(version?.id ?? "review")-91",
            version: version?.versionString ?? "1.2.0",
            buildNumber: "91",
            platform: version?.platform ?? "MAC_OS",
            sdk: "macOS 26 SDK",
            uploadedAt: .now.addingTimeInterval(-86_400 * 35),
            processingState: .expired,
            usesNonExemptEncryption: nil,
            minOSVersion: "26.0"
        )

        return AppSubmissionSetup(
            appID: app?.id ?? "review-demo-app",
            versionID: version?.id ?? "review-demo-version",
            selectedBuildID: nil,
            builds: [processingBuild, expiredBuild],
            reviewContact: SubmissionReviewContact(
                firstName: "Release",
                lastName: "",
                email: "release-team",
                phone: ""
            ),
            reviewNotes: "TBD: add reviewer setup steps and any required account instructions.",
            demoAccount: SubmissionDemoAccount(
                isRequired: true,
                username: "reviewer@example.com",
                password: "",
                notes: "Account should not expire."
            ),
            releaseOption: .manualRelease,
            scheduledReleaseDate: nil,
            isPhasedReleaseEnabled: true,
            exportCompliance: SubmissionExportCompliance(
                usesEncryption: true,
                isExempt: nil,
                complianceNotes: ""
            ),
            contentRights: SubmissionContentRights(
                containsThirdPartyContent: true,
                hasRights: nil,
                notes: "Includes sample screenshots and demo content."
            ),
            draftSubmissionItemCount: 0,
            updatedAt: .now
        )
    }
}
