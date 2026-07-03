import SwiftUI

@main
struct AppleConnectApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .environment(\.locale, model.appLanguage.locale)
                .preferredColorScheme(model.theme.colorScheme)
        }
        .defaultSize(width: 1280, height: 820)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandMenu("Workspace") {
                Button("Refresh") {
                    Task { await model.refreshCurrentSelection() }
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button("Validate Metadata") {
                    model.updateValidation()
                }
                .keyboardShortcut("k", modifiers: [.command])

                Button("Save Metadata Changes") {
                    Task { await model.saveMetadataChanges() }
                }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(!model.hasMetadataChanges || model.publishPlan.hasBlockingIssues || model.isBusy)
            }
        }

        Settings {
            SettingsView(model: model)
                .frame(width: 560, height: 520)
                .environment(\.locale, model.appLanguage.locale)
                .preferredColorScheme(model.theme.colorScheme)
        }
    }
}
