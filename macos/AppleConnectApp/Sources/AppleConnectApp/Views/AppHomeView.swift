import SwiftUI

struct AppHomeView: View {
    @Bindable var model: AppModel

    private let gridColumns = [
        GridItem(.adaptive(minimum: 240, maximum: 320), spacing: 16)
    ]

    var body: some View {
        ZStack(alignment: .top) {
            OrbiterColor.canvas
                .ignoresSafeArea()

            appListLayer
                .padding(.top, 78)

            HomeFloatingToolbar(model: model)
                .padding(.leading, 92)
                .padding(.trailing, 32)
                .padding(.top, 18)
        }
        .task(id: model.userSession?.id) {
            if model.userSession != nil, model.isConnectionVerified, model.apps.isEmpty, !model.isBusy {
                await model.loadApps()
            }
        }
    }

    @ViewBuilder
    private var appListLayer: some View {
        if model.apps.isEmpty && !model.isBusy {
            EmptyStateView(
                title: "No apps found",
                systemImage: "app.dashed",
                message: "No apps were returned by App Store Connect. Check the API key role, team access, and issuer."
            )
        } else {
            ScrollView {
                if model.appListViewMode == .grid {
                    LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 16) {
                        ForEach(model.apps) { app in
                            AppGridCard(app: app) {
                                Task { await model.selectApp(app) }
                            }
                        }
                    }
                    .padding(24)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(model.apps) { app in
                            AppListRow(app: app) {
                                Task { await model.selectApp(app) }
                            }
                        }
                    }
                    .padding(24)
                }
            }
        }
    }
}

struct HomeFloatingToolbar: View {
    @Bindable var model: AppModel
    @State private var isSettingsPresented = false

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 10) {
                AccountIdentityView(
                    displayName: model.userSession?.displayName ?? "Apple Developer",
                    teamName: model.activeConnection.name
                )

                if model.isDemoMode {
                    OrbiterBadge(text: "Demo", systemImage: "play.circle", tone: .accent)
                }

                Button {
                    isSettingsPresented = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.orbiterIcon(size: 28))
                .help("Settings")
            }

            Spacer()

            HStack(spacing: 12) {
                Text("\(model.apps.count) apps")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(OrbiterColor.textMuted)
                    .monospacedDigit()

                AppViewModePicker(selection: $model.appListViewMode)

                Button {
                    model.showCreateAppPlaceholder()
                } label: {
                    Label("Create App", systemImage: "plus")
                }
                .buttonStyle(.orbiter(.primary))
            }
        }
        .padding(8)
        .background(OrbiterColor.panel.opacity(0.96), in: RoundedRectangle(cornerRadius: OrbiterMetric.radiusLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OrbiterMetric.radiusLarge, style: .continuous)
                .stroke(OrbiterColor.border, lineWidth: OrbiterMetric.hairline)
        }
        .shadow(color: .black.opacity(0.06), radius: 16, y: 8)
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView(model: model)
                .frame(width: 560, height: 420)
        }
    }
}

struct AccountIdentityView: View {
    var displayName: String
    var teamName: String

    var body: some View {
        HStack(spacing: 10) {
            AppAvatar(initials: initials)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text(displayName)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(teamName)
                    .font(.caption)
                    .foregroundStyle(OrbiterColor.textMuted)
                    .lineLimit(1)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
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

struct AppViewModePicker: View {
    @Binding var selection: AppListViewMode

    var body: some View {
        OrbiterSegmentedIconControl(
            selection: $selection,
            items: [
                .init(id: .grid, systemImage: "square.grid.2x2", title: "Grid View"),
                .init(id: .list, systemImage: "list.bullet", title: "List View")
            ]
        )
        .help("View")
    }
}

struct AppGridCard: View {
    var app: ConnectApp
    var action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 13) {
                AppIconView(name: app.name, iconURL: app.iconURL)
                    .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                    Text(app.bundleID)
                        .font(.caption)
                        .foregroundStyle(OrbiterColor.textMuted)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        OrbiterBadge(text: app.primaryLocale, tone: .neutral)
                        Text("SKU \(app.sku)")
                            .font(.caption2)
                            .foregroundStyle(OrbiterColor.textSubtle)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(isHovered ? OrbiterColor.panelRaised : OrbiterColor.panel, in: RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous)
                    .stroke(isHovered ? OrbiterColor.borderStrong : OrbiterColor.border, lineWidth: OrbiterMetric.hairline)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct AppListRow: View {
    var app: ConnectApp
    var action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                AppIconView(name: app.name, iconURL: app.iconURL)
                    .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(app.name)
                        .font(.callout.weight(.semibold))
                    Text(app.bundleID)
                        .font(.caption)
                        .foregroundStyle(OrbiterColor.textMuted)
                }

                Spacer()

                Text(app.primaryLocale)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(OrbiterColor.textMuted)
            }
            .padding(10)
            .background(isHovered ? OrbiterColor.panelRaised : OrbiterColor.panel, in: RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous)
                    .stroke(isHovered ? OrbiterColor.borderStrong : OrbiterColor.border, lineWidth: OrbiterMetric.hairline)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct AppIconView: View {
    var name: String
    var iconURL: URL?

    var body: some View {
        Group {
            if let iconURL {
                AsyncImage(url: iconURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        placeholder
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .clipShape(.rect(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(OrbiterColor.border.opacity(0.8), lineWidth: OrbiterMetric.hairline)
        }
        .accessibilityLabel(name)
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(OrbiterColor.panelPressed)
            .overlay {
                Image(systemName: "app.fill")
                    .font(.title2)
                    .foregroundStyle(OrbiterColor.textSubtle)
            }
    }
}

struct AppAvatar: View {
    var initials: String

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(OrbiterColor.accentSoft)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(OrbiterColor.accent.opacity(0.2), lineWidth: OrbiterMetric.hairline)
            }
            .overlay {
                Text(initials.isEmpty ? "A" : initials)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(OrbiterColor.accent)
            }
    }
}
