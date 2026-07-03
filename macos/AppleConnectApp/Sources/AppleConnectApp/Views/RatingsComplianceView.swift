import SwiftUI

struct RatingsComplianceSummaryView: View {
    @Bindable var model: AppModel

    var body: some View {
        SummaryPage(title: "Ratings and Compliance") {
            SummarySection(title: "Current Version") {
                if let app = model.selectedApp, let version = model.selectedVersion {
                    StatusRow(title: "App", detail: LocalizedStringKey(app.name), systemImage: "app")
                    StatusRow(title: "Version", detail: LocalizedStringKey(version.versionString), systemImage: "number")
                    StatusRow(title: "Status", detail: statusText, systemImage: statusImage)
                } else {
                    StatusRow(title: "Selection", detail: "Select version", systemImage: "doc.text.magnifyingglass")
                }
            }

            SummarySection(title: "App Information") {
                if let configuration = model.ratingsCompliance {
                    StatusRow(title: "Age Rating", detail: LocalizedStringKey(configuration.estimatedAppleAgeRating), systemImage: "shield.lefthalf.filled")
                    StatusRow(title: "Category", detail: LocalizedStringKey(configuration.primaryCategory?.title ?? "Not set"), systemImage: "square.grid.2x2")
                    StatusRow(title: "Regional Items", detail: "\(model.ratingsComplianceSummary.regionalItemCount)", systemImage: "globe")
                } else {
                    StatusRow(title: "Ratings", detail: "Select version", systemImage: "shield.lefthalf.filled")
                }
            }

            SummarySection(title: "Actions") {
                Button("Open Ratings") {
                    model.sidebarSelection = .ratingsCompliance
                }
                .buttonStyle(.orbiter(.secondary))
                .disabled(model.ratingsCompliance == nil)
            }
        }
        .navigationTitle("Ratings and Compliance")
    }

    private var statusText: LocalizedStringKey {
        let summary = model.ratingsComplianceSummary
        if summary.blockingCount > 0 {
            return "\(summary.blockingCount) blocking"
        }

        if summary.warningCount > 0 {
            return "\(summary.warningCount) warnings"
        }

        return model.ratingsCompliance == nil ? "Select version" : "Ready"
    }

    private var statusImage: String {
        let summary = model.ratingsComplianceSummary
        if summary.blockingCount > 0 {
            return "xmark.octagon"
        }

        if summary.warningCount > 0 {
            return "exclamationmark.triangle"
        }

        return "checkmark.circle"
    }
}

struct RatingsComplianceView: View {
    @Bindable var model: AppModel

    var body: some View {
        Group {
            if let configuration = model.ratingsCompliance {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header(configuration: configuration)
                        RatingsComplianceSummaryPanel(summary: model.ratingsComplianceSummary)
                        RatingsComplianceReviewBanner(
                            summary: model.ratingsComplianceSummary,
                            issues: model.ratingsComplianceIssues
                        ) {
                            model.sidebarSelection = .reviewPrep
                        }
                        RatingsCategoryPanel(model: model, configuration: configuration)
                        AgeQuestionnairePanel(model: model, configuration: configuration)
                        RegionalCompliancePanel(model: model, configuration: configuration)
                        RatingsComplianceIssuesPanel(issues: model.ratingsComplianceIssues)
                    }
                    .padding(24)
                    .frame(maxWidth: 1040, alignment: .leading)
                }
                .background(OrbiterColor.canvas)
            } else {
                EmptyStateView(
                    title: "Ratings and Compliance",
                    systemImage: "shield.lefthalf.filled",
                    message: "Select an app and version to manage age rating, categories, Kids settings, and regional compliance."
                )
            }
        }
        .navigationTitle("Ratings and Compliance")
    }

    private func header(configuration: AppRatingsCompliance) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Ratings and Compliance")
                    .font(.title2.weight(.semibold))
                Text(subtitle(configuration: configuration))
                    .font(.callout)
                    .foregroundStyle(OrbiterColor.textMuted)
            }

            Spacer()

            OrbiterBadge(text: configuration.estimatedAppleAgeRating, systemImage: "shield", tone: badgeTone)
        }
    }

    private func subtitle(configuration: AppRatingsCompliance) -> String {
        let appName = model.selectedApp?.name ?? "No app"
        let version = model.selectedVersion?.versionString ?? "No version"
        let category = configuration.primaryCategory?.title ?? "no category"
        return "\(appName) · \(version) · \(category)"
    }

    private var badgeTone: OrbiterBadgeTone {
        if model.ratingsComplianceSummary.blockingCount > 0 {
            return .danger
        }

        if model.ratingsComplianceSummary.warningCount > 0 {
            return .warning
        }

        return .success
    }
}

struct RatingsComplianceSummaryPanel: View {
    var summary: RatingsComplianceSummary

    var body: some View {
        HStack(spacing: 8) {
            ReviewPrepMetricTile(title: "Age Rating", value: summary.estimatedAgeRating, tone: summary.blockingCount > 0 ? .danger : .success)
            ReviewPrepMetricTile(title: "Descriptors", value: "\(summary.completedDescriptorCount)/\(summary.totalDescriptorCount)", tone: summary.completedDescriptorCount > 0 ? .accent : .neutral)
            ReviewPrepMetricTile(title: "Regional", value: "\(summary.regionalItemCount)", tone: summary.regionalItemCount > 0 ? .warning : .neutral)
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

struct RatingsComplianceReviewBanner: View {
    var summary: RatingsComplianceSummary
    var issues: [RatingsComplianceIssue]
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
            return "Ratings block release prep"
        }

        if summary.warningCount > 0 {
            return "Ratings need review"
        }

        return "Ratings ready"
    }

    private var detail: String {
        if let firstBlocking = issues.first(where: { $0.severity == .blocking }) {
            return "\(firstBlocking.title): \(firstBlocking.detail)"
        }

        if let firstWarning = issues.first(where: { $0.severity == .warning }) {
            return "\(firstWarning.title): \(firstWarning.detail)"
        }

        return "Age rating, category, and regional compliance are ready for handoff."
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

struct RatingsCategoryPanel: View {
    @Bindable var model: AppModel
    var configuration: AppRatingsCompliance

    var body: some View {
        ReviewPrepSection(title: "Category And Kids") {
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    categoryPicker("Primary Category", selection: primaryCategoryBinding)
                    categoryPicker("Secondary Category", selection: secondaryCategoryBinding)
                }

                Toggle("Made for Kids", isOn: binding(\.isMadeForKids))
                    .toggleStyle(.checkbox)

                if configuration.isMadeForKids {
                    Picker("Kids Age Range", selection: kidsAgeBandBinding) {
                        Text("Select").tag(Optional<KidsAgeBand>.none)
                        ForEach(KidsAgeBand.allCases) { ageBand in
                            Text(ageBand.title).tag(Optional(ageBand))
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    private func categoryPicker(
        _ title: String,
        selection: Binding<AppStoreCategory?>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(OrbiterColor.textMuted)
            Picker(title, selection: selection) {
                Text("Not set").tag(Optional<AppStoreCategory>.none)
                ForEach(AppStoreCategory.allCases) { category in
                    Label(category.title, systemImage: category.systemImage)
                        .tag(Optional(category))
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)
        }
    }

    private var primaryCategoryBinding: Binding<AppStoreCategory?> {
        Binding(
            get: { configuration.primaryCategory },
            set: { model.updateRatingsComplianceField(\.primaryCategory, value: $0) }
        )
    }

    private var secondaryCategoryBinding: Binding<AppStoreCategory?> {
        Binding(
            get: { configuration.secondaryCategory },
            set: { model.updateRatingsComplianceField(\.secondaryCategory, value: $0) }
        )
    }

    private var kidsAgeBandBinding: Binding<KidsAgeBand?> {
        Binding(
            get: { configuration.kidsAgeBand },
            set: { model.updateRatingsComplianceField(\.kidsAgeBand, value: $0) }
        )
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AppRatingsCompliance, Value>) -> Binding<Value> {
        Binding(
            get: { configuration[keyPath: keyPath] },
            set: { model.updateRatingsComplianceField(keyPath, value: $0) }
        )
    }
}

struct AgeQuestionnairePanel: View {
    @Bindable var model: AppModel
    var configuration: AppRatingsCompliance

    var body: some View {
        ReviewPrepSection(title: "Age Rating Questionnaire") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Toggle("Questionnaire complete", isOn: binding(\.isAgeQuestionnaireComplete))
                        .toggleStyle(.checkbox)

                    Spacer()

                    OrbiterBadge(text: "Estimated \(configuration.estimatedAppleAgeRating)", tone: model.ratingsComplianceSummary.blockingCount > 0 ? .warning : .success)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(AgeRatingDescriptor.allCases) { descriptor in
                        AgeDescriptorRow(
                            descriptor: descriptor,
                            frequency: configuration.frequency(for: descriptor)
                        ) { frequency in
                            model.setAgeRatingFrequency(descriptor: descriptor, frequency: frequency)
                        }
                    }
                }

                OrbiterDivider()

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    Toggle("Unrestricted web access", isOn: binding(\.hasUnrestrictedWebAccess))
                        .toggleStyle(.checkbox)
                    Toggle("User-generated content", isOn: binding(\.hasUserGeneratedContent))
                        .toggleStyle(.checkbox)
                    Toggle("Location sharing", isOn: binding(\.hasLocationSharing))
                        .toggleStyle(.checkbox)
                }
            }
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AppRatingsCompliance, Value>) -> Binding<Value> {
        Binding(
            get: { configuration[keyPath: keyPath] },
            set: { model.updateRatingsComplianceField(keyPath, value: $0) }
        )
    }
}

struct AgeDescriptorRow: View {
    var descriptor: AgeRatingDescriptor
    var frequency: AgeRatingFrequency
    var update: (AgeRatingFrequency) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: descriptor.systemImage)
                .frame(width: 18)
                .foregroundStyle(OrbiterColor.textMuted)

            Text(descriptor.title)
                .font(.caption.weight(.medium))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker(descriptor.title, selection: frequencyBinding) {
                ForEach(AgeRatingFrequency.allCases) { frequency in
                    Text(frequency.title).tag(frequency)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 220)
        }
        .padding(8)
        .background(OrbiterColor.canvas, in: RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous))
    }

    private var frequencyBinding: Binding<AgeRatingFrequency> {
        Binding(
            get: { frequency },
            set: { update($0) }
        )
    }
}

struct RegionalCompliancePanel: View {
    @Bindable var model: AppModel
    var configuration: AppRatingsCompliance

    var body: some View {
        ReviewPrepSection(title: "Regional Compliance") {
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    regionalFieldGroup(
                        title: "Republic of Korea",
                        enabledTitle: "Available in Korea",
                        isEnabled: binding(\.regionalCompliance.isAvailableInKorea),
                        fieldTitle: "GRAC rating number",
                        text: binding(\.regionalCompliance.koreaRatingClassificationNumber)
                    )

                    regionalFieldGroup(
                        title: "China Mainland",
                        enabledTitle: "Available in China mainland",
                        isEnabled: binding(\.regionalCompliance.isAvailableInChinaMainland),
                        fieldTitle: "ICP filing number",
                        text: binding(\.regionalCompliance.chinaICPNumber)
                    )
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("China Game Approval")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(OrbiterColor.textMuted)
                        TextField("Game approval number", text: binding(\.regionalCompliance.chinaGameApprovalNumber))
                            .orbiterInputChrome()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Content Rights")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(OrbiterColor.textMuted)
                        Toggle("Contains third-party content", isOn: binding(\.regionalCompliance.containsThirdPartyContent))
                            .toggleStyle(.checkbox)
                        Toggle("Rights confirmed", isOn: optionalBoolBinding(\.regionalCompliance.hasThirdPartyContentRights))
                            .toggleStyle(.checkbox)
                            .disabled(!configuration.regionalCompliance.containsThirdPartyContent)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Regional Notes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(OrbiterColor.textMuted)
                    TextField("Internal notes for regional compliance handoff", text: binding(\.regionalCompliance.regionalNotes))
                        .orbiterInputChrome()
                }
            }
        }
    }

    private func regionalFieldGroup(
        title: String,
        enabledTitle: String,
        isEnabled: Binding<Bool>,
        fieldTitle: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(OrbiterColor.textMuted)
            Toggle(enabledTitle, isOn: isEnabled)
                .toggleStyle(.checkbox)
            TextField(fieldTitle, text: text)
                .orbiterInputChrome()
                .disabled(!isEnabled.wrappedValue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(OrbiterColor.canvas, in: RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous))
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AppRatingsCompliance, Value>) -> Binding<Value> {
        Binding(
            get: { configuration[keyPath: keyPath] },
            set: { model.updateRatingsComplianceField(keyPath, value: $0) }
        )
    }

    private func optionalBoolBinding(_ keyPath: WritableKeyPath<AppRatingsCompliance, Bool?>) -> Binding<Bool> {
        Binding(
            get: { configuration[keyPath: keyPath] ?? false },
            set: { model.updateRatingsComplianceField(keyPath, value: $0) }
        )
    }
}

struct RatingsComplianceIssuesPanel: View {
    var issues: [RatingsComplianceIssue]

    var body: some View {
        ReviewPrepSection(title: "Ratings Issues") {
            if issues.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(OrbiterColor.success)
                    Text("No ratings or compliance issues.")
                        .font(.callout.weight(.medium))
                    Spacer()
                }
                .padding(10)
            } else {
                VStack(spacing: 8) {
                    ForEach(issues) { issue in
                        RatingsComplianceIssueRow(issue: issue)
                    }
                }
            }
        }
    }
}

struct RatingsComplianceIssueRow: View {
    var issue: RatingsComplianceIssue

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
