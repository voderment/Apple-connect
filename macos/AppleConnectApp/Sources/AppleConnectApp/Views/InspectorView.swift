import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct InspectorView: View {
    @Bindable var model: AppModel
    @State private var changePreview: MetadataChangePreview?
    @State private var isResetConfirmationPresented = false
    @State private var isSaveConfirmationPresented = false
    @State private var isPasteJSONConfirmationPresented = false
    @State private var isOpenJSONConfirmationPresented = false
    @State private var isUpgradeHTTPSConfirmationPresented = false
    @State private var pendingImportURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                InspectorSection(title: "Release Readiness") {
                    ForEach(model.releaseReadinessItems) { item in
                        ReleaseReadinessRow(item: item)
                    }
                }

                InspectorSection(title: "Review Checklist") {
                    ForEach(model.reviewChecklistItems) { item in
                        ReviewChecklistRow(item: item)
                    }
                }

                InspectorSection(title: "Validation") {
                    if model.validationIssues.isEmpty {
                        Label("No issues", systemImage: "checkmark.circle")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(OrbiterColor.success)
                    } else {
                        ForEach(model.validationIssues) { issue in
                            ValidationIssueRow(issue: issue) {
                                model.focusValidationIssue(issue)
                            }
                        }
                    }
                }

                InspectorSection(title: "Changes") {
                    if model.publishPlan.visibleActions.isEmpty {
                        Text("No draft changes")
                            .font(.callout)
                            .foregroundStyle(OrbiterColor.textMuted)
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

                if let statusMessage = model.metadataSaveStatusMessage {
                    InspectorSection(title: "Save Status") {
                        Label(statusMessage, systemImage: model.hasMetadataChanges ? "icloud.and.arrow.up" : "checkmark.circle")
                            .font(.callout)
                            .foregroundStyle(model.hasMetadataChanges ? OrbiterColor.textMuted : OrbiterColor.success)
                    }
                }

                if let draftMessage = model.metadataDraftStatusMessage {
                    InspectorSection(title: "Draft") {
                        Label(draftMessage, systemImage: "tray.and.arrow.down")
                            .font(.callout)
                            .foregroundStyle(model.metadataDraftSavedAt == nil ? OrbiterColor.warning : OrbiterColor.textMuted)
                    }
                }

                InspectorSection(title: "Actions") {
                    Button {
                        model.updateValidation()
                        changePreview = MetadataChangePreview(
                            appName: model.selectedApp?.name ?? "",
                            versionString: model.selectedVersion?.versionString ?? "",
                            plan: model.publishPlan,
                            issues: model.validationIssues,
                            document: model.metadataDocument,
                            baseline: model.baselineDocument
                        )
                    } label: {
                        Label("Preview Changes", systemImage: "list.bullet.rectangle")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(model.metadataDocument == nil)
                    .buttonStyle(.orbiter(.secondary))

                    Button {
                        copyReviewReport()
                    } label: {
                        Label("Copy Review Report", systemImage: "checklist")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(model.metadataDocument == nil)
                    .buttonStyle(.orbiter(.secondary))

                    Button {
                        exportReviewReportFile()
                    } label: {
                        Label("Export Review Report", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(model.metadataDocument == nil)
                    .buttonStyle(.orbiter(.secondary))

                    Button {
                        isUpgradeHTTPSConfirmationPresented = true
                    } label: {
                        Label("Upgrade HTTP URLs", systemImage: "lock.shield")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(!canUpgradeHTTPURLs)
                    .buttonStyle(.orbiter(.secondary))

                    Button {
                        copyMetadataJSON()
                    } label: {
                        Label("Copy Metadata JSON", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(model.metadataDocument == nil)
                    .buttonStyle(.orbiter(.secondary))

                    Button {
                        exportMetadataJSONFile()
                    } label: {
                        Label("Export Metadata JSON", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(model.metadataDocument == nil)
                    .buttonStyle(.orbiter(.secondary))

                    Button {
                        isPasteJSONConfirmationPresented = true
                    } label: {
                        Label("Paste Metadata JSON", systemImage: "doc.on.clipboard")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(model.metadataDocument == nil)
                    .buttonStyle(.orbiter(.secondary))

                    Button {
                        selectMetadataJSONFile()
                    } label: {
                        Label("Open Metadata JSON", systemImage: "folder")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(model.metadataDocument == nil)
                    .buttonStyle(.orbiter(.secondary))

                    Button {
                        model.updateValidation()
                        isSaveConfirmationPresented = true
                    } label: {
                        Label(saveButtonTitle, systemImage: model.isDemoMode ? "tray.and.arrow.down" : "icloud.and.arrow.up")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(!canSave)
                    .buttonStyle(.orbiter(.primary))

                    Button {
                        isResetConfirmationPresented = true
                    } label: {
                        Label("Reset Changes", systemImage: "arrow.uturn.backward")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(!model.hasMetadataChanges)
                    .buttonStyle(.orbiter(.danger))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
        }
        .background(OrbiterColor.sidebar)
        .navigationTitle("Inspector")
        .sheet(item: $changePreview) { preview in
            MetadataChangePreviewSheet(preview: preview)
        }
        .confirmationDialog(
            "Reset all draft changes?",
            isPresented: $isResetConfirmationPresented
        ) {
            Button("Reset Changes", role: .destructive) {
                model.resetMetadataChanges()
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Save metadata changes?",
            isPresented: $isSaveConfirmationPresented
        ) {
            Button(saveButtonTitle) {
                Task { await model.saveMetadataChanges() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(saveConfirmationMessage)
        }
        .confirmationDialog(
            "Import metadata JSON from clipboard?",
            isPresented: $isPasteJSONConfirmationPresented
        ) {
            Button("Import JSON") {
                pasteMetadataJSON()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The current local metadata document will be replaced. Existing App Store baseline data remains available for change planning.")
        }
        .confirmationDialog(
            "Import metadata JSON from file?",
            isPresented: $isOpenJSONConfirmationPresented
        ) {
            Button("Import JSON") {
                importPendingMetadataJSONFile()
            }
            Button("Cancel", role: .cancel) {
                pendingImportURL = nil
            }
        } message: {
            Text("The current local metadata document will be replaced. Existing App Store baseline data remains available for change planning.")
        }
        .confirmationDialog(
            "Upgrade http:// URLs to HTTPS?",
            isPresented: $isUpgradeHTTPSConfirmationPresented
        ) {
            Button("Upgrade URLs") {
                model.upgradeHTTPURLsToHTTPS()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Privacy, marketing, and support URL fields that start with http:// will be changed to https:// across all locales.")
        }
    }

    private var canSave: Bool {
        model.hasMetadataChanges && !model.publishPlan.hasBlockingIssues && !model.isBusy
    }

    private var canUpgradeHTTPURLs: Bool {
        guard let localizations = model.metadataDocument?.localizations else {
            return false
        }

        return localizations.contains { localization in
            hasHTTPURL(localization.appInfo.privacyPolicyURL)
                || hasHTTPURL(localization.appInfo.privacyChoicesURL)
                || hasHTTPURL(localization.version.marketingURL)
                || hasHTTPURL(localization.version.supportURL)
        }
    }

    private var saveButtonTitle: String {
        model.isDemoMode ? "Save Demo Draft" : "Save to App Store Connect"
    }

    private var saveConfirmationMessage: String {
        if model.isDemoMode {
            return "\(model.changedFieldCount) fields across \(model.changedLocaleIDs.count) locales will update the local demo baseline."
        }

        return "\(model.changedFieldCount) fields across \(model.changedLocaleIDs.count) locales will be saved. This only updates App Store metadata and does not submit the app for review."
    }

    private var metadataExportFileName: String {
        let appPart = sanitizedFileNameComponent(model.selectedApp?.name ?? "", fallback: "metadata")
        let versionPart = sanitizedFileNameComponent(model.selectedVersion?.versionString ?? "", fallback: "version")
        return "\(appPart)-\(versionPart)-metadata.json"
    }

    private var reviewReportFileName: String {
        let appPart = sanitizedFileNameComponent(model.selectedApp?.name ?? "", fallback: "metadata")
        let versionPart = sanitizedFileNameComponent(model.selectedVersion?.versionString ?? "", fallback: "version")
        return "\(appPart)-\(versionPart)-review-report.md"
    }

    private func copyReviewReport() {
        let report = makeReviewReport()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
        model.metadataSaveStatusMessage = String(localized: "Copied review report.")
    }

    private func exportReviewReportFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = reviewReportFileName

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            try makeReviewReport().write(to: url, atomically: true, encoding: .utf8)
            model.metadataSaveStatusMessage = String(localized: "Exported \(url.lastPathComponent).")
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }

    private func makeReviewReport() -> String {
        model.reviewReportMarkdown()
    }

    private func copyMetadataJSON() {
        guard let document = model.metadataDocument else {
            return
        }

        do {
            let json = try MetadataDocumentExportFormatter.json(document: document)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(json, forType: .string)
            model.metadataSaveStatusMessage = String(localized: "Copied metadata JSON.")
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }

    private func exportMetadataJSONFile() {
        guard let document = model.metadataDocument else {
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = metadataExportFileName

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            try MetadataDocumentFileTransfer.write(document: document, to: url)
            model.metadataSaveStatusMessage = String(localized: "Exported \(url.lastPathComponent).")
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }

    private func pasteMetadataJSON() {
        guard let json = NSPasteboard.general.string(forType: .string),
              !json.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            model.errorMessage = String(localized: "Clipboard does not contain metadata JSON.")
            return
        }

        do {
            let document = try MetadataDocumentImportFormatter.document(from: json)
            model.importMetadataDocument(document)
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }

    private func selectMetadataJSONFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        pendingImportURL = url
        isOpenJSONConfirmationPresented = true
    }

    private func importPendingMetadataJSONFile() {
        guard let url = pendingImportURL else {
            return
        }

        defer {
            pendingImportURL = nil
        }

        do {
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let document = try MetadataDocumentFileTransfer.read(from: url)
            model.importMetadataDocument(document)
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }

    private func sanitizedFileNameComponent(_ value: String, fallback: String) -> String {
        let sanitized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^A-Za-z0-9_-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return sanitized.isEmpty ? fallback : sanitized
    }

    private func hasHTTPURL(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .hasPrefix("http://")
    }
}

struct ReleaseReadinessRow: View {
    var item: ReleaseReadinessItem

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: item.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.caption.weight(.semibold))
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(OrbiterColor.textMuted)
            }

            Spacer(minLength: 4)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background, in: RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: OrbiterMetric.hairline)
        }
    }

    private var tint: Color {
        switch item.level {
        case .ready:
            OrbiterColor.success
        case .warning:
            OrbiterColor.warning
        case .blocking:
            OrbiterColor.danger
        }
    }

    private var background: Color {
        switch item.level {
        case .ready:
            OrbiterColor.successSoft
        case .warning:
            OrbiterColor.warningSoft
        case .blocking:
            OrbiterColor.dangerSoft
        }
    }
}

struct ReviewChecklistRow: View {
    var item: ReviewChecklistItem

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: item.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.title)
                        .font(.caption.weight(.semibold))
                    Spacer(minLength: 4)
                    OrbiterBadge(text: statusTitle, systemImage: statusImage, tone: badgeTone)
                }

                Text(item.detail)
                    .font(.caption)

                Text(item.remediation)
                    .font(.caption)
                    .foregroundStyle(OrbiterColor.textMuted)

                if !item.affectedLocales.isEmpty {
                    Text("\(item.affectedLabel): \(localeSummary)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(OrbiterColor.textSubtle)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background, in: RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: OrbiterMetric.hairline)
        }
    }

    private var statusTitle: String {
        switch item.level {
        case .ready:
            "Ready"
        case .warning:
            "Review"
        case .blocking:
            "Blocked"
        }
    }

    private var statusImage: String {
        switch item.level {
        case .ready:
            "checkmark"
        case .warning:
            "exclamationmark.triangle"
        case .blocking:
            "xmark.octagon"
        }
    }

    private var badgeTone: OrbiterBadgeTone {
        switch item.level {
        case .ready:
            .success
        case .warning:
            .warning
        case .blocking:
            .danger
        }
    }

    private var tint: Color {
        switch item.level {
        case .ready:
            OrbiterColor.success
        case .warning:
            OrbiterColor.warning
        case .blocking:
            OrbiterColor.danger
        }
    }

    private var background: Color {
        switch item.level {
        case .ready:
            OrbiterColor.successSoft
        case .warning:
            OrbiterColor.warningSoft
        case .blocking:
            OrbiterColor.dangerSoft
        }
    }

    private var localeSummary: String {
        let visibleLocales = item.affectedLocales.prefix(4).joined(separator: ", ")
        let remainingCount = item.affectedLocales.count - 4
        if remainingCount > 0 {
            return "\(visibleLocales), +\(remainingCount)"
        }
        return visibleLocales
    }
}

struct InspectorSection<Content: View>: View {
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

struct MetadataChangePreview: Identifiable {
    let id = UUID()
    var appName: String
    var versionString: String
    var plan: MetadataPlan
    var issues: [ValidationIssue]
    var document: MetadataDocument?
    var baseline: MetadataDocument?
}

struct ValidationIssueRow: View {
    var issue: ValidationIssue
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) {
                rowContent
            }
            .buttonStyle(.plain)
            .help("Focus Locale")
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Label(issue.field, systemImage: issue.severity == .error ? "xmark.octagon" : "exclamationmark.triangle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(issue.severity == .error ? OrbiterColor.danger : OrbiterColor.warning)
                Text(issue.locale)
                    .font(.caption)
                    .foregroundStyle(OrbiterColor.textMuted)
                Text(issue.message)
                    .font(.caption)
                Text(issue.remediation)
                    .font(.caption)
                    .foregroundStyle(OrbiterColor.textMuted)
            }

            Spacer(minLength: 4)

            if action != nil {
                Image(systemName: "arrow.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(OrbiterColor.textSubtle)
                    .padding(.top, 2)
            }
        }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(OrbiterColor.panelRaised, in: RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous))
    }
}

struct ChangeActionRow: View {
    var action: MetadataChangeAction
    var document: MetadataDocument?
    var baseline: MetadataDocument?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(action.locale)
                    .font(.callout.weight(.semibold))
                Spacer()
                OrbiterBadge(text: action.kind.rawValue.capitalized, tone: .accent)
            }
            Text(resourceTitle)
                .font(.caption)
                .foregroundStyle(OrbiterColor.textMuted)
            Text(action.fields.joined(separator: ", "))
                .font(.caption)

            let changes = fieldChanges
            if !changes.isEmpty {
                VStack(spacing: 5) {
                    ForEach(changes) { change in
                        FieldChangePreviewRow(change: change)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OrbiterColor.panelRaised, in: RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous))
    }

    private var resourceTitle: String {
        switch action.resource {
        case .appInfoLocalization:
            "App Info"
        case .appStoreVersionLocalization:
            "Version"
        }
    }

    private var fieldChanges: [MetadataFieldDiff] {
        action.fields.map { field in
            MetadataFieldDiff(
                field: field,
                title: fieldTitle(field),
                before: fieldValue(field, in: baseline),
                after: fieldValue(field, in: document)
            )
        }
    }

    private func fieldTitle(_ field: String) -> String {
        switch field {
        case "privacyPolicyUrl":
            "Privacy Policy URL"
        case "privacyChoicesUrl":
            "Privacy Choices URL"
        case "marketingUrl":
            "Marketing URL"
        case "promotionalText":
            "Promotional Text"
        case "supportUrl":
            "Support URL"
        case "whatsNew":
            "What's New"
        default:
            field
                .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
                .capitalized
        }
    }

    private func fieldValue(_ field: String, in document: MetadataDocument?) -> String? {
        guard let localization = document?.localizations.first(where: { $0.locale == action.locale }) else {
            return nil
        }

        switch action.resource {
        case .appInfoLocalization:
            switch field {
            case "name":
                return localization.appInfo.name
            case "subtitle":
                return localization.appInfo.subtitle
            case "privacyPolicyUrl":
                return localization.appInfo.privacyPolicyURL
            case "privacyChoicesUrl":
                return localization.appInfo.privacyChoicesURL
            case "privacyPolicyText":
                return localization.appInfo.privacyPolicyText
            default:
                return nil
            }
        case .appStoreVersionLocalization:
            switch field {
            case "description":
                return localization.version.description
            case "keywords":
                return localization.version.keywords
            case "marketingUrl":
                return localization.version.marketingURL
            case "promotionalText":
                return localization.version.promotionalText
            case "supportUrl":
                return localization.version.supportURL
            case "whatsNew":
                return localization.version.whatsNew
            default:
                return nil
            }
        }
    }
}

struct MetadataFieldDiff: Identifiable {
    var field: String
    var title: String
    var before: String?
    var after: String?

    var id: String { field }
}

struct FieldChangePreviewRow: View {
    var change: MetadataFieldDiff

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(change.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(OrbiterColor.textMuted)

            HStack(alignment: .top, spacing: 6) {
                FieldValuePill(title: "Before", value: change.before)
                Image(systemName: "arrow.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(OrbiterColor.textSubtle)
                    .padding(.top, 6)
                FieldValuePill(title: "After", value: change.after)
            }
        }
        .padding(7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OrbiterColor.panel, in: RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous))
    }
}

struct FieldValuePill: View {
    var title: String
    var value: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(OrbiterColor.textSubtle)
            Text(previewText)
                .font(.caption)
                .lineLimit(2)
                .foregroundStyle(value == nil ? OrbiterColor.textSubtle : Color.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(OrbiterColor.panelRaised, in: RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous))
    }

    private var previewText: String {
        guard let value else {
            return "Not present"
        }

        let compact = value
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !compact.isEmpty else {
            return "Empty"
        }

        if compact.count > 140 {
            return "\(compact.prefix(140))..."
        }

        return compact
    }
}

struct MetadataChangePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var didCopySummary = false
    var preview: MetadataChangePreview

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Change Preview")
                        .font(.title2.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(OrbiterColor.textMuted)
                }

                Spacer()

                Button {
                    copySummary()
                } label: {
                    Label(didCopySummary ? "Copied" : "Copy Summary", systemImage: didCopySummary ? "checkmark" : "doc.on.doc")
                        .frame(width: 112, alignment: .leading)
                }
                .buttonStyle(.orbiter(.secondary))

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.orbiter(.secondary))
            }
            .padding(20)

            OrbiterDivider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !preview.issues.isEmpty {
                        PreviewSection(title: "Validation") {
                            ForEach(preview.issues) { issue in
                                ValidationIssueRow(issue: issue)
                            }
                        }
                    }

                    PreviewSection(title: "Draft Changes") {
                        if preview.plan.visibleActions.isEmpty {
                            Text("No draft changes")
                                .foregroundStyle(OrbiterColor.textMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 6)
                        } else {
                            ForEach(preview.plan.visibleActions) { action in
                                ChangeActionRow(
                                    action: action,
                                    document: preview.document,
                                    baseline: preview.baseline
                                )
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .background(OrbiterColor.canvas)
        .frame(width: 560, height: 520)
    }

    private var subtitle: String {
        [preview.appName, preview.versionString]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var summaryMarkdown: String {
        MetadataChangeSummaryFormatter.markdown(
            appName: preview.appName,
            versionString: preview.versionString,
            plan: preview.plan,
            issues: preview.issues,
            document: preview.document,
            baseline: preview.baseline
        )
    }

    private func copySummary() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summaryMarkdown, forType: .string)
        didCopySummary = true
    }
}

struct PreviewSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .orbiterPanel(padding: 12)
        }
    }
}
