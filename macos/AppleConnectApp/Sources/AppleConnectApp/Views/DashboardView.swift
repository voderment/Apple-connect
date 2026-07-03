import SwiftUI

struct DashboardView: View {
    @Bindable var model: AppModel

    var body: some View {
        SummaryPage(title: AppConstants.productName) {
            SummarySection(title: "Start") {
                StatusRow(
                    title: "Apple Account",
                    detail: model.userSession == nil ? "Not signed in" : "Signed in",
                    systemImage: "person.crop.circle"
                )
                StatusRow(
                    title: "App Store Connect",
                    detail: connectionStatusText,
                    systemImage: model.dataSourceMode.systemImage
                )
                StatusRow(
                    title: "Model Provider",
                    detail: model.providerConfiguration.isConfigured ? "Configured" : "Not configured",
                    systemImage: "sparkles"
                )
            }

            SummarySection(title: "Workspaces") {
                Button {
                    model.sidebarSelection = .copyWorkspace
                } label: {
                    StatusRow(title: "Localized Copy", detail: localizedCopyStatusText, systemImage: "globe")
                }
                .buttonStyle(.plain)

                Button {
                    model.sidebarSelection = .reviewPrep
                } label: {
                    StatusRow(title: "Review Prep", detail: reviewPrepStatusText, systemImage: "checklist")
                }
                .buttonStyle(.plain)

                Button {
                    model.sidebarSelection = .mediaAssets
                } label: {
                    StatusRow(title: "Media Assets", detail: mediaAssetsStatusText, systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.plain)

                Button {
                    model.sidebarSelection = .pricingAvailability
                } label: {
                    StatusRow(title: "Pricing and Availability", detail: pricingAvailabilityStatusText, systemImage: "tag")
                }
                .buttonStyle(.plain)

                Button {
                    model.sidebarSelection = .appPrivacy
                } label: {
                    StatusRow(title: "App Privacy", detail: appPrivacyStatusText, systemImage: "hand.raised")
                }
                .buttonStyle(.plain)

                Button {
                    model.sidebarSelection = .submissionSetup
                } label: {
                    StatusRow(title: "Submission Setup", detail: submissionSetupStatusText, systemImage: "shippingbox")
                }
                .buttonStyle(.plain)

                Button {
                    model.sidebarSelection = .ratingsCompliance
                } label: {
                    StatusRow(title: "Ratings and Compliance", detail: ratingsComplianceStatusText, systemImage: "shield.lefthalf.filled")
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(AppConstants.productName)
    }

    private var connectionStatusText: LocalizedStringKey {
        if model.isDemoMode {
            return "Demo workspace"
        }

        switch model.activeConnection.status {
        case .notVerified:
            return "Not verified"
        case let .verified(visibleAppCount):
            return "\(visibleAppCount) visible apps"
        case .failed:
            return "Failed"
        }
    }

    private var localizedCopyStatusText: LocalizedStringKey {
        guard model.metadataDocument != nil else {
            return "Select version"
        }

        let blockingCount = model.releaseReadinessItems.filter { $0.level == .blocking }.count
        if blockingCount > 0 {
            return "\(blockingCount) blocking"
        }

        let warningCount = model.releaseReadinessItems.filter { $0.level == .warning }.count
        if warningCount > 0 {
            return "\(warningCount) warnings"
        }

        return "Ready"
    }

    private var reviewPrepStatusText: LocalizedStringKey {
        guard model.metadataDocument != nil else {
            return "Select version"
        }

        if model.reviewChecklistItems.contains(where: { $0.level == .blocking }) {
            return "Blocked"
        }

        let warningCount = model.reviewChecklistItems.filter { $0.level == .warning }.count
        if warningCount > 0 {
            return "\(warningCount) to review"
        }

        return "Ready"
    }

    private var mediaAssetsStatusText: LocalizedStringKey {
        guard model.mediaAssetCatalog != nil else {
            return "Select version"
        }

        let summary = model.mediaValidationSummary
        if summary.blockingCount > 0 {
            return "\(summary.blockingCount) blocking"
        }

        if summary.warningCount > 0 {
            return "\(summary.warningCount) warnings"
        }

        return "\(summary.completeRequiredSetCount)/\(summary.requiredSetCount) ready"
    }

    private var pricingAvailabilityStatusText: LocalizedStringKey {
        guard model.pricingAvailability != nil else {
            return "Select version"
        }

        let summary = model.pricingAvailabilitySummary
        if summary.blockingCount > 0 {
            return "\(summary.blockingCount) blocking"
        }

        if summary.warningCount > 0 {
            return "\(summary.warningCount) warnings"
        }

        return "\(summary.customerVisibleTerritoryCount)/\(summary.territoryCount) storefronts"
    }

    private var appPrivacyStatusText: LocalizedStringKey {
        guard model.appPrivacyDisclosure != nil else {
            return "Select version"
        }

        let summary = model.appPrivacySummary
        if summary.blockingCount > 0 {
            return "\(summary.blockingCount) blocking"
        }

        if summary.warningCount > 0 {
            return "\(summary.warningCount) warnings"
        }

        return "\(summary.dataTypeCount) data types"
    }

    private var submissionSetupStatusText: LocalizedStringKey {
        guard model.submissionSetup != nil else {
            return "Select version"
        }

        let summary = model.submissionSetupSummary
        if summary.blockingCount > 0 {
            return "\(summary.blockingCount) blocking"
        }

        if summary.warningCount > 0 {
            return "\(summary.warningCount) warnings"
        }

        return summary.hasSelectedBuild ? "Build selected" : "Select build"
    }

    private var ratingsComplianceStatusText: LocalizedStringKey {
        guard model.ratingsCompliance != nil else {
            return "Select version"
        }

        let summary = model.ratingsComplianceSummary
        if summary.blockingCount > 0 {
            return "\(summary.blockingCount) blocking"
        }

        if summary.warningCount > 0 {
            return "\(summary.warningCount) warnings"
        }

        return "Age \(summary.estimatedAgeRating)"
    }
}

struct StatusRow: View {
    var title: LocalizedStringKey
    var detail: LocalizedStringKey
    var systemImage: String
    var isMuted = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .frame(width: 20)
                .foregroundStyle(isMuted ? OrbiterColor.textSubtle : OrbiterColor.textMuted)
            Text(title)
                .foregroundStyle(isMuted ? OrbiterColor.textSubtle : Color.primary)
            Spacer()
            Text(detail)
                .font(.caption.weight(.medium))
                .foregroundStyle(isMuted ? OrbiterColor.textSubtle : OrbiterColor.textMuted)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 34)
    }
}

struct ConnectionSummaryView: View {
    @Bindable var model: AppModel

    var body: some View {
        SummaryPage(title: "Connection") {
            SummarySection(title: "Connection") {
                StatusRow(
                    title: "Mode",
                    detail: LocalizedStringKey(model.dataSourceMode.title),
                    systemImage: model.dataSourceMode.systemImage
                )
                Text(model.activeConnection.name)
                    .font(.callout.weight(.medium))
                Text(model.activeConnection.keyID.isEmpty ? "No Key ID" : model.activeConnection.keyID)
                    .font(.caption)
                    .foregroundStyle(OrbiterColor.textMuted)
            }
            SummarySection(title: "Actions") {
                Button("Open Connection Setup") {
                    model.sidebarSelection = .connection
                }
                .buttonStyle(.orbiter(.secondary))
            }
        }
        .navigationTitle("Connection")
    }
}

struct CopyWorkspaceOverviewView: View {
    @Bindable var model: AppModel

    var body: some View {
        SummaryPage(title: "Localized Copy") {
            SummarySection(title: "Localized Copy") {
                Text("Select an app and version to edit localized App Store metadata. This is the first workspace; screenshots, pricing, builds, and review details can follow the same shell.")
                    .font(.callout)
                    .foregroundStyle(OrbiterColor.textMuted)
                if let selectedApp = model.selectedApp {
                    Text("Current app: \(selectedApp.name)")
                        .font(.caption)
                        .foregroundStyle(OrbiterColor.textMuted)
                }
            }

            if !model.apps.isEmpty {
                SummarySection(title: "Apps") {
                    ForEach(model.apps) { app in
                        Button {
                            Task { await model.selectApp(app) }
                        } label: {
                            VStack(alignment: .leading) {
                                Text(app.name)
                                    .font(.callout.weight(.medium))
                                Text(app.bundleID)
                                    .font(.caption)
                                    .foregroundStyle(OrbiterColor.textMuted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Localized Copy")
    }
}

struct LLMProviderSummaryView: View {
    @Bindable var model: AppModel

    var body: some View {
        SummaryPage(title: "Model Provider") {
            SummarySection(title: "Provider") {
                StatusRow(
                    title: "Type",
                    detail: LocalizedStringKey(model.providerConfiguration.kind.title),
                    systemImage: "sparkles"
                )
                StatusRow(
                    title: "Model",
                    detail: LocalizedStringKey(model.providerConfiguration.model),
                    systemImage: "cpu"
                )
            }
        }
        .navigationTitle("Model Provider")
    }
}

struct SettingsSummaryView: View {
    @Bindable var model: AppModel

    var body: some View {
        SummaryPage(title: "Settings") {
            SummarySection(title: "Appearance") {
                StatusRow(
                    title: "Theme",
                    detail: model.theme.title,
                    systemImage: "circle.lefthalf.filled"
                )
            }
        }
        .navigationTitle("Settings")
    }
}

struct SummaryPage<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(LocalizedStringKey(title))
                    .font(.title2.weight(.semibold))

                content
            }
            .padding(24)
            .frame(maxWidth: 720, alignment: .leading)
        }
        .background(OrbiterColor.canvas)
    }
}

struct SummarySection<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            OrbiterSectionLabel(title: title)
                .padding(.horizontal, 0)
            VStack(alignment: .leading, spacing: 2) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .orbiterPanel(padding: 8)
        }
    }
}
