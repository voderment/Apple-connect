import AppKit
import SwiftUI

struct ReviewPrepSummaryView: View {
    @Bindable var model: AppModel

    var body: some View {
        SummaryPage(title: "Review Prep") {
            SummarySection(title: "Current Version") {
                if let selectedApp = model.selectedApp, let selectedVersion = model.selectedVersion {
                    StatusRow(title: "App", detail: LocalizedStringKey(selectedApp.name), systemImage: "app")
                    StatusRow(title: "Version", detail: LocalizedStringKey(selectedVersion.versionString), systemImage: "number")
                    StatusRow(title: "Checklist", detail: reviewStatusText, systemImage: reviewStatusImage)
                } else {
                    StatusRow(title: "Selection", detail: "Select version", systemImage: "doc.text.magnifyingglass")
                }
            }

            SummarySection(title: "Preflight") {
                Text("Use Review Prep to check release readiness, review-sensitive copy, URL hygiene, validation issues, and unsaved draft actions before handoff.")
                    .font(.callout)
                    .foregroundStyle(OrbiterColor.textMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }

            SummarySection(title: "Actions") {
                Button("Open Localized Copy") {
                    model.sidebarSelection = .copyWorkspace
                }
                .buttonStyle(.orbiter(.secondary))
                .disabled(model.metadataDocument == nil)

                Button("Open Media Assets") {
                    model.sidebarSelection = .mediaAssets
                }
                .buttonStyle(.orbiter(.secondary))
                .disabled(model.mediaAssetCatalog == nil)

                Button("Open Pricing") {
                    model.sidebarSelection = .pricingAvailability
                }
                .buttonStyle(.orbiter(.secondary))
                .disabled(model.pricingAvailability == nil)

                Button("Open App Privacy") {
                    model.sidebarSelection = .appPrivacy
                }
                .buttonStyle(.orbiter(.secondary))
                .disabled(model.appPrivacyDisclosure == nil)

                Button("Open Submission") {
                    model.sidebarSelection = .submissionSetup
                }
                .buttonStyle(.orbiter(.secondary))
                .disabled(model.submissionSetup == nil)

                Button("Open Ratings") {
                    model.sidebarSelection = .ratingsCompliance
                }
                .buttonStyle(.orbiter(.secondary))
                .disabled(model.ratingsCompliance == nil)
            }
        }
        .navigationTitle("Review Prep")
    }

    private var reviewStatusText: LocalizedStringKey {
        if model.reviewChecklistItems.contains(where: { $0.level == .blocking }) {
            return "Blocked"
        }

        let warningCount = model.reviewChecklistItems.filter { $0.level == .warning }.count
        if warningCount > 0 {
            return "\(warningCount) to review"
        }

        return "Ready"
    }

    private var reviewStatusImage: String {
        if model.reviewChecklistItems.contains(where: { $0.level == .blocking }) {
            return "xmark.octagon"
        }

        if model.reviewChecklistItems.contains(where: { $0.level == .warning }) {
            return "exclamationmark.triangle"
        }

        return "checkmark.circle"
    }
}

struct ReviewPrepView: View {
    @Bindable var model: AppModel
    @State private var didCopyReport = false

    var body: some View {
        Group {
            if model.metadataDocument == nil {
                EmptyStateView(
                    title: "Review Prep",
                    systemImage: "checklist",
                    message: "Select an app and version to prepare an App Store review handoff."
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        ReviewPrepSummaryPanel(summary: model.reviewPrepSummary)

                        ReviewPrepSection(title: "Release Readiness") {
                            ForEach(model.releaseReadinessItems) { item in
                                ReleaseReadinessRow(item: item)
                            }
                        }

                        ReviewPrepSection(title: "Review Checklist") {
                            ForEach(model.reviewChecklistItems) { item in
                                if item.affectedLocales.isEmpty {
                                    ReviewChecklistRow(item: item)
                                } else {
                                    Button {
                                        openChecklistItem(item)
                                    } label: {
                                        ReviewChecklistRow(item: item)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Open first affected locale")
                                }
                            }
                        }

                        ReviewPrepSection(title: "Proposed Fixes") {
                            if model.reviewFixProposals.isEmpty {
                                Label("No deterministic fixes are available", systemImage: "checkmark.circle")
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(OrbiterColor.success)
                                    .padding(8)
                            } else {
                                HStack {
                                    Text("\(model.reviewFixProposals.count) safe fixes can be reviewed and applied.")
                                        .font(.callout)
                                        .foregroundStyle(OrbiterColor.textMuted)

                                    Spacer()

                                    Button {
                                        model.applyReviewFixProposals(model.reviewFixProposals)
                                    } label: {
                                        Label("Apply All", systemImage: "checkmark.circle")
                                    }
                                    .buttonStyle(.orbiter(.secondary, size: .compact))
                                }
                                .padding(.horizontal, 8)

                                ForEach(model.reviewFixProposals) { proposal in
                                    ReviewFixProposalRow(proposal: proposal) {
                                        model.applyReviewFixProposal(proposal)
                                    }
                                }
                            }
                        }

                        ReviewPrepSection(title: "Validation") {
                            if model.validationIssues.isEmpty {
                                Label("No validation issues", systemImage: "checkmark.circle")
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(OrbiterColor.success)
                                    .padding(8)
                            } else {
                                ForEach(model.validationIssues) { issue in
                                    ValidationIssueRow(issue: issue) {
                                        model.focusValidationIssue(issue)
                                        model.sidebarSelection = .copyWorkspace
                                    }
                                }
                            }
                        }

                        ReviewPrepSection(title: "Media Validation") {
                            if model.mediaValidationIssues.isEmpty {
                                Label("No media validation issues", systemImage: "checkmark.circle")
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(OrbiterColor.success)
                                    .padding(8)
                            } else {
                                ForEach(model.mediaValidationIssues.prefix(8)) { issue in
                                    Button {
                                        openMediaIssue(issue)
                                    } label: {
                                        MediaValidationIssueRow(issue: issue)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Open media asset set")
                                }

                                if model.mediaValidationIssues.count > 8 {
                                    Button {
                                        model.sidebarSelection = .mediaAssets
                                    } label: {
                                        Label("Open all \(model.mediaValidationIssues.count) media issues", systemImage: "photo.on.rectangle")
                                    }
                                    .buttonStyle(.orbiter(.secondary, size: .compact))
                                    .padding(.horizontal, 8)
                                }
                            }
                        }

                        ReviewPrepSection(title: "Pricing Validation") {
                            if model.pricingAvailabilityIssues.isEmpty {
                                Label("No pricing or availability issues", systemImage: "checkmark.circle")
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(OrbiterColor.success)
                                    .padding(8)
                            } else {
                                ForEach(model.pricingAvailabilityIssues) { issue in
                                    Button {
                                        openPricingIssue(issue)
                                    } label: {
                                        PricingAvailabilityIssueRow(issue: issue)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Open pricing and availability")
                                }
                            }
                        }

                        ReviewPrepSection(title: "App Privacy") {
                            if model.appPrivacyIssues.isEmpty {
                                Label("No App Privacy issues", systemImage: "checkmark.circle")
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(OrbiterColor.success)
                                    .padding(8)
                            } else {
                                ForEach(model.appPrivacyIssues) { issue in
                                    Button {
                                        openAppPrivacyIssue(issue)
                                    } label: {
                                        AppPrivacyIssueRow(issue: issue)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Open App Privacy")
                                }
                            }
                        }

                        ReviewPrepSection(title: "Submission Setup") {
                            if model.submissionSetupIssues.isEmpty {
                                Label("No submission setup issues", systemImage: "checkmark.circle")
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(OrbiterColor.success)
                                    .padding(8)
                            } else {
                                ForEach(model.submissionSetupIssues) { issue in
                                    Button {
                                        openSubmissionSetupIssue(issue)
                                    } label: {
                                        SubmissionSetupIssueRow(issue: issue)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Open Submission Setup")
                                }
                            }
                        }

                        ReviewPrepSection(title: "Ratings and Compliance") {
                            if model.ratingsComplianceIssues.isEmpty {
                                Label("No ratings or compliance issues", systemImage: "checkmark.circle")
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(OrbiterColor.success)
                                    .padding(8)
                            } else {
                                ForEach(model.ratingsComplianceIssues) { issue in
                                    Button {
                                        openRatingsComplianceIssue(issue)
                                    } label: {
                                        RatingsComplianceIssueRow(issue: issue)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Open Ratings and Compliance")
                                }
                            }
                        }

                        ReviewPrepSection(title: "Draft Changes") {
                            if model.publishPlan.visibleActions.isEmpty {
                                Text("No draft changes")
                                    .font(.callout)
                                    .foregroundStyle(OrbiterColor.textMuted)
                                    .padding(8)
                            } else {
                                ForEach(model.publishPlan.visibleActions) { action in
                                    ChangeActionRow(
                                        action: action,
                                        document: model.metadataDocument,
                                        baseline: model.baselineDocument
                                    )
                                }
                            }
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: 920, alignment: .leading)
                }
                .background(OrbiterColor.canvas)
            }
        }
        .navigationTitle("Review Prep")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Review Prep")
                    .font(.title2.weight(.semibold))
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(OrbiterColor.textMuted)
            }

            Spacer()

            Button {
                copyReport()
            } label: {
                Label(didCopyReport ? "Copied" : "Copy Report", systemImage: didCopyReport ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.orbiter(.secondary, size: .compact))

            Button {
                exportHandoffPackage()
            } label: {
                Label("Export Handoff", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.orbiter(.secondary, size: .compact))

            Button {
                model.sidebarSelection = .copyWorkspace
            } label: {
                Label("Open Copy", systemImage: "globe")
            }
            .buttonStyle(.orbiter(.secondary, size: .compact))

            Button {
                model.sidebarSelection = .mediaAssets
            } label: {
                Label("Open Media", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.orbiter(.secondary, size: .compact))
            .disabled(model.mediaAssetCatalog == nil)

            Button {
                model.sidebarSelection = .pricingAvailability
            } label: {
                Label("Open Pricing", systemImage: "tag")
            }
            .buttonStyle(.orbiter(.secondary, size: .compact))
            .disabled(model.pricingAvailability == nil)

            Button {
                model.sidebarSelection = .appPrivacy
            } label: {
                Label("Open Privacy", systemImage: "hand.raised")
            }
            .buttonStyle(.orbiter(.secondary, size: .compact))
            .disabled(model.appPrivacyDisclosure == nil)

            Button {
                model.sidebarSelection = .submissionSetup
            } label: {
                Label("Open Submission", systemImage: "shippingbox")
            }
            .buttonStyle(.orbiter(.secondary, size: .compact))
            .disabled(model.submissionSetup == nil)

            Button {
                model.sidebarSelection = .ratingsCompliance
            } label: {
                Label("Open Ratings", systemImage: "shield.lefthalf.filled")
            }
            .buttonStyle(.orbiter(.secondary, size: .compact))
            .disabled(model.ratingsCompliance == nil)
        }
    }

    private var subtitle: String {
        let appName = model.selectedApp?.name ?? "No app"
        let version = model.selectedVersion?.versionString ?? "No version"
        return "\(appName) · \(version) · preflight, not App Review approval"
    }

    private func copyReport() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(model.reviewReportMarkdown(), forType: .string)
        model.metadataSaveStatusMessage = String(localized: "Copied review report.")
        didCopyReport = true
    }

    private func exportHandoffPackage() {
        guard let document = model.metadataDocument else {
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export"
        panel.message = "Choose a folder for the review handoff package."

        guard panel.runModal() == .OK, let directoryURL = panel.url else {
            return
        }

        do {
            model.updateValidation()
            let hasAccess = directoryURL.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    directoryURL.stopAccessingSecurityScopedResource()
                }
            }
            let packageURL = try MetadataReviewHandoffPackage.write(
                context: MetadataReviewHandoffContext(
                    appName: model.selectedApp?.name ?? "",
                    versionString: model.selectedVersion?.versionString ?? "",
                    sourceMode: model.dataSourceMode.rawValue,
                    generatedAt: .now,
                    document: document,
                    baseline: model.baselineDocument,
                    readinessItems: model.releaseReadinessItems,
                    checklistItems: model.reviewChecklistItems,
                    fixProposals: model.reviewFixProposals,
                    validationIssues: model.validationIssues,
                    mediaValidationIssues: model.mediaValidationIssues,
                    pricingAvailabilityIssues: model.pricingAvailabilityIssues,
                    appPrivacyIssues: model.appPrivacyIssues,
                    submissionSetupIssues: model.submissionSetupIssues,
                    ratingsComplianceIssues: model.ratingsComplianceIssues,
                    plan: model.publishPlan
                ),
                to: directoryURL
            )
            model.workspaceNoticeMessage = String(localized: "Exported review handoff package: \(packageURL.lastPathComponent).")
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }

    private func openChecklistItem(_ item: ReviewChecklistItem) {
        if item.title == "Localized Media" {
            model.selectedMediaLocaleID = item.affectedLocales.first ?? model.selectedMediaLocaleID
            model.sidebarSelection = .mediaAssets
            model.workspaceNoticeMessage = String(localized: "Opened media assets from \(item.title).")
            return
        }

        if item.title == "Pricing And Availability" {
            model.sidebarSelection = .pricingAvailability
            model.workspaceNoticeMessage = String(localized: "Opened pricing and availability from \(item.title).")
            return
        }

        if item.title == "App Privacy" {
            model.sidebarSelection = .appPrivacy
            model.workspaceNoticeMessage = String(localized: "Opened App Privacy from \(item.title).")
            return
        }

        if item.title == "Submission Setup" {
            model.sidebarSelection = .submissionSetup
            model.workspaceNoticeMessage = String(localized: "Opened Submission Setup from \(item.title).")
            return
        }

        if item.title == "Ratings And Compliance" {
            model.sidebarSelection = .ratingsCompliance
            model.workspaceNoticeMessage = String(localized: "Opened Ratings and Compliance from \(item.title).")
            return
        }

        guard let locale = item.affectedLocales.first else {
            return
        }

        model.selectedLocaleID = locale
        model.detailSelection = .localizedCopy
        model.sidebarSelection = .copyWorkspace
        model.workspaceNoticeMessage = String(localized: "Opened \(locale) from \(item.title).")
    }

    private func openMediaIssue(_ issue: StoreMediaValidationIssue) {
        model.selectedMediaLocaleID = issue.locale
        model.sidebarSelection = .mediaAssets
        model.workspaceNoticeMessage = String(localized: "Opened \(issue.locale) media assets.")
    }

    private func openPricingIssue(_ issue: PricingAvailabilityIssue) {
        model.sidebarSelection = .pricingAvailability
        model.workspaceNoticeMessage = String(localized: "Opened pricing issue: \(issue.title).")
    }

    private func openAppPrivacyIssue(_ issue: AppPrivacyIssue) {
        model.sidebarSelection = .appPrivacy
        model.workspaceNoticeMessage = String(localized: "Opened App Privacy issue: \(issue.title).")
    }

    private func openSubmissionSetupIssue(_ issue: SubmissionSetupIssue) {
        model.sidebarSelection = .submissionSetup
        model.workspaceNoticeMessage = String(localized: "Opened submission setup issue: \(issue.title).")
    }

    private func openRatingsComplianceIssue(_ issue: RatingsComplianceIssue) {
        model.sidebarSelection = .ratingsCompliance
        model.workspaceNoticeMessage = String(localized: "Opened ratings issue: \(issue.title).")
    }
}

struct ReviewPrepSummaryPanel: View {
    var summary: ReviewPrepSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: summary.nextAction.systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.nextAction.title)
                        .font(.headline.weight(.semibold))
                    Text(summary.nextAction.detail)
                        .font(.callout)
                        .foregroundStyle(OrbiterColor.textMuted)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                ReviewPrepMetricTile(title: "Blockers", value: "\(summary.blockerCount)", tone: summary.blockerCount > 0 ? .danger : .success)
                ReviewPrepMetricTile(title: "Warnings", value: "\(summary.warningCount)", tone: summary.warningCount > 0 ? .warning : .success)
                ReviewPrepMetricTile(title: "Fixes", value: "\(summary.proposedFixCount)", tone: summary.proposedFixCount > 0 ? .accent : .neutral)
                ReviewPrepMetricTile(title: "Drafts", value: "\(summary.draftActionCount)", tone: summary.draftActionCount > 0 ? .accent : .neutral)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .orbiterPanel(padding: 12, surface: background)
    }

    private var tint: Color {
        switch summary.nextAction.level {
        case .ready:
            OrbiterColor.success
        case .warning:
            OrbiterColor.warning
        case .blocking:
            OrbiterColor.danger
        }
    }

    private var background: Color {
        switch summary.nextAction.level {
        case .ready:
            OrbiterColor.successSoft
        case .warning:
            OrbiterColor.warningSoft
        case .blocking:
            OrbiterColor.dangerSoft
        }
    }
}

struct ReviewPrepMetricTile: View {
    var title: String
    var value: String
    var tone: OrbiterBadgeTone

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.callout.weight(.semibold))
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(OrbiterColor.textSubtle)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        .background(tone.background, in: RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous)
                .stroke(tone.foreground.opacity(0.18), lineWidth: OrbiterMetric.hairline)
        }
    }
}

struct ReviewFixProposalRow: View {
    var proposal: ReviewFixProposal
    var apply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(proposal.title, systemImage: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(OrbiterColor.accent)

                OrbiterBadge(text: proposal.locale, tone: .neutral)

                Spacer(minLength: 8)

                Button {
                    apply()
                } label: {
                    Label("Apply", systemImage: "checkmark")
                }
                .buttonStyle(.orbiter(.secondary, size: .compact))
            }

            Text(proposal.detail)
                .font(.caption)
                .foregroundStyle(OrbiterColor.textMuted)

            VStack(alignment: .leading, spacing: 4) {
                ReviewFixValueRow(title: "Before", value: proposal.before)
                ReviewFixValueRow(title: "After", value: proposal.after)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OrbiterColor.panelRaised, in: RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous)
                .stroke(OrbiterColor.border, lineWidth: OrbiterMetric.hairline)
        }
    }

    private var systemImage: String {
        switch proposal.kind {
        case .upgradeHTTPS:
            "lock.shield"
        case .normalizeKeywords:
            "line.3.horizontal.decrease.circle"
        }
    }
}

struct ReviewFixValueRow: View {
    var title: String
    var value: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(OrbiterColor.textSubtle)
                .frame(width: 42, alignment: .leading)
            Text(value.isEmpty ? "Empty" : value)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .textSelection(.enabled)
        }
    }
}

struct ReviewPrepSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            OrbiterSectionLabel(title: title)
                .padding(.horizontal, 0)

            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .orbiterPanel(padding: 10)
        }
    }
}
