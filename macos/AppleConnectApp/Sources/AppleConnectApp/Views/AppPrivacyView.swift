import SwiftUI

struct AppPrivacySummaryView: View {
    @Bindable var model: AppModel

    var body: some View {
        SummaryPage(title: "App Privacy") {
            SummarySection(title: "Current Version") {
                if let app = model.selectedApp, let version = model.selectedVersion {
                    StatusRow(title: "App", detail: LocalizedStringKey(app.name), systemImage: "app")
                    StatusRow(title: "Version", detail: LocalizedStringKey(version.versionString), systemImage: "number")
                    StatusRow(title: "Status", detail: statusText, systemImage: statusImage)
                } else {
                    StatusRow(title: "Selection", detail: "Select version", systemImage: "doc.text.magnifyingglass")
                }
            }

            SummarySection(title: "Privacy Responses") {
                if let disclosure = model.appPrivacyDisclosure {
                    StatusRow(title: "Privacy Policy", detail: LocalizedStringKey(disclosure.privacyPolicyURL.isEmpty ? "Missing" : "Present"), systemImage: "link")
                    StatusRow(title: "Data Types", detail: "\(disclosure.dataTypeCount)", systemImage: "list.bullet.rectangle")
                    StatusRow(title: "Tracking", detail: "\(disclosure.trackingDataTypeCount)", systemImage: "scope")
                } else {
                    StatusRow(title: "App Privacy", detail: "Select version", systemImage: "hand.raised")
                }
            }

            SummarySection(title: "Actions") {
                Button("Open App Privacy") {
                    model.sidebarSelection = .appPrivacy
                }
                .buttonStyle(.orbiter(.secondary))
                .disabled(model.appPrivacyDisclosure == nil)
            }
        }
        .navigationTitle("App Privacy")
    }

    private var statusText: LocalizedStringKey {
        let summary = model.appPrivacySummary
        if summary.blockingCount > 0 {
            return "\(summary.blockingCount) blocking"
        }

        if summary.warningCount > 0 {
            return "\(summary.warningCount) warnings"
        }

        return model.appPrivacyDisclosure == nil ? "Select version" : "Ready"
    }

    private var statusImage: String {
        let summary = model.appPrivacySummary
        if summary.blockingCount > 0 {
            return "xmark.octagon"
        }

        if summary.warningCount > 0 {
            return "exclamationmark.triangle"
        }

        return "checkmark.circle"
    }
}

struct AppPrivacyView: View {
    @Bindable var model: AppModel
    @State private var selectedDataType: AppPrivacyDataType = .identifiers

    var body: some View {
        Group {
            if let disclosure = model.appPrivacyDisclosure {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header(disclosure: disclosure)
                        AppPrivacySummaryPanel(summary: model.appPrivacySummary)
                        AppPrivacyReviewBanner(
                            summary: model.appPrivacySummary,
                            issues: model.appPrivacyIssues
                        ) {
                            model.sidebarSelection = .reviewPrep
                        }
                        AppPrivacyPolicyPanel(model: model, disclosure: disclosure)
                        AppPrivacyDataTypesPanel(
                            model: model,
                            disclosure: disclosure,
                            selectedDataType: $selectedDataType
                        )
                        AppPrivacyIssuesPanel(issues: model.appPrivacyIssues)
                    }
                    .padding(24)
                    .frame(maxWidth: 980, alignment: .leading)
                }
                .background(OrbiterColor.canvas)
            } else {
                EmptyStateView(
                    title: "App Privacy",
                    systemImage: "hand.raised",
                    message: "Select an app and version to manage privacy policy links and App Store privacy label responses."
                )
            }
        }
        .navigationTitle("App Privacy")
    }

    private func header(disclosure: AppPrivacyDisclosure) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("App Privacy")
                    .font(.title2.weight(.semibold))
                Text(subtitle(disclosure: disclosure))
                    .font(.callout)
                    .foregroundStyle(OrbiterColor.textMuted)
            }

            Spacer()

            OrbiterBadge(
                text: disclosure.doesCollectData ? "Collects Data" : "No Data Collected",
                systemImage: disclosure.doesCollectData ? "list.bullet.rectangle" : "checkmark.shield",
                tone: disclosure.doesCollectData ? .neutral : .success
            )
        }
    }

    private func subtitle(disclosure: AppPrivacyDisclosure) -> String {
        let appName = model.selectedApp?.name ?? "No app"
        let version = model.selectedVersion?.versionString ?? "No version"
        let published = disclosure.lastPublishedAt == nil ? "not published" : "published"
        return "\(appName) · \(version) · \(published) privacy responses"
    }
}

struct AppPrivacySummaryPanel: View {
    var summary: AppPrivacySummary

    var body: some View {
        HStack(spacing: 8) {
            ReviewPrepMetricTile(title: "Data Types", value: "\(summary.dataTypeCount)", tone: summary.dataTypeCount > 0 ? .accent : .neutral)
            ReviewPrepMetricTile(title: "Linked", value: "\(summary.linkedDataTypeCount)", tone: summary.linkedDataTypeCount > 0 ? .warning : .success)
            ReviewPrepMetricTile(title: "Tracking", value: "\(summary.trackingDataTypeCount)", tone: summary.trackingDataTypeCount > 0 ? .warning : .success)
            ReviewPrepMetricTile(title: "Issues", value: "\(summary.blockingCount + summary.warningCount)", tone: issueTone)
        }
    }

    private var issueTone: OrbiterBadgeTone {
        if summary.blockingCount > 0 {
            return .danger
        }

        if summary.warningCount > 0 {
            return .warning
        }

        return .success
    }
}

struct AppPrivacyReviewBanner: View {
    var summary: AppPrivacySummary
    var issues: [AppPrivacyIssue]
    var openReviewPrep: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(OrbiterColor.textMuted)
            }

            Spacer(minLength: 12)

            Button {
                openReviewPrep()
            } label: {
                Label("Review Prep", systemImage: "checklist")
            }
            .buttonStyle(.orbiter(.secondary, size: .compact))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .orbiterPanel(padding: 12, surface: background)
    }

    private var title: String {
        if summary.blockingCount > 0 {
            return "App Privacy blocks release prep"
        }

        if summary.warningCount > 0 {
            return "App Privacy needs review"
        }

        return "App Privacy ready"
    }

    private var detail: String {
        if let firstBlocking = issues.first(where: { $0.severity == .blocking }) {
            return "\(firstBlocking.title): \(firstBlocking.detail)"
        }

        if let firstWarning = issues.first(where: { $0.severity == .warning }) {
            return "\(firstWarning.title): \(firstWarning.detail)"
        }

        return "\(summary.dataTypeCount) data types are configured for the App Store privacy label."
    }

    private var systemImage: String {
        if summary.blockingCount > 0 {
            return "xmark.octagon"
        }

        if summary.warningCount > 0 {
            return "exclamationmark.triangle"
        }

        return "checkmark.circle"
    }

    private var tint: Color {
        if summary.blockingCount > 0 {
            return OrbiterColor.danger
        }

        if summary.warningCount > 0 {
            return OrbiterColor.warning
        }

        return OrbiterColor.success
    }

    private var background: Color {
        if summary.blockingCount > 0 {
            return OrbiterColor.dangerSoft
        }

        if summary.warningCount > 0 {
            return OrbiterColor.warningSoft
        }

        return OrbiterColor.successSoft
    }
}

struct AppPrivacyPolicyPanel: View {
    @Bindable var model: AppModel
    var disclosure: AppPrivacyDisclosure

    var body: some View {
        ReviewPrepSection(title: "Policy Links") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("App or third-party partners collect data", isOn: collectsDataBinding)
                    .font(.callout.weight(.medium))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Privacy Policy URL")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(OrbiterColor.textMuted)
                    TextField("https://example.com/privacy", text: privacyPolicyURLBinding)
                        .orbiterInputChrome(isInvalid: hasPolicyURLBlocker)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("User Privacy Choices URL")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(OrbiterColor.textMuted)
                    TextField("https://example.com/privacy/choices", text: privacyChoicesURLBinding)
                        .orbiterInputChrome(isInvalid: hasChoicesURLBlocker)
                }
            }
        }
    }

    private var collectsDataBinding: Binding<Bool> {
        Binding(
            get: { disclosure.doesCollectData },
            set: { model.setAppPrivacyCollectsData($0) }
        )
    }

    private var privacyPolicyURLBinding: Binding<String> {
        Binding(
            get: { disclosure.privacyPolicyURL },
            set: { model.updateAppPrivacyPolicyURL($0) }
        )
    }

    private var privacyChoicesURLBinding: Binding<String> {
        Binding(
            get: { disclosure.privacyChoicesURL },
            set: { model.updateAppPrivacyChoicesURL($0) }
        )
    }

    private var hasPolicyURLBlocker: Bool {
        AppPrivacyValidator.issues(for: disclosure).contains {
            $0.severity == .blocking && $0.title.localizedCaseInsensitiveContains("privacy policy")
        }
    }

    private var hasChoicesURLBlocker: Bool {
        AppPrivacyValidator.issues(for: disclosure).contains {
            $0.severity == .blocking && $0.title.localizedCaseInsensitiveContains("choices")
        }
    }
}

struct AppPrivacyDataTypesPanel: View {
    @Bindable var model: AppModel
    var disclosure: AppPrivacyDisclosure
    @Binding var selectedDataType: AppPrivacyDataType

    private let columns = [
        GridItem(.adaptive(minimum: 220), spacing: 8, alignment: .top)
    ]

    var body: some View {
        ReviewPrepSection(title: "Data Types") {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(AppPrivacyDataType.allCases) { dataType in
                    AppPrivacyDataTypeRow(
                        dataType: dataType,
                        disclosure: disclosure.disclosure(for: dataType),
                        isSelected: selectedDataType == dataType,
                        isEnabled: disclosure.disclosure(for: dataType) != nil,
                        select: { selectedDataType = dataType },
                        toggle: { isEnabled in
                            model.setAppPrivacyDataType(dataType, isEnabled: isEnabled)
                            selectedDataType = dataType
                        }
                    )
                }
            }

            if let selectedDisclosure = disclosure.disclosure(for: selectedDataType) {
                AppPrivacyDataTypeDetailPanel(
                    model: model,
                    disclosure: selectedDisclosure
                )
            } else {
                HStack(spacing: 8) {
                    Image(systemName: selectedDataType.systemImage)
                        .foregroundStyle(OrbiterColor.textMuted)
                    Text("Enable \(selectedDataType.title) to answer its purposes, linked data, and tracking questions.")
                        .font(.callout)
                        .foregroundStyle(OrbiterColor.textMuted)
                }
                .padding(8)
            }
        }
    }
}

struct AppPrivacyDataTypeRow: View {
    var dataType: AppPrivacyDataType
    var disclosure: AppPrivacyDataDisclosure?
    var isSelected: Bool
    var isEnabled: Bool
    var select: () -> Void
    var toggle: (Bool) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: select) {
                VStack(alignment: .leading, spacing: 5) {
                    Label(dataType.title, systemImage: dataType.systemImage)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)

                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(OrbiterColor.textMuted)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
            }
            .buttonStyle(.plain)

            Toggle("", isOn: toggleBinding)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(8)
        .background(isSelected ? OrbiterColor.selected : OrbiterColor.panelRaised, in: RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous)
                .stroke(isSelected ? OrbiterColor.accent.opacity(0.24) : OrbiterColor.border, lineWidth: OrbiterMetric.hairline)
        }
    }

    private var detail: String {
        guard let disclosure else {
            return "Not collected"
        }

        if disclosure.purposes.isEmpty {
            return "Needs purposes"
        }

        if disclosure.isUsedForTracking {
            return "Tracking · \(disclosure.purposeSummary)"
        }

        if disclosure.isLinkedToUser {
            return "Linked · \(disclosure.purposeSummary)"
        }

        return disclosure.purposeSummary
    }

    private var toggleBinding: Binding<Bool> {
        Binding(
            get: { isEnabled },
            set: { newValue in
                toggle(newValue)
            }
        )
    }
}

struct AppPrivacyDataTypeDetailPanel: View {
    @Bindable var model: AppModel
    var disclosure: AppPrivacyDataDisclosure

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(disclosure.dataType.title, systemImage: disclosure.dataType.systemImage)
                    .font(.callout.weight(.semibold))

                Spacer()

                if disclosure.purposes.isEmpty {
                    OrbiterBadge(text: "Needs Purposes", systemImage: "exclamationmark.triangle", tone: .danger)
                } else if disclosure.isUsedForTracking {
                    OrbiterBadge(text: "Tracking", systemImage: "scope", tone: .warning)
                } else if disclosure.isLinkedToUser {
                    OrbiterBadge(text: "Linked", systemImage: "link", tone: .warning)
                } else {
                    OrbiterBadge(text: "Ready", systemImage: "checkmark", tone: .success)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Purposes")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(OrbiterColor.textMuted)

                ForEach(AppPrivacyPurpose.allCases) { purpose in
                    Toggle(purpose.title, isOn: purposeBinding(purpose))
                }
            }

            OrbiterDivider()

            Toggle("Linked to the user", isOn: linkedBinding)
            Toggle("Used for tracking", isOn: trackingBinding)

            if !disclosure.note.isEmpty {
                Text(disclosure.note)
                    .font(.caption)
                    .foregroundStyle(OrbiterColor.textMuted)
            }
        }
        .padding(10)
        .background(OrbiterColor.panelRaised, in: RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous)
                .stroke(OrbiterColor.border, lineWidth: OrbiterMetric.hairline)
        }
    }

    private func purposeBinding(_ purpose: AppPrivacyPurpose) -> Binding<Bool> {
        Binding(
            get: { disclosure.purposes.contains(purpose) },
            set: { model.setAppPrivacyPurpose(dataType: disclosure.dataType, purpose: purpose, isEnabled: $0) }
        )
    }

    private var linkedBinding: Binding<Bool> {
        Binding(
            get: { disclosure.isLinkedToUser },
            set: { model.setAppPrivacyLinked(dataType: disclosure.dataType, isLinked: $0) }
        )
    }

    private var trackingBinding: Binding<Bool> {
        Binding(
            get: { disclosure.isUsedForTracking },
            set: { model.setAppPrivacyTracking(dataType: disclosure.dataType, isTracking: $0) }
        )
    }
}

struct AppPrivacyIssuesPanel: View {
    var issues: [AppPrivacyIssue]

    var body: some View {
        ReviewPrepSection(title: "Privacy Validation") {
            if issues.isEmpty {
                Label("No App Privacy issues", systemImage: "checkmark.circle")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(OrbiterColor.success)
                    .padding(8)
            } else {
                ForEach(issues) { issue in
                    AppPrivacyIssueRow(issue: issue)
                }
            }
        }
    }
}

struct AppPrivacyIssueRow: View {
    var issue: AppPrivacyIssue

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: issue.severity == .blocking ? "xmark.octagon" : "exclamationmark.triangle")
                .foregroundStyle(issue.severity == .blocking ? OrbiterColor.danger : OrbiterColor.warning)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(issue.title)
                    .font(.callout.weight(.semibold))
                Text(issue.detail)
                    .font(.caption)
                    .foregroundStyle(OrbiterColor.textMuted)
                if !issue.affectedDataTypes.isEmpty {
                    Text(issue.affectedDataTypes.map(\.title).joined(separator: ", "))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(OrbiterColor.textSubtle)
                }
            }

            Spacer()
        }
        .padding(8)
        .background(issue.severity == .blocking ? OrbiterColor.dangerSoft : OrbiterColor.warningSoft, in: RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous)
                .stroke((issue.severity == .blocking ? OrbiterColor.danger : OrbiterColor.warning).opacity(0.2), lineWidth: OrbiterMetric.hairline)
        }
    }
}
