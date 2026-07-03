import SwiftUI

struct MetadataEditorView: View {
    @Binding var localization: LocaleMetadata
    var issues: [ValidationIssue] = []
    var appInfoChangedFields: Set<String> = []
    var versionChangedFields: Set<String> = []
    var onChange: () -> Void
    var onAIAction: (MetadataAIAction) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                MetadataSection(title: "App Info") {
                    EditableTextField(
                        title: "App Name",
                        text: $localization.appInfo.name,
                        isChanged: appInfoChangedFields.contains("name"),
                        issues: fieldIssues("appInfo.name"),
                        limit: 30,
                        lowerLimit: 2,
                        onChange: onChange
                    )

                    EditableTextField(
                        title: "Subtitle",
                        text: $localization.appInfo.subtitle,
                        isChanged: appInfoChangedFields.contains("subtitle"),
                        issues: fieldIssues("appInfo.subtitle"),
                        limit: 30,
                        onChange: onChange
                    )

                    EditableTextField(
                        title: "Privacy Policy URL",
                        text: $localization.appInfo.privacyPolicyURL,
                        isChanged: appInfoChangedFields.contains("privacyPolicyUrl"),
                        issues: fieldIssues("appInfo.privacyPolicyUrl"),
                        onChange: onChange
                    )

                    EditableTextField(
                        title: "Privacy Choices URL",
                        text: $localization.appInfo.privacyChoicesURL,
                        isChanged: appInfoChangedFields.contains("privacyChoicesUrl"),
                        issues: fieldIssues("appInfo.privacyChoicesUrl"),
                        onChange: onChange
                    )

                    EditableLongTextField(
                        title: "Privacy Policy Text",
                        text: $localization.appInfo.privacyPolicyText,
                        isChanged: appInfoChangedFields.contains("privacyPolicyText"),
                        issues: fieldIssues("appInfo.privacyPolicyText"),
                        minHeight: 90,
                        onChange: onChange
                    )
                }

                MetadataSection(title: "Version") {
                    MetadataAIActionGrid { action in
                        onAIAction(action)
                    }

                    EditableLongTextField(
                        title: "Description",
                        text: $localization.version.description,
                        isChanged: versionChangedFields.contains("description"),
                        issues: fieldIssues("version.description"),
                        limit: 4_000,
                        minHeight: 160,
                        onChange: onChange
                    )

                    EditableTextField(
                        title: "Keywords",
                        text: $localization.version.keywords,
                        isChanged: versionChangedFields.contains("keywords"),
                        issues: fieldIssues("version.keywords"),
                        usesKeywordLimit: true,
                        onChange: onChange
                    )

                    HStack {
                        Spacer()
                        Button {
                            localization.version.keywords = normalizedKeywords
                            onChange()
                        } label: {
                            Label("Normalize Keywords", systemImage: "line.3.horizontal.decrease.circle")
                        }
                        .buttonStyle(.orbiter(.secondary, size: .compact))
                        .disabled(!canNormalizeKeywords)
                    }

                    EditableTextField(
                        title: "Promotional Text",
                        text: $localization.version.promotionalText,
                        isChanged: versionChangedFields.contains("promotionalText"),
                        issues: fieldIssues("version.promotionalText"),
                        limit: 170,
                        onChange: onChange
                    )

                    EditableTextField(
                        title: "Support URL",
                        text: $localization.version.supportURL,
                        isChanged: versionChangedFields.contains("supportUrl"),
                        issues: fieldIssues("version.supportUrl"),
                        onChange: onChange
                    )

                    EditableTextField(
                        title: "Marketing URL",
                        text: $localization.version.marketingURL,
                        isChanged: versionChangedFields.contains("marketingUrl"),
                        issues: fieldIssues("version.marketingUrl"),
                        onChange: onChange
                    )

                    EditableLongTextField(
                        title: "What's New",
                        text: $localization.version.whatsNew,
                        isChanged: versionChangedFields.contains("whatsNew"),
                        issues: fieldIssues("version.whatsNew"),
                        limit: 4_000,
                        minHeight: 110,
                        onChange: onChange
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: 920, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(OrbiterColor.canvas)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(localization.locale)
                .font(.title2.weight(.semibold))
                .lineLimit(1)

            OrbiterBadge(text: "\(localization.completedFieldCount)/\(localization.totalFieldCount) fields", tone: .neutral)
            OrbiterBadge(text: "\(changedFieldCount) changed", systemImage: changedFieldCount > 0 ? "pencil" : nil, tone: changedFieldCount > 0 ? .accent : .neutral)
            OrbiterBadge(text: "\(issues.count) issues", systemImage: issues.isEmpty ? "checkmark.circle" : "exclamationmark.triangle", tone: issues.isEmpty ? .success : .warning)

            Spacer()
        }
        .frame(minHeight: 30)
    }

    private var changedFieldCount: Int {
        appInfoChangedFields.count + versionChangedFields.count
    }

    private var normalizedKeywords: String {
        MetadataKeywordNormalizer.normalized(localization.version.keywords)
    }

    private var canNormalizeKeywords: Bool {
        !localization.version.keywords.isEmpty && normalizedKeywords != localization.version.keywords
    }

    private func fieldIssues(_ field: String) -> [ValidationIssue] {
        issues.filter { $0.field == field }
    }
}

struct MetadataAIActionGrid: View {
    var onAction: (MetadataAIAction) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(MetadataAIAction.allCases) { action in
                Button {
                    onAction(action)
                } label: {
                    Label(action.title, systemImage: action.systemImage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.orbiter(.secondary, size: .compact))
            }
        }
    }
}

struct MetadataSection<Content: View>: View {
    var title: LocalizedStringKey
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.semibold))
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .orbiterPanel(padding: 12)
        }
    }
}

struct EditableTextField: View {
    var title: String
    @Binding var text: String
    var isChanged: Bool
    var issues: [ValidationIssue]
    var limit: Int?
    var lowerLimit: Int?
    var usesKeywordLimit = false
    var onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            MetadataFieldTitle(title: title, isChanged: isChanged)

            TextField(title, text: $text)
                .textFieldStyle(.plain)
                .font(.callout)
                .padding(.horizontal, 10)
                .frame(height: OrbiterMetric.controlHeight)
                .orbiterFieldChrome(isInvalid: !issues.isEmpty)
                .onChange(of: text) { onChange() }

            if usesKeywordLimit {
                KeywordLimitView(value: text)
            } else if let limit {
                FieldLimitView(value: text, limit: limit, lowerLimit: lowerLimit)
            }

            ValidationMessagesView(issues: issues)
        }
    }
}

struct EditableLongTextField: View {
    var title: String
    @Binding var text: String
    var isChanged: Bool
    var issues: [ValidationIssue]
    var limit: Int?
    var minHeight: CGFloat
    var onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            MetadataFieldTitle(title: title, isChanged: isChanged)

            TextEditor(text: $text)
                .font(.callout)
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight)
                .padding(8)
                .orbiterFieldChrome(isInvalid: !issues.isEmpty)
                .onChange(of: text) { onChange() }

            if let limit {
                FieldLimitView(value: text, limit: limit)
            }

            ValidationMessagesView(issues: issues)
        }
    }
}

struct MetadataFieldTitle: View {
    var title: String
    var isChanged: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(OrbiterColor.textMuted)

            if isChanged {
                OrbiterBadge(text: "Edited", systemImage: "pencil", tone: .accent)
            }
        }
    }
}

struct ValidationMessagesView: View {
    var issues: [ValidationIssue]

    var body: some View {
        if !issues.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(issues) { issue in
                    Label(issue.message, systemImage: issue.severity == .error ? "xmark.octagon" : "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(issue.severity == .error ? OrbiterColor.danger : OrbiterColor.warning)
                }
            }
            .padding(.top, 2)
        }
    }
}

struct FieldLimitView: View {
    var value: String
    var limit: Int
    var lowerLimit: Int?

    var body: some View {
        HStack {
            Spacer()
            Text(statusText)
                .font(.caption)
                .foregroundStyle(isInvalid ? OrbiterColor.danger : OrbiterColor.textMuted)
        }
    }

    private var statusText: String {
        if let lowerLimit, !value.isEmpty, value.count < lowerLimit {
            return "\(value.count)/\(limit), minimum \(lowerLimit)"
        }

        return "\(value.count)/\(limit)"
    }

    private var isInvalid: Bool {
        value.count > limit || (lowerLimit != nil && !value.isEmpty && value.count < (lowerLimit ?? 0))
    }
}

struct KeywordLimitView: View {
    var value: String

    var body: some View {
        HStack {
            Spacer()
            Text("\(value.lengthOfBytes(using: .utf8))/100 UTF-8 bytes")
                .font(.caption)
                .foregroundStyle(value.lengthOfBytes(using: .utf8) > 100 ? OrbiterColor.danger : OrbiterColor.textMuted)
        }
    }
}
