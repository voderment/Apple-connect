import SwiftUI

struct RootView: View {
    @Bindable var model: AppModel

    var body: some View {
        Group {
            if model.userSession == nil {
                LoginView(model: model)
            } else if !model.isConnectionVerified {
                APIBindingView(model: model)
            } else {
                WorkspaceShellView(model: model)
            }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                if let notice = model.workspaceNoticeMessage {
                    WorkspaceNoticeToast(message: notice) {
                        model.workspaceNoticeMessage = nil
                    }
                }

                if model.isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .padding(8)
                        .background(OrbiterColor.panel, in: RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous)
                                .stroke(OrbiterColor.border, lineWidth: OrbiterMetric.hairline)
                        }
                }
            }
            .padding(.bottom, 12)
        }
        .orbiterPageBackground()
        .background(WindowAccessor(configure: WindowConfigurator.configure))
        .alert("Operation Failed", isPresented: errorBinding) {
            Button("OK") {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { newValue in
                if !newValue {
                    model.errorMessage = nil
                }
            }
        )
    }
}

struct WorkspaceNoticeToast: View {
    var message: String
    var dismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "tray.and.arrow.down")
                .foregroundStyle(OrbiterColor.accent)

            Text(message)
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: dismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.orbiterIcon(size: 24))
            .help("Dismiss")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: 560)
        .background(OrbiterColor.panel, in: RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous)
                .stroke(OrbiterColor.border, lineWidth: OrbiterMetric.hairline)
        }
        .shadow(color: .black.opacity(0.08), radius: 14, y: 8)
    }
}

struct WorkspaceShellView: View {
    @Bindable var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(model: model)
                .frame(width: WorkspaceShellMetric.sidebarWidth)

            WorkspaceColumnDivider()

            WorkspaceChromeColumn {
                PrimaryColumnView(model: model)
            }
            .frame(width: WorkspaceShellMetric.primaryColumnWidth)

            WorkspaceColumnDivider()

            WorkspaceChromeColumn {
                DetailColumnView(model: model)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OrbiterColor.canvas)
        .ignoresSafeArea(.container, edges: .top)
        .task(id: model.userSession?.id) {
            if model.userSession != nil, model.isConnectionVerified, model.apps.isEmpty, !model.isBusy {
                await model.loadApps()
            }
        }
    }
}

private enum WorkspaceShellMetric {
    static let sidebarWidth: CGFloat = 286
    static let primaryColumnWidth: CGFloat = 332
}

private struct WorkspaceColumnDivider: View {
    var body: some View {
        Rectangle()
            .fill(OrbiterColor.border)
            .frame(width: OrbiterMetric.hairline)
    }
}

private struct WorkspaceChromeColumn<Content: View>: View {
    @ViewBuilder var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(OrbiterColor.canvas)
    }
}

struct PrimaryColumnView: View {
    @Bindable var model: AppModel

    var body: some View {
        Group {
            switch model.sidebarSelection {
            case .dashboard, nil:
                DashboardView(model: model)
            case .connection:
                ConnectionSummaryView(model: model)
            case .copyWorkspace:
                CopyWorkspaceOverviewView(model: model)
            case .mediaAssets:
                MediaAssetsSummaryView(model: model)
            case .pricingAvailability:
                PricingAvailabilitySummaryView(model: model)
            case .appPrivacy:
                AppPrivacySummaryView(model: model)
            case .submissionSetup:
                SubmissionSetupSummaryView(model: model)
            case .ratingsCompliance:
                RatingsComplianceSummaryView(model: model)
            case .reviewPrep:
                ReviewPrepSummaryView(model: model)
            case .llmSettings:
                LLMProviderSummaryView(model: model)
            case .settings:
                SettingsSummaryView(model: model)
            case .app:
                AppVersionsView(model: model)
            }
        }
    }
}

struct DetailColumnView: View {
    @Bindable var model: AppModel

    var body: some View {
        Group {
            switch model.sidebarSelection {
            case .connection:
                ConnectionSetupView(model: model)
            case .llmSettings:
                LLMProviderSettingsView(model: model)
            case .settings:
                SettingsView(model: model)
            case .app:
                if model.metadataDocument != nil {
                    MetadataWorkspaceView(model: model)
                } else {
                    EmptyStateView(
                        title: "Select a version",
                        systemImage: "doc.text.magnifyingglass",
                        message: "Choose an App Store version to load localized metadata."
                    )
                }
            case .reviewPrep:
                ReviewPrepView(model: model)
            case .mediaAssets:
                MediaAssetsView(model: model)
            case .pricingAvailability:
                PricingAvailabilityView(model: model)
            case .appPrivacy:
                AppPrivacyView(model: model)
            case .submissionSetup:
                SubmissionSetupView(model: model)
            case .ratingsCompliance:
                RatingsComplianceView(model: model)
            case .copyWorkspace, .dashboard, nil:
                if model.metadataDocument != nil {
                    MetadataWorkspaceView(model: model)
                } else {
                    EmptyStateView(
                        title: "Metadata workspace",
                        systemImage: "globe",
                        message: "Bind App Store Connect, select an app, then choose a version to begin."
                    )
                }
            }
        }
    }
}

struct EmptyStateView: View {
    var title: LocalizedStringKey
    var systemImage: String
    var message: LocalizedStringKey

    var body: some View {
        OrbiterEmptyStateView(title: title, systemImage: systemImage, message: message)
    }
}
