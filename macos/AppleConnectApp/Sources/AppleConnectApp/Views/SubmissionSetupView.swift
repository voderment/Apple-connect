import SwiftUI

struct SubmissionSetupSummaryView: View {
    @Bindable var model: AppModel

    var body: some View {
        SummaryPage(title: "Submission Setup") {
            SummarySection(title: "Current Version") {
                if let app = model.selectedApp, let version = model.selectedVersion {
                    StatusRow(title: "App", detail: LocalizedStringKey(app.name), systemImage: "app")
                    StatusRow(title: "Version", detail: LocalizedStringKey(version.versionString), systemImage: "number")
                    StatusRow(title: "Status", detail: statusText, systemImage: statusImage)
                } else {
                    StatusRow(title: "Selection", detail: "Select version", systemImage: "doc.text.magnifyingglass")
                }
            }

            SummarySection(title: "Submission") {
                if let setup = model.submissionSetup {
                    StatusRow(title: "Build", detail: LocalizedStringKey(setup.selectedBuild?.displayName ?? "Not selected"), systemImage: "shippingbox")
                    StatusRow(title: "Review Contact", detail: LocalizedStringKey(setup.reviewContact.displayName.isEmpty ? "Missing" : setup.reviewContact.displayName), systemImage: "person.crop.circle")
                    StatusRow(title: "Draft Items", detail: "\(setup.draftSubmissionItemCount)", systemImage: "tray.full")
                } else {
                    StatusRow(title: "Submission", detail: "Select version", systemImage: "shippingbox")
                }
            }

            SummarySection(title: "Actions") {
                Button("Open Submission Setup") {
                    model.sidebarSelection = .submissionSetup
                }
                .buttonStyle(.orbiter(.secondary))
                .disabled(model.submissionSetup == nil)
            }
        }
        .navigationTitle("Submission Setup")
    }

    private var statusText: LocalizedStringKey {
        let summary = model.submissionSetupSummary
        if summary.blockingCount > 0 {
            return "\(summary.blockingCount) blocking"
        }

        if summary.warningCount > 0 {
            return "\(summary.warningCount) warnings"
        }

        return model.submissionSetup == nil ? "Select version" : "Ready"
    }

    private var statusImage: String {
        let summary = model.submissionSetupSummary
        if summary.blockingCount > 0 {
            return "xmark.octagon"
        }

        if summary.warningCount > 0 {
            return "exclamationmark.triangle"
        }

        return "checkmark.circle"
    }
}

struct SubmissionSetupView: View {
    @Bindable var model: AppModel

    var body: some View {
        Group {
            if let setup = model.submissionSetup {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header(setup: setup)
                        SubmissionSetupSummaryPanel(summary: model.submissionSetupSummary)
                        SubmissionSetupReviewBanner(
                            summary: model.submissionSetupSummary,
                            issues: model.submissionSetupIssues
                        ) {
                            model.sidebarSelection = .reviewPrep
                        }
                        SubmissionBuildPanel(model: model, setup: setup)
                        SubmissionReviewInfoPanel(model: model, setup: setup)
                        SubmissionReleaseCompliancePanel(model: model, setup: setup)
                        SubmissionSetupIssuesPanel(issues: model.submissionSetupIssues)
                    }
                    .padding(24)
                    .frame(maxWidth: 1040, alignment: .leading)
                }
                .background(OrbiterColor.canvas)
            } else {
                EmptyStateView(
                    title: "Submission Setup",
                    systemImage: "shippingbox",
                    message: "Select an app and version to manage build selection, App Review information, compliance, and release options."
                )
            }
        }
        .navigationTitle("Submission Setup")
    }

    private func header(setup: AppSubmissionSetup) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Submission Setup")
                    .font(.title2.weight(.semibold))
                Text(subtitle(setup: setup))
                    .font(.callout)
                    .foregroundStyle(OrbiterColor.textMuted)
            }

            Spacer()

            OrbiterBadge(text: setup.releaseOption.title, systemImage: "paperplane", tone: .neutral)
        }
    }

    private func subtitle(setup: AppSubmissionSetup) -> String {
        let appName = model.selectedApp?.name ?? "No app"
        let version = model.selectedVersion?.versionString ?? "No version"
        let build = setup.selectedBuild?.displayName ?? "no build selected"
        return "\(appName) · \(version) · \(build)"
    }
}

struct SubmissionSetupSummaryPanel: View {
    var summary: SubmissionSetupSummary

    var body: some View {
        HStack(spacing: 8) {
            ReviewPrepMetricTile(title: "Builds", value: "\(summary.buildCount)", tone: summary.hasSelectedBuild ? .success : .warning)
            ReviewPrepMetricTile(title: "Selected", value: summary.hasSelectedBuild ? "Yes" : "No", tone: summary.hasSelectedBuild ? .success : .danger)
            ReviewPrepMetricTile(title: "Draft Items", value: "\(summary.draftSubmissionItemCount)", tone: summary.draftSubmissionItemCount > 0 ? .success : .warning)
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

struct SubmissionSetupReviewBanner: View {
    var summary: SubmissionSetupSummary
    var issues: [SubmissionSetupIssue]
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
            return "Submission setup blocks review"
        }

        if summary.warningCount > 0 {
            return "Submission setup needs review"
        }

        return "Submission setup ready"
    }

    private var detail: String {
        if let firstBlocking = issues.first(where: { $0.severity == .blocking }) {
            return "\(firstBlocking.title): \(firstBlocking.detail)"
        }

        if let firstWarning = issues.first(where: { $0.severity == .warning }) {
            return "\(firstWarning.title): \(firstWarning.detail)"
        }

        return "Build, App Review details, compliance, and release settings are ready for handoff."
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

struct SubmissionBuildPanel: View {
    @Bindable var model: AppModel
    var setup: AppSubmissionSetup

    var body: some View {
        ReviewPrepSection(title: "Build Candidate") {
            if setup.builds.isEmpty {
                Text("No uploaded builds are available for this version.")
                    .font(.callout)
                    .foregroundStyle(OrbiterColor.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            } else {
                VStack(spacing: 8) {
                    ForEach(setup.builds) { build in
                        Button {
                            model.selectSubmissionBuild(build.id)
                        } label: {
                            SubmissionBuildRow(
                                build: build,
                                isSelected: setup.selectedBuildID == build.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct SubmissionBuildRow: View {
    var build: SubmissionBuildCandidate
    var isSelected: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? OrbiterColor.accent : OrbiterColor.textSubtle)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(build.displayName)
                    .font(.callout.weight(.semibold))
                Text("\(build.platform) · \(build.sdk) · minimum \(build.minOSVersion)")
                    .font(.caption)
                    .foregroundStyle(OrbiterColor.textMuted)
            }

            Spacer()

            Text(build.uploadedAt, format: .dateTime.month().day().hour().minute())
                .font(.caption)
                .foregroundStyle(OrbiterColor.textSubtle)

            OrbiterBadge(text: build.processingState.title, tone: tone)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 54)
        .background(isSelected ? OrbiterColor.accentSoft : OrbiterColor.panel, in: RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous)
                .stroke(isSelected ? OrbiterColor.accent.opacity(0.24) : OrbiterColor.border, lineWidth: OrbiterMetric.hairline)
        }
    }

    private var tone: OrbiterBadgeTone {
        switch build.processingState {
        case .valid:
            .success
        case .processing:
            .warning
        case .invalid, .expired:
            .danger
        }
    }
}

struct SubmissionReviewInfoPanel: View {
    @Bindable var model: AppModel
    var setup: AppSubmissionSetup

    var body: some View {
        ReviewPrepSection(title: "App Review Information") {
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    labeledField("First Name", text: binding(\.reviewContact.firstName))
                    labeledField("Last Name", text: binding(\.reviewContact.lastName))
                    labeledField("Email", text: binding(\.reviewContact.email))
                    labeledField("Phone", text: binding(\.reviewContact.phone))
                }

                Toggle("Sign-in is required to review this app", isOn: binding(\.demoAccount.isRequired))
                    .toggleStyle(.checkbox)

                if setup.demoAccount.isRequired {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        labeledField("Demo Username", text: binding(\.demoAccount.username))
                        labeledField("Demo Password", text: binding(\.demoAccount.password))
                    }

                    labeledField("Demo Notes", text: binding(\.demoAccount.notes))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Review Notes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(OrbiterColor.textMuted)
                    TextEditor(text: binding(\.reviewNotes))
                        .font(.callout)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .frame(minHeight: 98)
                        .orbiterFieldChrome()
                    Text("\(setup.reviewNotes.utf8.count)/4000 bytes")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(setup.reviewNotes.utf8.count > 4_000 ? OrbiterColor.danger : OrbiterColor.textSubtle)
                }
            }
        }
    }

    private func labeledField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(OrbiterColor.textMuted)
            TextField(title, text: text)
                .orbiterInputChrome()
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AppSubmissionSetup, Value>) -> Binding<Value> {
        Binding(
            get: { setup[keyPath: keyPath] },
            set: { model.updateSubmissionSetupField(keyPath, value: $0) }
        )
    }
}

struct SubmissionReleaseCompliancePanel: View {
    @Bindable var model: AppModel
    var setup: AppSubmissionSetup

    var body: some View {
        ReviewPrepSection(title: "Release And Compliance") {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Release Option", selection: releaseOptionBinding) {
                        ForEach(SubmissionReleaseOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(setup.releaseOption.detail)
                        .font(.caption)
                        .foregroundStyle(OrbiterColor.textMuted)
                }

                if setup.releaseOption == .scheduledRelease {
                    DatePicker(
                        "Release Date",
                        selection: scheduledDateBinding,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.compact)
                }

                Toggle("Phased release", isOn: binding(\.isPhasedReleaseEnabled))
                    .toggleStyle(.checkbox)

                OrbiterDivider()

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    complianceBlock
                    contentRightsBlock
                }

                Stepper(value: draftItemBinding, in: 0...20) {
                    Text("Draft submission items: \(setup.draftSubmissionItemCount)")
                        .font(.callout.weight(.medium))
                }
            }
        }
    }

    private var complianceBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Export Compliance")
                .font(.caption.weight(.semibold))
                .foregroundStyle(OrbiterColor.textMuted)

            Toggle("Uses encryption", isOn: binding(\.exportCompliance.usesEncryption))
                .toggleStyle(.checkbox)

            Toggle("Qualifies for exemption", isOn: optionalBoolBinding(\.exportCompliance.isExempt))
                .toggleStyle(.checkbox)
                .disabled(!setup.exportCompliance.usesEncryption)

            TextField("Compliance notes", text: binding(\.exportCompliance.complianceNotes))
                .orbiterInputChrome()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(OrbiterColor.canvas, in: RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous))
    }

    private var contentRightsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Content Rights")
                .font(.caption.weight(.semibold))
                .foregroundStyle(OrbiterColor.textMuted)

            Toggle("Contains third-party content", isOn: binding(\.contentRights.containsThirdPartyContent))
                .toggleStyle(.checkbox)

            Toggle("Rights are confirmed", isOn: optionalBoolBinding(\.contentRights.hasRights))
                .toggleStyle(.checkbox)
                .disabled(!setup.contentRights.containsThirdPartyContent)

            TextField("Rights notes", text: binding(\.contentRights.notes))
                .orbiterInputChrome()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(OrbiterColor.canvas, in: RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous))
    }

    private var releaseOptionBinding: Binding<SubmissionReleaseOption> {
        Binding(
            get: { setup.releaseOption },
            set: { model.updateSubmissionReleaseOption($0) }
        )
    }

    private var scheduledDateBinding: Binding<Date> {
        Binding(
            get: { setup.scheduledReleaseDate ?? Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now },
            set: { model.updateSubmissionScheduledReleaseDate($0) }
        )
    }

    private var draftItemBinding: Binding<Int> {
        Binding(
            get: { setup.draftSubmissionItemCount },
            set: { model.updateSubmissionDraftItemCount($0) }
        )
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AppSubmissionSetup, Value>) -> Binding<Value> {
        Binding(
            get: { setup[keyPath: keyPath] },
            set: { model.updateSubmissionSetupField(keyPath, value: $0) }
        )
    }

    private func optionalBoolBinding(_ keyPath: WritableKeyPath<AppSubmissionSetup, Bool?>) -> Binding<Bool> {
        Binding(
            get: { setup[keyPath: keyPath] ?? false },
            set: { model.updateSubmissionSetupField(keyPath, value: $0) }
        )
    }
}

struct SubmissionSetupIssuesPanel: View {
    var issues: [SubmissionSetupIssue]

    var body: some View {
        ReviewPrepSection(title: "Submission Issues") {
            if issues.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(OrbiterColor.success)
                    Text("No submission setup issues.")
                        .font(.callout.weight(.medium))
                    Spacer()
                }
                .padding(10)
            } else {
                VStack(spacing: 8) {
                    ForEach(issues) { issue in
                        SubmissionSetupIssueRow(issue: issue)
                    }
                }
            }
        }
    }
}

struct SubmissionSetupIssueRow: View {
    var issue: SubmissionSetupIssue

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: issue.severity == .blocking ? "xmark.octagon" : "exclamationmark.triangle")
                .foregroundStyle(issue.severity == .blocking ? OrbiterColor.danger : OrbiterColor.warning)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(issue.title)
                        .font(.caption.weight(.semibold))
                    OrbiterBadge(text: issue.area.title, tone: .neutral)
                }

                Text(issue.detail)
                    .font(.caption)
                    .foregroundStyle(OrbiterColor.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(10)
        .background(issue.severity == .blocking ? OrbiterColor.dangerSoft : OrbiterColor.warningSoft, in: RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous)
                .stroke((issue.severity == .blocking ? OrbiterColor.danger : OrbiterColor.warning).opacity(0.18), lineWidth: OrbiterMetric.hairline)
        }
    }
}
