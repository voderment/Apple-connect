import SwiftUI

struct AppVersionsView: View {
    @Bindable var model: AppModel

    var body: some View {
        SummaryPage(title: "Versions") {
            if let selectedApp = model.selectedApp {
                SummarySection(title: selectedApp.name) {
                    AppSummaryRow(app: selectedApp)
                }
            }

            SummarySection(title: "Versions") {
                ForEach(model.versionsForSelectedApp) { version in
                    Button {
                        Task { await model.selectVersion(version) }
                    } label: {
                        VersionRow(version: version, isSelected: model.selectedVersionID == version.id)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Versions")
    }
}

struct AppSummaryRow: View {
    var app: ConnectApp

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(app.bundleID)
            Text("SKU \(app.sku) · Primary locale \(app.primaryLocale)")
                .font(.caption)
                .foregroundStyle(OrbiterColor.textMuted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

struct VersionRow: View {
    var version: AppStoreVersion
    var isSelected = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(version.versionString)
                    .font(.callout.weight(.semibold))
                Spacer()
                OrbiterBadge(text: version.platform, tone: .neutral)
            }
            Text(version.appVersionState)
                .font(.caption)
                .foregroundStyle(OrbiterColor.textMuted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isSelected ? OrbiterColor.selected : .clear, in: RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous))
    }
}
