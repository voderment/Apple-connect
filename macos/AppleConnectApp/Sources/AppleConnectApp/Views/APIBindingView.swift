import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct APIBindingView: View {
    @Bindable var model: AppModel

    var body: some View {
        ZStack {
            OrbiterColor.canvas
                .ignoresSafeArea()

            VStack(spacing: 22) {
                VStack(spacing: 8) {
                    Text("Connect App Store Connect")
                        .font(.title.weight(.semibold))
                    Text("Sign in identifies your Fact account. The API key grants Fact permission to read and manage App Store Connect data.")
                        .foregroundStyle(OrbiterColor.textMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 560)
                }

                VStack(alignment: .leading, spacing: 18) {
                    AccountSummaryStrip(
                        displayName: model.userSession?.displayName ?? "Apple Developer",
                        email: model.userSession?.email,
                        teamName: model.activeConnection.name
                    )

                    DataSourceModePicker(model: model)

                    OrbiterDivider()

                    if model.isDemoMode {
                        DemoConnectionPanel()
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Connection Name", text: $model.activeConnection.name)
                                .orbiterInputChrome()
                            TextField("Key ID", text: $model.activeConnection.keyID)
                                .orbiterInputChrome()
                            TextField("Issuer ID", text: $model.activeConnection.issuerID)
                                .orbiterInputChrome()

                            HStack {
                                TextField("Private Key Path", text: $model.activeConnection.privateKeyPath)
                                    .orbiterInputChrome()
                                Button {
                                    choosePrivateKey()
                                } label: {
                                    Label("Choose", systemImage: "folder")
                                }
                                .buttonStyle(.orbiter(.secondary))
                            }

                            if model.activeConnection.privateKeyPEM.isEmpty {
                                Text("Private key content has not been loaded yet.")
                                    .font(.caption)
                                    .foregroundStyle(OrbiterColor.textMuted)
                            } else {
                                Label("Private key loaded and ready to store in Keychain.", systemImage: "checkmark.seal")
                                    .font(.caption)
                                    .foregroundStyle(OrbiterColor.success)
                            }

                            ConnectionStatusView(status: model.activeConnection.status)
                        }
                    }

                    HStack {
                        Button {
                            model.signOut()
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                        .buttonStyle(.orbiter(.secondary))

                        Spacer()

                        Button {
                            Task {
                                if model.isDemoMode {
                                    await model.startDemoSession()
                                } else {
                                    await model.validateConnection()
                                }
                            }
                        } label: {
                            Label(primaryActionTitle, systemImage: model.isDemoMode ? "play.circle" : "checkmark.circle")
                        }
                        .buttonStyle(.orbiter(.primary))
                        .disabled(model.isBusy)
                    }
                }
                .padding(20)
                .frame(width: 620)
                .background(OrbiterColor.panel, in: RoundedRectangle(cornerRadius: OrbiterMetric.radiusLarge, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: OrbiterMetric.radiusLarge, style: .continuous)
                        .stroke(OrbiterColor.border, lineWidth: OrbiterMetric.hairline)
                }
            }
            .padding(40)
        }
    }

    private func choosePrivateKey() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [UTType(filenameExtension: "p8") ?? .data]
        if panel.runModal() == .OK, let url = panel.url {
            do {
                model.activeConnection.privateKeyPath = url.path
                model.activeConnection.privateKeyPEM = try String(contentsOf: url, encoding: .utf8)
            } catch {
                model.errorMessage = error.localizedDescription
            }
        }
    }

    private var primaryActionTitle: String {
        model.isDemoMode ? "Open Demo Workspace" : "Validate and Continue"
    }
}

struct DataSourceModePicker: View {
    @Bindable var model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AppDataSourceMode.allCases) { mode in
                Button {
                    model.switchDataSourceMode(mode)
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: mode.systemImage)
                            .frame(width: 18)
                            .foregroundStyle(model.dataSourceMode == mode ? OrbiterColor.accent : OrbiterColor.textMuted)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.title)
                                .font(.callout.weight(.medium))
                            Text(mode.detail)
                                .font(.caption)
                                .foregroundStyle(OrbiterColor.textMuted)
                        }

                        Spacer(minLength: 4)

                        if model.dataSourceMode == mode {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(OrbiterColor.accent)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                    .background(model.dataSourceMode == mode ? OrbiterColor.selected : OrbiterColor.panelRaised, in: RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous)
                            .stroke(model.dataSourceMode == mode ? OrbiterColor.accent.opacity(0.24) : OrbiterColor.border, lineWidth: OrbiterMetric.hairline)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct DemoConnectionPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            StatusRow(title: "Workspace", detail: "Demo data", systemImage: "play.circle")
            StatusRow(title: "Secrets", detail: "Not required", systemImage: "key.slash")
            StatusRow(title: "Publishing", detail: "Local simulation", systemImage: "icloud.slash")
        }
        .orbiterPanel(padding: 8)
    }
}

struct AccountSummaryStrip: View {
    var displayName: String
    var email: String?
    var teamName: String

    var body: some View {
        HStack(spacing: 12) {
            AppAvatar(initials: initials)
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(displayName)
                    .font(.headline.weight(.semibold))
                Text(email ?? "Apple account")
                    .font(.caption)
                    .foregroundStyle(OrbiterColor.textMuted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("Team")
                    .font(.caption)
                    .foregroundStyle(OrbiterColor.textMuted)
                Text(teamName)
                    .font(.callout.weight(.medium))
            }
        }
    }

    private var initials: String {
        displayName
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }
}
