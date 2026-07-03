import SwiftUI

struct PricingAvailabilitySummaryView: View {
    @Bindable var model: AppModel

    var body: some View {
        SummaryPage(title: "Pricing and Availability") {
            SummarySection(title: "Current Version") {
                if let app = model.selectedApp, let version = model.selectedVersion {
                    StatusRow(title: "App", detail: LocalizedStringKey(app.name), systemImage: "app")
                    StatusRow(title: "Version", detail: LocalizedStringKey(version.versionString), systemImage: "number")
                    StatusRow(title: "Status", detail: statusText, systemImage: statusImage)
                } else {
                    StatusRow(title: "Selection", detail: "Select version", systemImage: "doc.text.magnifyingglass")
                }
            }

            SummarySection(title: "Commercial Setup") {
                if let configuration = model.pricingAvailability {
                    StatusRow(title: "Price", detail: LocalizedStringKey(configuration.priceDisplay), systemImage: "tag")
                    StatusRow(title: "Tax Category", detail: LocalizedStringKey(configuration.taxCategory.isEmpty ? "Not set" : configuration.taxCategory), systemImage: "doc.plaintext")
                    StatusRow(title: "Storefronts", detail: "\(configuration.customerVisibleTerritoryCount)/\(configuration.territories.count)", systemImage: "storefront")
                } else {
                    StatusRow(title: "Pricing", detail: "Select version", systemImage: "tag")
                }
            }

            SummarySection(title: "Actions") {
                Button("Open Pricing") {
                    model.sidebarSelection = .pricingAvailability
                }
                .buttonStyle(.orbiter(.secondary))
                .disabled(model.pricingAvailability == nil)
            }
        }
        .navigationTitle("Pricing and Availability")
    }

    private var statusText: LocalizedStringKey {
        let summary = model.pricingAvailabilitySummary
        if summary.blockingCount > 0 {
            return "\(summary.blockingCount) blocking"
        }

        if summary.warningCount > 0 {
            return "\(summary.warningCount) warnings"
        }

        return model.pricingAvailability == nil ? "Select version" : "Ready"
    }

    private var statusImage: String {
        let summary = model.pricingAvailabilitySummary
        if summary.blockingCount > 0 {
            return "xmark.octagon"
        }

        if summary.warningCount > 0 {
            return "exclamationmark.triangle"
        }

        return "checkmark.circle"
    }
}

struct PricingAvailabilityView: View {
    @Bindable var model: AppModel

    var body: some View {
        Group {
            if let configuration = model.pricingAvailability {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header(configuration: configuration)
                        PricingAvailabilitySummaryPanel(summary: model.pricingAvailabilitySummary)
                        PricingAvailabilityReviewBanner(
                            summary: model.pricingAvailabilitySummary,
                            issues: model.pricingAvailabilityIssues
                        ) {
                            model.sidebarSelection = .reviewPrep
                        }
                        PricingCommercialSetupPanel(model: model, configuration: configuration)
                        TerritoryAvailabilityPanel(model: model, configuration: configuration)
                        PricingAvailabilityIssuesPanel(issues: model.pricingAvailabilityIssues)
                    }
                    .padding(24)
                    .frame(maxWidth: 980, alignment: .leading)
                }
                .background(OrbiterColor.canvas)
            } else {
                EmptyStateView(
                    title: "Pricing and Availability",
                    systemImage: "tag",
                    message: "Select an app and version to manage pricing, distribution, and storefront availability."
                )
            }
        }
        .navigationTitle("Pricing and Availability")
    }

    private func header(configuration: AppPricingAvailability) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Pricing and Availability")
                    .font(.title2.weight(.semibold))
                Text(subtitle(configuration: configuration))
                    .font(.callout)
                    .foregroundStyle(OrbiterColor.textMuted)
            }

            Spacer()

            OrbiterBadge(text: configuration.distributionMethod.title, systemImage: configuration.distributionMethod.systemImage, tone: .neutral)
        }
    }

    private func subtitle(configuration: AppPricingAvailability) -> String {
        let appName = model.selectedApp?.name ?? "No app"
        let version = model.selectedVersion?.versionString ?? "No version"
        return "\(appName) · \(version) · base territory \(configuration.baseTerritoryName)"
    }
}

struct PricingAvailabilitySummaryPanel: View {
    var summary: PricingAvailabilitySummary

    var body: some View {
        HStack(spacing: 8) {
            ReviewPrepMetricTile(title: "Storefronts", value: "\(summary.customerVisibleTerritoryCount)/\(summary.territoryCount)", tone: summary.customerVisibleTerritoryCount > 0 ? .accent : .danger)
            ReviewPrepMetricTile(title: "Unavailable", value: "\(summary.unavailableTerritoryCount)", tone: summary.unavailableTerritoryCount > 0 ? .warning : .success)
            ReviewPrepMetricTile(title: "Pre-Orders", value: "\(summary.preOrderTerritoryCount)", tone: summary.preOrderTerritoryCount > 0 ? .accent : .neutral)
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

struct PricingAvailabilityReviewBanner: View {
    var summary: PricingAvailabilitySummary
    var issues: [PricingAvailabilityIssue]
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
            return "Pricing blocks release prep"
        }

        if summary.warningCount > 0 {
            return "Pricing needs review"
        }

        return "Pricing ready"
    }

    private var detail: String {
        if let firstBlocking = issues.first(where: { $0.severity == .blocking }) {
            return "\(firstBlocking.title): \(firstBlocking.detail)"
        }

        if let firstWarning = issues.first(where: { $0.severity == .warning }) {
            return "\(firstWarning.title): \(firstWarning.detail)"
        }

        return "\(summary.customerVisibleTerritoryCount) storefronts are customer-visible."
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

struct PricingCommercialSetupPanel: View {
    @Bindable var model: AppModel
    var configuration: AppPricingAvailability

    var body: some View {
        ReviewPrepSection(title: "Commercial Setup") {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Distribution", selection: distributionBinding) {
                        ForEach(AppDistributionMethod.allCases) { method in
                            Label(method.title, systemImage: method.systemImage)
                                .tag(method)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(configuration.distributionMethod.detail)
                        .font(.caption)
                        .foregroundStyle(OrbiterColor.textMuted)

                    Picker("Price", selection: priceBinding) {
                        ForEach(priceOptions) { option in
                            Text(option.title).tag(option.id)
                        }
                    }

                    Picker("Tax Category", selection: taxCategoryBinding) {
                        ForEach(taxCategories, id: \.self) { category in
                            Text(category.isEmpty ? "Not set" : category).tag(category)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 9) {
                    Toggle("Pre-order", isOn: preOrderBinding)
                    if configuration.isPreOrderEnabled {
                        HStack(spacing: 8) {
                            Text(preOrderDateText)
                                .font(.caption)
                                .foregroundStyle(OrbiterColor.textMuted)

                            Spacer()

                            Button("Set Date") {
                                model.updatePreOrderReleaseDate(.now.addingTimeInterval(86_400 * 14))
                            }
                            .buttonStyle(.orbiter(.secondary, size: .compact))
                        }
                    }

                    Toggle("Phased release", isOn: phasedReleaseBinding)
                    Toggle("Education discount", isOn: educationDiscountBinding)
                    Toggle("Apple Silicon Mac", isOn: appleSiliconBinding)
                }
                .frame(width: 260, alignment: .leading)
            }
            .padding(8)
        }
    }

    private var distributionBinding: Binding<AppDistributionMethod> {
        Binding(
            get: { configuration.distributionMethod },
            set: { model.updatePricingDistributionMethod($0) }
        )
    }

    private var priceBinding: Binding<String> {
        Binding(
            get: { priceOptions.first { $0.matches(configuration) }?.id ?? "custom" },
            set: { id in
                guard let option = priceOptions.first(where: { $0.id == id }) else {
                    return
                }
                model.updatePricingTier(priceTier: option.priceTier, customerPrice: option.customerPrice, proceeds: option.proceeds)
            }
        )
    }

    private var taxCategoryBinding: Binding<String> {
        Binding(
            get: { configuration.taxCategory },
            set: { model.updateTaxCategory($0) }
        )
    }

    private var preOrderBinding: Binding<Bool> {
        Binding(
            get: { configuration.isPreOrderEnabled },
            set: { model.setPreOrderEnabled($0) }
        )
    }

    private var phasedReleaseBinding: Binding<Bool> {
        Binding(
            get: { configuration.isPhasedReleaseEnabled },
            set: { model.setPhasedReleaseEnabled($0) }
        )
    }

    private var educationDiscountBinding: Binding<Bool> {
        Binding(
            get: { configuration.isEducationDiscountEnabled },
            set: { model.setEducationDiscountEnabled($0) }
        )
    }

    private var appleSiliconBinding: Binding<Bool> {
        Binding(
            get: { configuration.isAppleSiliconMacAvailable },
            set: { model.setAppleSiliconMacAvailable($0) }
        )
    }

    private var preOrderDateText: String {
        guard let date = configuration.preOrderReleaseDate else {
            return "No release date"
        }

        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private var taxCategories: [String] {
        ["", "Software", "Productivity", "Education", "Games", "Health and Fitness"]
    }

    private var priceOptions: [PricingOption] {
        [
            PricingOption(id: "free", title: "Free · 0.00 USD", priceTier: "Free", customerPrice: "0.00", proceeds: "0.00"),
            PricingOption(id: "tier-1", title: "Tier 1 · 0.99 USD", priceTier: "Tier 1", customerPrice: "0.99", proceeds: "0.70"),
            PricingOption(id: "tier-10", title: "Tier 10 · 9.99 USD", priceTier: "Tier 10", customerPrice: "9.99", proceeds: "7.00"),
            PricingOption(id: "custom", title: configuration.priceDisplay, priceTier: configuration.priceTier, customerPrice: configuration.customerPrice, proceeds: configuration.proceeds)
        ]
    }
}

private struct PricingOption: Identifiable {
    var id: String
    var title: String
    var priceTier: String
    var customerPrice: String
    var proceeds: String

    func matches(_ configuration: AppPricingAvailability) -> Bool {
        priceTier == configuration.priceTier && customerPrice == configuration.customerPrice
    }
}

struct TerritoryAvailabilityPanel: View {
    @Bindable var model: AppModel
    var configuration: AppPricingAvailability

    var body: some View {
        ReviewPrepSection(title: "Storefront Availability") {
            ForEach(configuration.territories) { territory in
                TerritoryAvailabilityRow(
                    territory: territory,
                    selection: Binding(
                        get: { territory.status },
                        set: { model.updateTerritoryAvailability(code: territory.code, status: $0) }
                    )
                )
            }
        }
    }
}

struct TerritoryAvailabilityRow: View {
    var territory: TerritoryAvailability
    @Binding var selection: StorefrontAvailabilityStatus

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(territory.name)
                    .font(.callout.weight(.medium))
                Text(territory.code + (territory.note.isEmpty ? "" : " · \(territory.note)"))
                    .font(.caption)
                    .foregroundStyle(OrbiterColor.textMuted)
                    .lineLimit(1)
            }

            Spacer()

            Picker("Availability", selection: $selection) {
                ForEach(StorefrontAvailabilityStatus.allCases) { status in
                    Text(status.title).tag(status)
                }
            }
            .labelsHidden()
            .frame(width: 150)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OrbiterColor.panelRaised, in: RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous)
                .stroke(OrbiterColor.border, lineWidth: OrbiterMetric.hairline)
        }
    }
}

struct PricingAvailabilityIssuesPanel: View {
    var issues: [PricingAvailabilityIssue]

    var body: some View {
        ReviewPrepSection(title: "Pricing Issues") {
            if issues.isEmpty {
                Label("No pricing or availability issues", systemImage: "checkmark.circle")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(OrbiterColor.success)
                    .padding(8)
            } else {
                ForEach(issues) { issue in
                    PricingAvailabilityIssueRow(issue: issue)
                }
            }
        }
    }
}

struct PricingAvailabilityIssueRow: View {
    var issue: PricingAvailabilityIssue

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: issue.severity == .blocking ? "xmark.octagon" : "exclamationmark.triangle")
                .foregroundStyle(issue.severity == .blocking ? OrbiterColor.danger : OrbiterColor.warning)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(issue.title)
                    .font(.caption.weight(.semibold))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(OrbiterColor.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(issue.severity == .blocking ? OrbiterColor.dangerSoft : OrbiterColor.warningSoft, in: RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous))
    }

    private var detail: String {
        guard !issue.affectedTerritories.isEmpty else {
            return issue.detail
        }

        return "\(issue.detail) Territories: \(issue.affectedTerritories.joined(separator: ", "))."
    }
}
