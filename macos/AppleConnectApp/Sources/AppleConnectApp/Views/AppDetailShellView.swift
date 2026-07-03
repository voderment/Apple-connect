import SwiftUI

struct AppDetailShellView: View {
    @Bindable var model: AppModel

    var body: some View {
        NavigationSplitView {
            AppDetailSidebar(model: model)
        } detail: {
            AppDetailReadOnlyView(model: model)
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    model.returnToHome()
                } label: {
                    Label("Apps", systemImage: "chevron.left")
                }
                .buttonStyle(.orbiter(.ghost, size: .compact))

                Button {
                    Task { await model.refreshCurrentSelection() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(model.isBusy)
                .buttonStyle(.orbiter(.secondary, size: .compact))
            }
        }
        .orbiterPageBackground()
    }
}

struct AppDetailSidebar: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            if let app = model.selectedApp {
                AppDetailHeader(app: app)
                    .padding(12)
            }

            OrbiterDivider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    OrbiterSidebarSection(title: "App") {
                        OrbiterSidebarRow(
                            title: "Overview",
                            systemImage: "info.circle",
                            isSelected: model.detailSelection == .overview
                        ) {
                            model.detailSelection = .overview
                        }

                        OrbiterSidebarRow(
                            title: "App Information",
                            systemImage: "app.badge",
                            isSelected: model.detailSelection == .appInformation
                        ) {
                            model.detailSelection = .appInformation
                        }

                        OrbiterSidebarRow(
                            title: "Localized Copy",
                            systemImage: "globe",
                            isSelected: model.detailSelection == .localizedCopy
                        ) {
                            model.detailSelection = .localizedCopy
                        } accessory: {
                            if model.hasMetadataChanges {
                                OrbiterBadge(text: "\(model.changedFieldCount)", tone: .accent)
                            }
                        }
                    }

                    OrbiterSidebarSection(title: "Platforms and Versions") {
                        ForEach(groupedVersions, id: \.platform) { group in
                            DisclosureGroup {
                                VStack(spacing: 2) {
                                    ForEach(group.versions) { version in
                                        VersionSidebarRow(
                                            version: version,
                                            isSelected: model.detailSelection == .version(version.id)
                                        ) {
                                            model.detailSelection = .version(version.id)
                                        }
                                    }
                                }
                                .padding(.top, 3)
                            } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: "rectangle.stack")
                                        .font(.caption)
                                        .foregroundStyle(OrbiterColor.textMuted)
                                    Text(group.platform)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(OrbiterColor.textMuted)
                                    Spacer()
                                    OrbiterBadge(text: "\(group.versions.count)", tone: .neutral)
                                }
                                .padding(.vertical, 4)
                            }
                            .padding(.horizontal, 8)
                            .tint(OrbiterColor.textMuted)
                        }
                    }
                }
                .padding(10)
            }
        }
        .background(OrbiterColor.sidebar.ignoresSafeArea())
        .navigationTitle(model.selectedApp?.name ?? AppConstants.productName)
        .navigationSplitViewColumnWidth(min: 260, ideal: 300)
        .onChange(of: model.detailSelection) { _, newValue in
            if case let .version(versionID) = newValue,
               let version = model.versionsForSelectedApp.first(where: { $0.id == versionID }) {
                Task { await model.selectVersion(version) }
            }
        }
    }

    private var groupedVersions: [VersionGroup] {
        let groups = Dictionary(grouping: model.versionsForSelectedApp, by: \.platform)
        return groups
            .map { VersionGroup(platform: $0.key, versions: $0.value.sorted { $0.createdDate > $1.createdDate }) }
            .sorted { $0.platform < $1.platform }
    }
}

struct AppDetailHeader: View {
    var app: ConnectApp

    var body: some View {
        HStack(spacing: 12) {
            AppIconView(name: app.name)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                Text(app.bundleID)
                    .font(.caption)
                    .foregroundStyle(OrbiterColor.textMuted)
                    .lineLimit(1)
                OrbiterBadge(text: app.primaryLocale, tone: .neutral)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct VersionSidebarRow: View {
    var version: AppStoreVersion
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: "tag")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isSelected ? OrbiterColor.accent : OrbiterColor.textMuted)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(version.versionString)
                        .font(.callout.weight(isSelected ? .semibold : .regular))
                        .lineLimit(1)
                    Text(version.appVersionState)
                        .font(.caption2)
                        .foregroundStyle(OrbiterColor.textSubtle)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(minHeight: 38)
            .background(isSelected ? OrbiterColor.selected : .clear, in: RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous)
                    .stroke(isSelected ? OrbiterColor.accent.opacity(0.18) : .clear, lineWidth: OrbiterMetric.hairline)
            }
        }
        .buttonStyle(.plain)
    }
}

struct VersionGroup {
    var platform: String
    var versions: [AppStoreVersion]
}

struct AppDetailReadOnlyView: View {
    @Bindable var model: AppModel

    var body: some View {
        Group {
            if model.detailSelection == .localizedCopy {
                MetadataWorkspaceView(model: model)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch model.detailSelection ?? .overview {
                        case .overview:
                            AppOverviewPanel(model: model)
                        case .appInformation:
                            AppInformationPanel(model: model)
                        case .localizedCopy:
                            EmptyView()
                        case let .version(versionID):
                            VersionReadOnlyPanel(
                                app: model.selectedApp,
                                version: model.versionsForSelectedApp.first { $0.id == versionID }
                            )
                            VersionLocalizationReadOnlyPanel(
                                document: model.metadataDocument,
                                isLoading: model.isBusy
                            )
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: 860, alignment: .leading)
                }
                .background(OrbiterColor.canvas)
            }
        }
        .navigationTitle(detailTitle)
    }

    private var detailTitle: String {
        switch model.detailSelection ?? .overview {
        case .overview:
            "Overview"
        case .appInformation:
            "App Information"
        case .localizedCopy:
            "Localized Copy"
        case .version:
            "Version"
        }
    }
}

struct AppOverviewPanel: View {
    @Bindable var model: AppModel

    var body: some View {
        if let app = model.selectedApp {
            ReadOnlySection(title: "App") {
                ReadOnlyField(title: "Name", value: app.name)
                ReadOnlyField(title: "Bundle ID", value: app.bundleID)
                ReadOnlyField(title: "SKU", value: app.sku)
                ReadOnlyField(title: "Primary Locale", value: app.primaryLocale)
            }

            ReadOnlySection(title: "Versions") {
                ReadOnlyField(title: "Available Versions", value: "\(model.versionsForSelectedApp.count)")
                if let selectedVersion = model.selectedVersion {
                    ReadOnlyField(title: "Selected Version", value: selectedVersion.versionString)
                    ReadOnlyField(title: "State", value: selectedVersion.appVersionState)
                }
            }

            ReleaseReadinessOverviewSection(items: model.releaseReadinessItems) {
                model.detailSelection = .localizedCopy
            }

            ReadOnlySection(title: "App Info") {
                ReadOnlyField(title: "App Info Resources", value: "\(model.appInfosForSelectedApp.count)")
                if let appInfo = model.appInfosForSelectedApp.first {
                    ReadOnlyField(title: "Current State", value: appInfo.state)
                    ReadOnlyField(title: "App Store State", value: appInfo.appStoreState)
                }
            }
        } else {
            EmptyStateView(title: "No app selected", systemImage: "app", message: "Return to the app list and select an app.")
        }
    }
}

struct ReleaseReadinessOverviewSection: View {
    var items: [ReleaseReadinessItem]
    var openLocalizedCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Release Readiness")
                    .font(.headline)

                Spacer()

                Button {
                    openLocalizedCopy()
                } label: {
                    Label("Open Copy", systemImage: "globe")
                }
                .buttonStyle(.orbiter(.secondary, size: .compact))
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items) { item in
                    ReleaseReadinessRow(item: item)
                }
            }
        }
    }
}

struct AppInformationPanel: View {
    @Bindable var model: AppModel

    var body: some View {
        if let app = model.selectedApp {
            ReadOnlySection(title: "Global App Information") {
                ReadOnlyField(title: "Name", value: app.name)
                ReadOnlyField(title: "Bundle ID", value: app.bundleID)
                ReadOnlyField(title: "SKU", value: app.sku)
                ReadOnlyField(title: "Primary Locale", value: app.primaryLocale)
            }

            ReadOnlySection(title: "App Info Resources") {
                if model.appInfosForSelectedApp.isEmpty {
                    ReadOnlyField(title: "Status", value: "No App Info resources returned.")
                } else {
                    ForEach(model.appInfosForSelectedApp) { appInfo in
                        ReadOnlyField(title: "Resource ID", value: appInfo.id)
                        ReadOnlyField(title: "State", value: appInfo.state)
                        ReadOnlyField(title: "App Store State", value: appInfo.appStoreState)
                    }
                }
            }
        }
    }
}

struct LocalizedCopyReadOnlyPanel: View {
    @Bindable var model: AppModel

    var body: some View {
        if let document = model.metadataDocument {
            ReadOnlySection(title: "Localized Copy") {
                ReadOnlyField(title: "Selected Version", value: model.selectedVersion?.versionString ?? "")
                ReadOnlyField(title: "Loaded Locales", value: "\(document.localizations.count)")
                ReadOnlyField(title: "Last Pulled", value: document.pulledAt.formatted(date: .abbreviated, time: .shortened))
                ReadOnlyField(title: "Validation Issues", value: "\(model.validationIssues.count)")
                ReadOnlyField(title: "Pending Changes", value: "\(model.publishPlan.visibleActions.count)")
            }

            if document.localizations.isEmpty {
                EmptyStateView(
                    title: "No localized copy",
                    systemImage: "globe.badge.chevron.backward",
                    message: "No App Info or version localizations were returned for this version."
                )
            } else {
                ForEach(document.localizations) { localization in
                    LocaleCopyReadOnlySection(localization: localization, mode: .full)
                }
            }
        } else if model.isBusy {
            EmptyStateView(
                title: "Loading localized copy",
                systemImage: "arrow.clockwise",
                message: "Fact is reading App Info and version localizations from App Store Connect."
            )
        } else {
            EmptyStateView(
                title: "Localized copy unavailable",
                systemImage: "globe",
                message: "Select an app and version to load localized metadata."
            )
        }
    }
}

struct VersionReadOnlyPanel: View {
    var app: ConnectApp?
    var version: AppStoreVersion?

    var body: some View {
        if let version {
            ReadOnlySection(title: "Version") {
                ReadOnlyField(title: "App", value: app?.name ?? "")
                ReadOnlyField(title: "Platform", value: version.platform)
                ReadOnlyField(title: "Version String", value: version.versionString)
                ReadOnlyField(title: "App Version State", value: version.appVersionState)
                ReadOnlyField(title: "App Store State", value: version.appStoreState)
                ReadOnlyField(title: "Created", value: version.createdDate.formatted(date: .abbreviated, time: .shortened))
            }
        } else {
            EmptyStateView(title: "Version unavailable", systemImage: "clock.badge.questionmark", message: "Select a version from the sidebar.")
        }
    }
}

struct VersionLocalizationReadOnlyPanel: View {
    var document: MetadataDocument?
    var isLoading: Bool

    var body: some View {
        if let document {
            ReadOnlySection(title: "Version Localizations") {
                ReadOnlyField(title: "Loaded Locales", value: "\(document.localizations.count)")
                ReadOnlyField(title: "Last Pulled", value: document.pulledAt.formatted(date: .abbreviated, time: .shortened))
            }

            if document.localizations.isEmpty {
                EmptyStateView(
                    title: "No version copy",
                    systemImage: "doc.text.magnifyingglass",
                    message: "No version localizations were returned for the selected version."
                )
            } else {
                ForEach(document.localizations) { localization in
                    LocaleCopyReadOnlySection(localization: localization, mode: .versionOnly)
                }
            }
        } else if isLoading {
            EmptyStateView(
                title: "Loading version copy",
                systemImage: "arrow.clockwise",
                message: "Fact is reading localized metadata for the selected version."
            )
        }
    }
}

enum LocaleCopyReadOnlyMode {
    case full
    case versionOnly
}

struct LocaleCopyReadOnlySection: View {
    var localization: LocaleMetadata
    var mode: LocaleCopyReadOnlyMode

    var body: some View {
        ReadOnlySection(title: title) {
            if mode == .full {
                ReadOnlyGroupLabel(title: "App Info")
                ReadOnlyField(title: "App Name", value: localization.appInfo.name)
                ReadOnlyField(title: "Subtitle", value: localization.appInfo.subtitle)
                ReadOnlyField(title: "Privacy Policy URL", value: localization.appInfo.privacyPolicyURL)
                ReadOnlyField(title: "Privacy Choices URL", value: localization.appInfo.privacyChoicesURL)
                ReadOnlyLongField(title: "Privacy Policy Text", value: localization.appInfo.privacyPolicyText)
            }

            ReadOnlyGroupLabel(title: "Version")
            ReadOnlyLongField(title: "Description", value: localization.version.description)
            ReadOnlyField(title: "Keywords", value: localization.version.keywords)
            ReadOnlyField(title: "Promotional Text", value: localization.version.promotionalText)
            ReadOnlyField(title: "Support URL", value: localization.version.supportURL)
            ReadOnlyField(title: "Marketing URL", value: localization.version.marketingURL)
            ReadOnlyLongField(title: "What's New", value: localization.version.whatsNew)
        }
    }

    private var title: String {
        let completed = mode == .full ? localization.completedFieldCount : localization.version.completedFieldCount
        let total = mode == .full ? localization.totalFieldCount : localization.version.totalFieldCount
        return "\(localization.locale) · \(completed)/\(total) fields"
    }
}

struct ReadOnlySection<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            VStack(spacing: 0) {
                content
            }
            .background(OrbiterColor.panel, in: RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous)
                    .stroke(OrbiterColor.border, lineWidth: OrbiterMetric.hairline)
            }
        }
    }
}

struct ReadOnlyGroupLabel: View {
    var title: String

    var body: some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(OrbiterColor.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(OrbiterColor.panelPressed)
            .overlay(alignment: .bottom) {
                OrbiterDivider()
            }
    }
}

struct ReadOnlyField: View {
    var title: String
    var value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(OrbiterColor.textMuted)
                .frame(width: 170, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            OrbiterDivider()
        }
    }
}

struct ReadOnlyLongField: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(OrbiterColor.textMuted)
            Text(value.isEmpty ? "—" : value)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            OrbiterDivider()
        }
    }
}
