import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ConnectionSetupView: View {
    @Bindable var model: AppModel

    var body: some View {
        SummaryPage(title: "Connection") {
            SummarySection(title: "Apple Account") {
                StatusRow(
                    title: "Status",
                    detail: model.userSession == nil ? "Not signed in" : "Signed in",
                    systemImage: "person.crop.circle"
                )
            }

            SummarySection(title: "App Store Connect API") {
                DataSourceModePicker(model: model)

                if model.isDemoMode {
                    DemoConnectionPanel()
                } else {
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
                }

                HStack {
                    Text("Status")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(OrbiterColor.textMuted)
                    Spacer()
                    ConnectionStatusView(status: model.activeConnection.status)
                }
            }

            SummarySection(title: "Actions") {
                HStack {
                    Button {
                        Task {
                            if model.isDemoMode {
                                await model.startDemoSession()
                            } else {
                                await model.validateConnection()
                            }
                        }
                    } label: {
                        Label(model.isDemoMode ? "Open Demo Workspace" : "Validate Connection", systemImage: model.isDemoMode ? "play.circle" : "checkmark.circle")
                    }
                    .disabled(model.isBusy)
                    .buttonStyle(.orbiter(.primary))

                    Button {
                        Task { await model.loadApps() }
                    } label: {
                        Label("Load Apps", systemImage: "arrow.down.circle")
                    }
                    .disabled(model.isBusy)
                    .buttonStyle(.orbiter(.secondary))

                    Button {
                        model.forgetStoredConnection()
                    } label: {
                        Label("Forget Stored Key", systemImage: "trash")
                    }
                    .disabled(model.isDemoMode)
                    .buttonStyle(.orbiter(.danger))
                }
            }
        }
        .navigationTitle("Connection")
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
}

struct ConnectionStatusView: View {
    var status: ConnectionStatus

    var body: some View {
        switch status {
        case .notVerified:
            Label("Not verified", systemImage: "circle")
                .foregroundStyle(OrbiterColor.textMuted)
        case let .verified(visibleAppCount):
            Label("\(visibleAppCount) apps visible", systemImage: "checkmark.circle.fill")
                .foregroundStyle(OrbiterColor.success)
        case let .failed(message):
            Label(message, systemImage: "xmark.octagon.fill")
                .foregroundStyle(OrbiterColor.danger)
        }
    }
}
