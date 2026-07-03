import SwiftUI

struct MetadataWorkspaceView: View {
    @Bindable var model: AppModel

    var body: some View {
        Group {
            if model.metadataDocument == nil {
                EmptyStateView(
                    title: "Localized copy unavailable",
                    systemImage: "globe",
                    message: "Select an app and version to load localized metadata."
                )
            } else {
                VStack(spacing: 0) {
                    MetadataWorkspaceHeader(model: model)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(OrbiterColor.panel)

                    OrbiterDivider()

                    HStack(spacing: 0) {
                        if let localization = selectedLocalizationBinding {
                            MetadataEditorView(
                                localization: localization,
                                issues: selectedLocaleIssues,
                                appInfoChangedFields: selectedAppInfoChangedFields,
                                versionChangedFields: selectedVersionChangedFields
                            ) {
                                model.updateValidation()
                            } onAIAction: { action in
                                Task { await model.generateMetadataCopy(action) }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .layoutPriority(1)
                        } else {
                            EmptyStateView(
                                title: "Select a locale",
                                systemImage: "globe",
                                message: "Choose a locale to edit App Info and version metadata."
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .layoutPriority(1)
                        }

                        MetadataWorkspaceVerticalDivider()

                        InspectorView(model: model)
                            .frame(width: 360)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(OrbiterColor.canvas)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .navigationTitle(model.selectedApp?.name ?? "Localized Copy")
    }

    private var selectedLocaleIssues: [ValidationIssue] {
        guard let localeID = model.selectedLocaleID else {
            return []
        }

        return model.issues(for: localeID)
    }

    private var selectedAppInfoChangedFields: Set<String> {
        guard let localeID = model.selectedLocaleID else {
            return []
        }

        return model.changedFields(for: localeID, resource: .appInfoLocalization)
    }

    private var selectedVersionChangedFields: Set<String> {
        guard let localeID = model.selectedLocaleID else {
            return []
        }

        return model.changedFields(for: localeID, resource: .appStoreVersionLocalization)
    }

    private var selectedLocalizationBinding: Binding<LocaleMetadata>? {
        guard let localeID = model.selectedLocaleID,
              let index = model.metadataDocument?.localizations.firstIndex(where: { $0.locale == localeID }) else {
            return nil
        }

        return Binding {
            model.metadataDocument?.localizations[index] ?? LocaleMetadata(
                locale: localeID,
                appInfo: AppInfoMetadata(name: "", subtitle: "", privacyPolicyURL: "", privacyChoicesURL: "", privacyPolicyText: ""),
                version: VersionMetadata(description: "", keywords: "", marketingURL: "", promotionalText: "", supportURL: "", whatsNew: "")
            )
        } set: { newValue in
            model.metadataDocument?.localizations[index] = newValue
        }
    }
}

struct MetadataWorkspaceVerticalDivider: View {
    var body: some View {
        Rectangle()
            .fill(OrbiterColor.border)
            .frame(width: OrbiterMetric.hairline)
    }
}

struct MetadataWorkspaceHeader: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MetadataWorkspaceStatusBar(model: model)
            LocaleListView(model: model)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MetadataWorkspaceStatusBar: View {
    @Bindable var model: AppModel

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Localized Copy")
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(OrbiterColor.textMuted)
                    .lineLimit(1)
            }
            .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            HStack(spacing: 8) {
                WorkspaceMetricView(
                    title: "Changes",
                    value: "\(model.changedFieldCount)",
                    systemImage: model.hasMetadataChanges ? "pencil.line" : "checkmark.circle"
                )

                WorkspaceMetricView(
                    title: "Issues",
                    value: "\(model.validationIssues.count)",
                    systemImage: model.validationIssues.isEmpty ? "checkmark.circle" : "exclamationmark.triangle"
                )

                WorkspaceMetricView(
                    title: "Review",
                    value: reviewStatusValue,
                    systemImage: reviewStatusImage
                )
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .frame(minHeight: 34)
    }

    private var statusText: String {
        let version = model.selectedVersion?.versionString ?? "No version"
        guard let pulledAt = model.metadataDocument?.pulledAt else {
            return version
        }

        return "\(version) · synced \(pulledAt.formatted(date: .abbreviated, time: .shortened))"
    }

    private var reviewStatusValue: String {
        if model.reviewChecklistItems.contains(where: { $0.level == .blocking }) {
            return "Blocked"
        }

        if model.reviewChecklistItems.contains(where: { $0.level == .warning }) {
            return "Review"
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

struct WorkspaceMetricView: View {
    var title: String
    var value: String
    var systemImage: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .foregroundStyle(OrbiterColor.textMuted)
                .frame(width: 15)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(OrbiterColor.textSubtle)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .frame(width: 112, height: 30, alignment: .leading)
        .background(OrbiterColor.panelRaised, in: RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous)
                .stroke(OrbiterColor.border, lineWidth: OrbiterMetric.hairline)
        }
    }
}

struct LocaleListView: View {
    @Bindable var model: AppModel
    @State private var isAddLocalePresented = false
    @State private var isTranslateLocalePresented = false
    @State private var isFillCopyConfirmationPresented = false
    @State private var isFillURLsConfirmationPresented = false
    @State private var statusFilter: LocaleStatusFilter = .all
    @State private var searchText = ""

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 8) {
                localeFilterControls
                localeStrip
                    .frame(minWidth: 180, maxWidth: .infinity)
                localeActions
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .center, spacing: 8) {
                    localeFilterControls
                    Spacer(minLength: 8)
                    localeActions
                }

                localeStrip
            }
        }
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $isAddLocalePresented) {
            AddLocaleSheet(model: model)
        }
        .sheet(isPresented: $isTranslateLocalePresented) {
            TranslateLocaleSheet(model: model)
        }
        .confirmationDialog(
            "Fill missing copy?",
            isPresented: $isFillCopyConfirmationPresented
        ) {
            Button("Fill Missing Copy") {
                model.fillMissingCopyFromSelectedLocale()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Empty names, subtitles, descriptions, keywords, promotional text, privacy text, and What's New fields in other locales will use the selected locale's copy.")
        }
        .confirmationDialog(
            "Fill missing URLs?",
            isPresented: $isFillURLsConfirmationPresented
        ) {
            Button("Fill Missing URLs") {
                model.fillMissingURLsFromSelectedLocale()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Empty privacy, marketing, and support URL fields in other locales will use the selected locale's URLs.")
        }
    }

    private var localeFilterControls: some View {
        HStack(alignment: .center, spacing: 8) {
            OrbiterSectionLabel(title: "Locales")
                .padding(.horizontal, 0)
                .frame(width: 58, alignment: .leading)

            TextField("Filter locales", text: $searchText)
                .orbiterInputChrome()
                .frame(width: 210)

            OrbiterSegmentedTextControl(
                selection: $statusFilter,
                items: LocaleStatusFilter.allCases.map { filter in
                    OrbiterSegmentedTextControl.Item(id: filter, title: LocalizedStringKey(filter.title))
                }
            )
            .frame(width: 224)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var localeActions: some View {
        HStack(spacing: 5) {
            Button {
                isTranslateLocalePresented = true
            } label: {
                Image(systemName: "translate")
            }
            .buttonStyle(.orbiterIcon(size: 24))
            .help("Translate Selected Locale")
            .disabled(!canTranslateSelectedLocale)

            Button {
                isFillCopyConfirmationPresented = true
            } label: {
                Image(systemName: "text.badge.plus")
            }
            .buttonStyle(.orbiterIcon(size: 24))
            .help("Fill Missing Copy")
            .disabled(!canFillMissingCopy)

            Button {
                isFillURLsConfirmationPresented = true
            } label: {
                Image(systemName: "link")
            }
            .buttonStyle(.orbiterIcon(size: 24))
            .help("Fill Missing URLs")
            .disabled(!canFillMissingURLs)

            Button {
                isAddLocalePresented = true
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.orbiterIcon(size: 24))
            .help("Add Locale")
            .disabled(model.metadataDocument == nil)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private var localeStrip: some View {
        if filteredLocalizations.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(OrbiterColor.textSubtle)
                Text("No matching locales")
                    .font(.caption)
                    .foregroundStyle(OrbiterColor.textMuted)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: OrbiterMetric.controlHeight, alignment: .leading)
            .background(OrbiterColor.panelRaised, in: RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous)
                    .stroke(OrbiterColor.border, lineWidth: OrbiterMetric.hairline)
            }
        } else {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 6) {
                    ForEach(filteredLocalizations) { localization in
                        LocaleRow(
                            localization: localization,
                            hasChanges: model.changedLocaleIDs.contains(localization.locale),
                            issueCount: model.issueCount(for: localization.locale),
                            isSelected: model.selectedLocaleID == localization.locale
                        ) {
                            model.selectedLocaleID = localization.locale
                        }
                        .frame(width: 124)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: OrbiterMetric.controlHeight, maxHeight: OrbiterMetric.controlHeight)
            .scrollIndicators(.hidden)
        }
    }

    private var filteredLocalizations: [LocaleMetadata] {
        let localizations = model.metadataDocument?.localizations ?? []
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return localizations.filter { localization in
            matches(statusFilter, localization: localization)
                && (
                    query.isEmpty
                        || localization.locale.localizedStandardContains(query)
                        || localization.appInfo.name.localizedStandardContains(query)
                        || localization.appInfo.subtitle.localizedStandardContains(query)
                )
        }
    }

    private func matches(_ filter: LocaleStatusFilter, localization: LocaleMetadata) -> Bool {
        switch filter {
        case .all:
            true
        case .edited:
            model.changedLocaleIDs.contains(localization.locale)
        case .issues:
            model.issueCount(for: localization.locale) > 0
        case .incomplete:
            localization.completedFieldCount < localization.totalFieldCount
        }
    }

    private var canTranslateSelectedLocale: Bool {
        guard model.selectedLocaleID != nil else {
            return false
        }

        return (model.metadataDocument?.localizations.count ?? 0) > 1
    }

    private var canFillMissingCopy: Bool {
        guard let selectedLocaleID = model.selectedLocaleID,
              let localizations = model.metadataDocument?.localizations,
              let source = localizations.first(where: { $0.locale == selectedLocaleID }),
              localizations.count > 1 else {
            return false
        }

        return localizations.contains { localization in
            guard localization.locale != selectedLocaleID else {
                return false
            }

            return shouldCopy(source.appInfo.name, into: localization.appInfo.name)
                || shouldCopy(source.appInfo.subtitle, into: localization.appInfo.subtitle)
                || shouldCopy(source.appInfo.privacyPolicyText, into: localization.appInfo.privacyPolicyText)
                || shouldCopy(source.version.description, into: localization.version.description)
                || shouldCopy(source.version.keywords, into: localization.version.keywords)
                || shouldCopy(source.version.promotionalText, into: localization.version.promotionalText)
                || shouldCopy(source.version.whatsNew, into: localization.version.whatsNew)
        }
    }

    private var canFillMissingURLs: Bool {
        guard let selectedLocaleID = model.selectedLocaleID,
              let localizations = model.metadataDocument?.localizations,
              let source = localizations.first(where: { $0.locale == selectedLocaleID }),
              localizations.count > 1 else {
            return false
        }

        return localizations.contains { localization in
            guard localization.locale != selectedLocaleID else {
                return false
            }

            return shouldCopy(source.appInfo.privacyPolicyURL, into: localization.appInfo.privacyPolicyURL)
                || shouldCopy(source.appInfo.privacyChoicesURL, into: localization.appInfo.privacyChoicesURL)
                || shouldCopy(source.version.marketingURL, into: localization.version.marketingURL)
                || shouldCopy(source.version.supportURL, into: localization.version.supportURL)
        }
    }

    private func shouldCopy(_ source: String, into target: String) -> Bool {
        !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum LocaleStatusFilter: String, CaseIterable, Hashable {
    case all
    case edited
    case issues
    case incomplete

    var title: String {
        switch self {
        case .all:
            "All"
        case .edited:
            "Edited"
        case .issues:
            "Issues"
        case .incomplete:
            "Open"
        }
    }
}

struct TranslateLocaleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: AppModel
    @State private var sourceLocaleID = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Translate Locale")
                    .font(.title3.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(OrbiterColor.textMuted)
            }

            if sourceOptions.isEmpty {
                Text("Add another locale before translating.")
                    .font(.callout)
                    .foregroundStyle(OrbiterColor.textMuted)
                    .orbiterPanel(padding: 10)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Source Locale")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(OrbiterColor.textMuted)

                    Picker("Source Locale", selection: $sourceLocaleID) {
                        ForEach(sourceOptions) { localization in
                            Text(localization.locale)
                                .tag(localization.locale)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .orbiterPanel(padding: 10)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.orbiter(.secondary))

                Button {
                    Task {
                        await model.translateSelectedLocale(from: sourceLocaleID)
                        dismiss()
                    }
                } label: {
                    Label("Translate", systemImage: "translate")
                }
                .buttonStyle(.orbiter(.primary))
                .disabled(sourceLocaleID.isEmpty || sourceOptions.isEmpty || model.isBusy)
            }
        }
        .padding(20)
        .frame(width: 420)
        .background(OrbiterColor.canvas)
        .onAppear {
            if sourceLocaleID.isEmpty {
                sourceLocaleID = sourceOptions.first?.locale ?? ""
            }
        }
    }

    private var subtitle: String {
        if let targetLocaleID = model.selectedLocaleID {
            return "Use AI to translate another locale into \(targetLocaleID)."
        }

        return "Select a target locale before translating."
    }

    private var sourceOptions: [LocaleMetadata] {
        let targetLocaleID = model.selectedLocaleID
        return (model.metadataDocument?.localizations ?? [])
            .filter { $0.locale != targetLocaleID }
            .sorted { $0.locale.localizedStandardCompare($1.locale) == .orderedAscending }
    }
}

struct AddLocaleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: AppModel
    @State private var localeID = ""
    @State private var copySelectedLocale = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Add Locale")
                    .font(.title3.weight(.semibold))
                Text("Create a new App Info and version localization.")
                    .font(.caption)
                    .foregroundStyle(OrbiterColor.textMuted)
            }

            VStack(alignment: .leading, spacing: 8) {
                TextField("Locale ID, e.g. ja, de-DE", text: $localeID)
                    .orbiterInputChrome(isInvalid: isDuplicate)

                if isDuplicate {
                    Text("\(normalizedLocaleID) already exists.")
                        .font(.caption)
                        .foregroundStyle(OrbiterColor.danger)
                }

                Toggle("Copy fields from selected locale", isOn: $copySelectedLocale)
                    .disabled(model.selectedLocaleID == nil)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.orbiter(.secondary))

                Button {
                    let sourceLocaleID = copySelectedLocale ? model.selectedLocaleID : nil
                    if model.addLocale(localeID: localeID, copyFrom: sourceLocaleID) {
                        dismiss()
                    }
                } label: {
                    Label("Add Locale", systemImage: "plus")
                }
                .buttonStyle(.orbiter(.primary))
                .disabled(normalizedLocaleID.isEmpty || isDuplicate)
            }
        }
        .padding(20)
        .frame(width: 420)
        .background(OrbiterColor.canvas)
    }

    private var normalizedLocaleID: String {
        localeID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isDuplicate: Bool {
        guard !normalizedLocaleID.isEmpty else {
            return false
        }

        return model.metadataDocument?.localizations.contains {
            $0.locale.caseInsensitiveCompare(normalizedLocaleID) == .orderedSame
        } ?? false
    }
}

struct LocaleRow: View {
    var localization: LocaleMetadata
    var hasChanges: Bool
    var issueCount: Int
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(localization.locale)
                        .font(.caption.weight(isSelected ? .semibold : .medium))
                        .lineLimit(1)
                    Spacer()
                    if issueCount > 0 {
                        Label("\(issueCount)", systemImage: "exclamationmark.triangle.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(OrbiterColor.warning)
                    } else if hasChanges {
                        Image(systemName: "pencil")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(OrbiterColor.accent)
                    } else {
                        Text("\(localization.completedFieldCount)/\(localization.totalFieldCount)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(OrbiterColor.textSubtle)
                    }
                }
                .frame(height: 16)

                LocaleProgressBar(
                    fraction: completionFraction,
                    tint: issueCount > 0 ? OrbiterColor.warning : OrbiterColor.accent
                )
            }
            .padding(.horizontal, 8)
            .frame(height: OrbiterMetric.controlHeight)
            .background(isSelected ? OrbiterColor.selected : .clear, in: RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous)
                    .stroke(isSelected ? OrbiterColor.accent.opacity(0.18) : .clear, lineWidth: OrbiterMetric.hairline)
            }
        }
        .buttonStyle(.plain)
    }

    private var completionFraction: Double {
        guard localization.totalFieldCount > 0 else {
            return 0
        }

        return Double(localization.completedFieldCount) / Double(localization.totalFieldCount)
    }
}

private struct LocaleProgressBar: View {
    var fraction: Double
    var tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(OrbiterColor.border.opacity(0.75))
                Capsule()
                    .fill(tint)
                    .frame(width: proxy.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 4)
    }
}
