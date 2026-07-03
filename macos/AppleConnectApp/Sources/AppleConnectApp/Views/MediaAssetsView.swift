import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MediaAssetsSummaryView: View {
    @Bindable var model: AppModel

    var body: some View {
        SummaryPage(title: "Media Assets") {
            SummarySection(title: "Current Version") {
                if let app = model.selectedApp, let version = model.selectedVersion {
                    StatusRow(title: "App", detail: LocalizedStringKey(app.name), systemImage: "app")
                    StatusRow(title: "Platform", detail: LocalizedStringKey(version.platform), systemImage: "rectangle.stack")
                    StatusRow(title: "Locales", detail: "\(model.mediaAssetCatalog?.locales.count ?? 0)", systemImage: "globe")
                } else {
                    StatusRow(title: "Selection", detail: "Select version", systemImage: "doc.text.magnifyingglass")
                }
            }

            SummarySection(title: "Coverage") {
                StatusRow(title: "Required Sets", detail: requiredSetText, systemImage: "checklist")
                StatusRow(title: "Screenshots", detail: "\(model.mediaValidationSummary.screenshotCount)", systemImage: "photo.on.rectangle")
                StatusRow(title: "App Previews", detail: "\(model.mediaValidationSummary.previewCount)", systemImage: "play.rectangle")
                StatusRow(title: "Issues", detail: issueText, systemImage: issueImage)
            }

            SummarySection(title: "Actions") {
                Button("Open Media Assets") {
                    model.sidebarSelection = .mediaAssets
                }
                .buttonStyle(.orbiter(.secondary))
                .disabled(model.mediaAssetCatalog == nil)
            }
        }
        .navigationTitle("Media Assets")
    }

    private var requiredSetText: LocalizedStringKey {
        let summary = model.mediaValidationSummary
        guard summary.requiredSetCount > 0 else {
            return "Select version"
        }

        return "\(summary.completeRequiredSetCount)/\(summary.requiredSetCount)"
    }

    private var issueText: LocalizedStringKey {
        let summary = model.mediaValidationSummary
        if summary.blockingCount > 0 {
            return "\(summary.blockingCount) blocking"
        }

        if summary.warningCount > 0 {
            return "\(summary.warningCount) warnings"
        }

        return summary.requiredSetCount == 0 ? "Select version" : "Ready"
    }

    private var issueImage: String {
        let summary = model.mediaValidationSummary
        if summary.blockingCount > 0 {
            return "xmark.octagon"
        }

        if summary.warningCount > 0 {
            return "exclamationmark.triangle"
        }

        return "checkmark.circle"
    }
}

struct MediaAssetsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Group {
            if let catalog = model.mediaAssetCatalog {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header(catalog: catalog)
                        MediaAssetSummaryPanel(summary: model.mediaValidationSummary)
                        MediaAssetReviewBanner(
                            summary: model.mediaValidationSummary,
                            issues: model.mediaValidationIssues
                        ) {
                            model.sidebarSelection = .reviewPrep
                        }
                        localePicker(catalog: catalog)
                        deviceSections(catalog: catalog)
                    }
                    .padding(24)
                    .frame(maxWidth: 980, alignment: .leading)
                }
                .background(OrbiterColor.canvas)
            } else {
                EmptyStateView(
                    title: "Media Assets",
                    systemImage: "photo.on.rectangle.angled",
                    message: "Select an app and version to manage localized screenshots and app previews."
                )
            }
        }
        .navigationTitle("Media Assets")
    }

    private func header(catalog: StoreMediaCatalog) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Media Assets")
                    .font(.title2.weight(.semibold))
                Text(subtitle(catalog: catalog))
                    .font(.callout)
                    .foregroundStyle(OrbiterColor.textMuted)
            }

            Spacer()

            OrbiterBadge(text: catalog.platform, systemImage: "rectangle.stack", tone: .neutral)
        }
    }

    private func localePicker(catalog: StoreMediaCatalog) -> some View {
        ReviewPrepSection(title: "Locale") {
            Picker("Locale", selection: selectedLocaleBinding(catalog: catalog)) {
                ForEach(catalog.locales, id: \.self) { locale in
                    Text(locale).tag(locale)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private func deviceSections(catalog: StoreMediaCatalog) -> some View {
        ReviewPrepSection(title: "Device Sizes") {
            let locale = selectedLocale(catalog: catalog)
            ForEach(catalog.deviceSpecs) { spec in
                MediaDeviceAssetPanel(
                    spec: spec,
                    set: catalog.set(locale: locale, deviceID: spec.id),
                    issues: issues(locale: locale, deviceID: spec.id),
                    importScreenshot: {
                        chooseAsset(kind: .screenshot, locale: locale, deviceID: spec.id)
                    },
                    importPreview: {
                        chooseAsset(kind: .appPreview, locale: locale, deviceID: spec.id)
                    },
                    removeAsset: { asset, kind in
                        model.removeMediaAsset(assetID: asset.id, locale: locale, deviceID: spec.id, kind: kind)
                    }
                )
            }
        }
    }

    private func selectedLocale(catalog: StoreMediaCatalog) -> String {
        if let selected = model.selectedMediaLocaleID, catalog.locales.contains(selected) {
            return selected
        }

        return catalog.locales.first ?? ""
    }

    private func selectedLocaleBinding(catalog: StoreMediaCatalog) -> Binding<String> {
        Binding(
            get: { selectedLocale(catalog: catalog) },
            set: { model.selectedMediaLocaleID = $0 }
        )
    }

    private func issues(locale: String, deviceID: String) -> [StoreMediaValidationIssue] {
        model.mediaValidationIssues.filter { $0.locale == locale && $0.deviceID == deviceID }
    }

    private func subtitle(catalog: StoreMediaCatalog) -> String {
        let appName = model.selectedApp?.name ?? "No app"
        let version = model.selectedVersion?.versionString ?? "No version"
        return "\(appName) · \(version) · \(catalog.locales.count) localized media sets"
    }

    private func chooseAsset(kind: StoreMediaAssetKind, locale: String, deviceID: String) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Import"
        panel.message = "Choose a \(kind.title.lowercased()) for \(locale)."
        panel.allowedContentTypes = allowedContentTypes(for: kind)

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        Task {
            await model.importMediaAsset(url: url, kind: kind, locale: locale, deviceID: deviceID)
        }
    }

    private func allowedContentTypes(for kind: StoreMediaAssetKind) -> [UTType] {
        switch kind {
        case .screenshot:
            [.jpeg, .png]
        case .appPreview:
            [UTType.quickTimeMovie, UTType.mpeg4Movie, UTType(filenameExtension: "m4v")]
                .compactMap { $0 }
        }
    }
}

struct MediaAssetReviewBanner: View {
    var summary: StoreMediaValidationSummary
    var issues: [StoreMediaValidationIssue]
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
            return "Media blocks release prep"
        }

        if summary.warningCount > 0 {
            return "Media needs review"
        }

        return "Media ready"
    }

    private var detail: String {
        if let firstBlocking = issues.first(where: { $0.severity == .blocking }) {
            return "\(firstBlocking.locale) · \(firstBlocking.title): \(firstBlocking.detail)"
        }

        if let firstWarning = issues.first(where: { $0.severity == .warning }) {
            return "\(firstWarning.locale) · \(firstWarning.title): \(firstWarning.detail)"
        }

        return "\(summary.completeRequiredSetCount)/\(summary.requiredSetCount) required screenshot sets are complete."
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

struct MediaAssetSummaryPanel: View {
    var summary: StoreMediaValidationSummary

    var body: some View {
        HStack(spacing: 8) {
            ReviewPrepMetricTile(
                title: "Required",
                value: "\(summary.completeRequiredSetCount)/\(summary.requiredSetCount)",
                tone: summary.isReady ? .success : .warning
            )
            ReviewPrepMetricTile(title: "Shots", value: "\(summary.screenshotCount)", tone: .accent)
            ReviewPrepMetricTile(title: "Previews", value: "\(summary.previewCount)", tone: summary.previewCount > 0 ? .accent : .neutral)
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

struct MediaDeviceAssetPanel: View {
    var spec: StoreMediaDeviceSpec
    var set: StoreMediaSet
    var issues: [StoreMediaValidationIssue]
    var importScreenshot: () -> Void
    var importPreview: () -> Void
    var removeAsset: (StoreMediaAsset, StoreMediaAssetKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "rectangle.on.rectangle")
                    .foregroundStyle(OrbiterColor.accent)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(spec.displayName)
                            .font(.headline.weight(.semibold))
                        if spec.isRequired {
                            OrbiterBadge(text: "Required", tone: .warning)
                        }
                    }
                    Text(spec.requirement)
                        .font(.caption)
                        .foregroundStyle(OrbiterColor.textMuted)
                    Text("Screenshots: \(spec.screenshotSizeSummary)")
                        .font(.caption2)
                        .foregroundStyle(OrbiterColor.textSubtle)
                    Text("Previews: \(spec.previewSizeSummary)")
                        .font(.caption2)
                        .foregroundStyle(OrbiterColor.textSubtle)
                }

                Spacer()

                Button {
                    importScreenshot()
                } label: {
                    Label("Screenshot", systemImage: "plus")
                }
                .buttonStyle(.orbiter(.secondary, size: .compact))

                Button {
                    importPreview()
                } label: {
                    Label("Preview", systemImage: "plus")
                }
                .buttonStyle(.orbiter(.secondary, size: .compact))
                .disabled(spec.previewSizes.isEmpty)
            }

            if !issues.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(issues) { issue in
                        MediaValidationIssueRow(issue: issue)
                    }
                }
            }

            MediaAssetGroup(
                title: "Screenshots",
                emptyText: "No screenshots imported",
                assets: set.screenshots,
                kind: .screenshot,
                removeAsset: removeAsset
            )

            MediaAssetGroup(
                title: "App Previews",
                emptyText: "No app previews imported",
                assets: set.appPreviews,
                kind: .appPreview,
                removeAsset: removeAsset
            )
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OrbiterColor.panelRaised, in: RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous)
                .stroke(OrbiterColor.border, lineWidth: OrbiterMetric.hairline)
        }
    }
}

struct MediaAssetGroup: View {
    var title: String
    var emptyText: String
    var assets: [StoreMediaAsset]
    var kind: StoreMediaAssetKind
    var removeAsset: (StoreMediaAsset, StoreMediaAssetKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(title) · \(assets.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(OrbiterColor.textMuted)

            if assets.isEmpty {
                Text(emptyText)
                    .font(.caption)
                    .foregroundStyle(OrbiterColor.textSubtle)
                    .padding(.vertical, 4)
            } else {
                ForEach(assets) { asset in
                    MediaAssetRow(asset: asset) {
                        removeAsset(asset, kind)
                    }
                }
            }
        }
    }
}

struct MediaAssetRow: View {
    var asset: StoreMediaAsset
    var remove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: asset.kind == .screenshot ? "photo" : "play.rectangle")
                .foregroundStyle(OrbiterColor.textMuted)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(asset.fileName)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(OrbiterColor.textSubtle)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                remove()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.orbiterIcon(size: 24))
            .help("Remove asset")
        }
        .padding(.horizontal, 8)
        .frame(minHeight: 34)
        .background(OrbiterColor.panel, in: RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous))
    }

    private var detail: String {
        if asset.kind == .appPreview {
            return "\(asset.dimensionText) · \(asset.durationText) · \(asset.fileSizeText)"
        }

        return "\(asset.dimensionText) · \(asset.fileSizeText)"
    }
}

struct MediaValidationIssueRow: View {
    var issue: StoreMediaValidationIssue

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: issue.severity == .blocking ? "xmark.octagon" : "exclamationmark.triangle")
                .foregroundStyle(issue.severity == .blocking ? OrbiterColor.danger : OrbiterColor.warning)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(issue.title)
                    .font(.caption.weight(.semibold))
                Text(issue.detail)
                    .font(.caption2)
                    .foregroundStyle(OrbiterColor.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(issue.severity == .blocking ? OrbiterColor.dangerSoft : OrbiterColor.warningSoft, in: RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous))
    }
}
