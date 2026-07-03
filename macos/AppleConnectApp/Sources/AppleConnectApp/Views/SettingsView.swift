import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        SummaryPage(title: "Settings") {
            SummarySection(title: "Appearance") {
                OrbiterSegmentedTextControl(
                    selection: $model.theme,
                    items: AppTheme.allCases.map { theme in
                        .init(id: theme, title: theme.title)
                    }
                )
            }

            SummarySection(title: "Data Source") {
                StatusRow(
                    title: "Mode",
                    detail: LocalizedStringKey(model.dataSourceMode.title),
                    systemImage: model.dataSourceMode.systemImage
                )
                DataSourceModePicker(model: model)
            }

            SummarySection(title: "Language") {
                StatusRow(title: "App Language", detail: model.appLanguage.statusTitle, systemImage: "globe")
                OrbiterSegmentedTextControl(
                    selection: $model.appLanguage,
                    items: AppLanguage.allCases.map { language in
                        .init(id: language, title: language.title)
                    }
                )
                Text("Language changes apply immediately to the app shell and localized workflow surfaces.")
                    .font(.caption)
                    .foregroundStyle(OrbiterColor.textMuted)
            }

            SummarySection(title: "Safety") {
                StatusRow(title: "Live Saves", detail: "Metadata only", systemImage: "icloud.and.arrow.up")
                StatusRow(title: "App Review", detail: "Never submitted automatically", systemImage: "checklist")
                StatusRow(title: "Demo Mode", detail: "Local simulation", systemImage: "play.circle")
            }

            SummarySection(title: "Storage") {
                StatusRow(title: "Secrets", detail: "Keychain", systemImage: "key")
                StatusRow(title: "Model Provider", detail: "Keychain", systemImage: "sparkles")
                StatusRow(title: "Drafts", detail: "Application Support", systemImage: "folder")
            }
        }
        .navigationTitle("Settings")
    }
}
