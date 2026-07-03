import AuthenticationServices
import SwiftUI

struct SidebarView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: 56)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    OrbiterSidebarSection(title: "Workspace") {
                        OrbiterSidebarRow(
                            title: "Dashboard",
                            systemImage: "square.grid.2x2",
                            isSelected: model.sidebarSelection == .dashboard
                        ) {
                            model.sidebarSelection = .dashboard
                        }

                        OrbiterSidebarRow(
                            title: "Localized Copy",
                            systemImage: "globe",
                            isSelected: model.sidebarSelection == .copyWorkspace
                        ) {
                            model.sidebarSelection = .copyWorkspace
                        }

                        OrbiterSidebarRow(
                            title: "Media Assets",
                            systemImage: "photo.on.rectangle",
                            isSelected: model.sidebarSelection == .mediaAssets
                        ) {
                            model.sidebarSelection = .mediaAssets
                        } accessory: {
                            if model.mediaValidationSummary.blockingCount > 0 {
                                OrbiterBadge(text: "\(model.mediaValidationSummary.blockingCount)", tone: .danger)
                            }
                        }

                        OrbiterSidebarRow(
                            title: "Pricing",
                            systemImage: "tag",
                            isSelected: model.sidebarSelection == .pricingAvailability
                        ) {
                            model.sidebarSelection = .pricingAvailability
                        } accessory: {
                            if model.pricingAvailabilitySummary.blockingCount > 0 {
                                OrbiterBadge(text: "\(model.pricingAvailabilitySummary.blockingCount)", tone: .danger)
                            }
                        }

                        OrbiterSidebarRow(
                            title: "App Privacy",
                            systemImage: "hand.raised",
                            isSelected: model.sidebarSelection == .appPrivacy
                        ) {
                            model.sidebarSelection = .appPrivacy
                        } accessory: {
                            if model.appPrivacySummary.blockingCount > 0 {
                                OrbiterBadge(text: "\(model.appPrivacySummary.blockingCount)", tone: .danger)
                            }
                        }

                        OrbiterSidebarRow(
                            title: "Submission",
                            systemImage: "shippingbox",
                            isSelected: model.sidebarSelection == .submissionSetup
                        ) {
                            model.sidebarSelection = .submissionSetup
                        } accessory: {
                            if model.submissionSetupSummary.blockingCount > 0 {
                                OrbiterBadge(text: "\(model.submissionSetupSummary.blockingCount)", tone: .danger)
                            }
                        }

                        OrbiterSidebarRow(
                            title: "Ratings",
                            systemImage: "shield.lefthalf.filled",
                            isSelected: model.sidebarSelection == .ratingsCompliance
                        ) {
                            model.sidebarSelection = .ratingsCompliance
                        } accessory: {
                            if model.ratingsComplianceSummary.blockingCount > 0 {
                                OrbiterBadge(text: "\(model.ratingsComplianceSummary.blockingCount)", tone: .danger)
                            }
                        }

                        OrbiterSidebarRow(
                            title: "Review Prep",
                            systemImage: "checklist",
                            isSelected: model.sidebarSelection == .reviewPrep
                        ) {
                            model.sidebarSelection = .reviewPrep
                        }
                    }

                    OrbiterSidebarSection(title: "Apps") {
                        if model.apps.isEmpty {
                            OrbiterSidebarRow(
                                title: "No apps loaded",
                                systemImage: "app.dashed",
                                isSelected: false,
                                isMuted: true
                            ) {}
                        } else {
                            ForEach(model.apps) { app in
                                OrbiterSidebarRow(
                                    title: app.name,
                                    subtitle: app.bundleID,
                                    systemImage: "app",
                                    isSelected: model.sidebarSelection == .app(app.id)
                                ) {
                                    model.sidebarSelection = .app(app.id)
                                }
                                .contextMenu {
                                    Button("Load Versions") {
                                        Task { await model.selectApp(app) }
                                    }
                                }
                            }
                        }
                    }

                    OrbiterSidebarSection(title: "Setup") {
                        OrbiterSidebarRow(
                            title: "Connection",
                            systemImage: "key",
                            isSelected: model.sidebarSelection == .connection
                        ) {
                            model.sidebarSelection = .connection
                        }

                        OrbiterSidebarRow(
                            title: "Model Provider",
                            systemImage: "sparkles",
                            isSelected: model.sidebarSelection == .llmSettings
                        ) {
                            model.sidebarSelection = .llmSettings
                        }

                        OrbiterSidebarRow(
                            title: "Settings",
                            systemImage: "gearshape",
                            isSelected: model.sidebarSelection == .settings
                        ) {
                            model.sidebarSelection = .settings
                        }
                    }
                }
                .padding(10)
            }

            AccountFooterView(model: model)
        }
        .background(OrbiterColor.sidebar.ignoresSafeArea())
        .onChange(of: model.sidebarSelection) { _, newSelection in
            if case let .app(appID) = newSelection,
               let app = model.apps.first(where: { $0.id == appID }) {
                Task { await model.selectApp(app) }
            }
        }
    }
}

struct AccountFooterView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            OrbiterDivider()

            if let userSession = model.userSession {
                HStack(spacing: 8) {
                    AppAvatar(initials: userInitials(userSession))
                        .frame(width: 28, height: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(userSession.displayName ?? "Apple Developer")
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                        if let email = userSession.email {
                            Text(email)
                                .font(.caption)
                                .foregroundStyle(OrbiterColor.textMuted)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Button {
                        model.signOut()
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                    .buttonStyle(.orbiterIcon(size: 28))
                    .help("Sign Out")
                }
            } else {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    switch result {
                    case let .success(authorization):
                        let credential = authorization.credential as? ASAuthorizationAppleIDCredential
                        let name = credential?.fullName
                            .map { PersonNameComponentsFormatter().string(from: $0) }
                        model.completeAppleSignIn(displayName: name, email: credential?.email)
                    case let .failure(error):
                        model.errorMessage = error.localizedDescription
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 32)
                .help("Sign in with your Apple Account")
            }
        }
        .padding(10)
        .background(OrbiterColor.sidebar)
    }

    private func userInitials(_ userSession: UserSession) -> String {
        (userSession.displayName ?? "Apple Developer")
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }
}
