import AppKit
import SwiftUI

enum OrbiterColor {
    static let canvas = dynamic(light: 0xF6F7F9, dark: 0x101114)
    static let sidebar = dynamic(light: 0xEEF1F5, dark: 0x0D0E11)
    static let panel = dynamic(light: 0xFFFFFF, dark: 0x181A1F)
    static let panelRaised = dynamic(light: 0xFBFCFE, dark: 0x202228)
    static let panelPressed = dynamic(light: 0xEAEDF3, dark: 0x252832)
    static let selected = dynamic(light: 0xE8ECFA, dark: 0x212944)
    static let field = dynamic(light: 0xFBFCFE, dark: 0x111318)
    static let border = dynamic(light: 0xDADDE5, dark: 0x30333D)
    static let borderStrong = dynamic(light: 0xC6CBD5, dark: 0x444957)
    static let textMuted = dynamic(light: 0x626A78, dark: 0xA7ADBA)
    static let textSubtle = dynamic(light: 0x8A92A0, dark: 0x747C8B)
    static let accent = dynamic(light: 0x5E6AD2, dark: 0x8D95F2)
    static let accentSoft = dynamic(light: 0xEEF0FF, dark: 0x252A46)
    static let success = dynamic(light: 0x218A5A, dark: 0x5BC98D)
    static let successSoft = dynamic(light: 0xEAF7F0, dark: 0x183A2A)
    static let warning = dynamic(light: 0xB46B16, dark: 0xF0B35B)
    static let warningSoft = dynamic(light: 0xFFF4E3, dark: 0x3A2A14)
    static let danger = dynamic(light: 0xC33A3A, dark: 0xFF7777)
    static let dangerSoft = dynamic(light: 0xFDECEC, dark: 0x3F1E22)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            return NSColor(hex: match == .darkAqua ? dark : light)
        })
    }
}

enum OrbiterMetric {
    static let hairline: CGFloat = 0.65
    static let radiusSmall: CGFloat = 5
    static let radius: CGFloat = 7
    static let radiusLarge: CGFloat = 10
    static let controlHeight: CGFloat = 30
    static let compactControlHeight: CGFloat = 26
    static let sidebarRowHeight: CGFloat = 30
}

enum OrbiterButtonRole {
    case primary
    case secondary
    case ghost
    case danger
}

enum OrbiterButtonSize {
    case compact
    case regular

    var height: CGFloat {
        switch self {
        case .compact:
            OrbiterMetric.compactControlHeight
        case .regular:
            OrbiterMetric.controlHeight
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .compact:
            9
        case .regular:
            12
        }
    }

    var font: Font {
        switch self {
        case .compact:
            .caption.weight(.medium)
        case .regular:
            .callout.weight(.medium)
        }
    }
}

struct OrbiterButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    var role: OrbiterButtonRole = .secondary
    var size: OrbiterButtonSize = .regular

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .labelStyle(.titleAndIcon)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, size.horizontalPadding)
            .frame(height: size.height)
            .background(backgroundColor(isPressed: configuration.isPressed), in: RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous)
                    .stroke(borderColor, lineWidth: OrbiterMetric.hairline)
            }
            .opacity(isEnabled ? 1 : 0.48)
            .contentShape(.rect(cornerRadius: OrbiterMetric.radius))
    }

    private var foregroundColor: Color {
        switch role {
        case .primary:
            .white
        case .danger:
            OrbiterColor.danger
        case .secondary, .ghost:
            .primary
        }
    }

    private var borderColor: Color {
        switch role {
        case .primary:
            OrbiterColor.accent.opacity(0.7)
        case .danger:
            OrbiterColor.danger.opacity(0.35)
        case .secondary:
            OrbiterColor.border
        case .ghost:
            .clear
        }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isPressed {
            switch role {
            case .primary:
                return OrbiterColor.accent.opacity(0.78)
            case .danger:
                return OrbiterColor.dangerSoft.opacity(0.86)
            case .secondary, .ghost:
                return OrbiterColor.panelPressed
            }
        }

        switch role {
        case .primary:
            return OrbiterColor.accent
        case .danger:
            return OrbiterColor.dangerSoft
        case .secondary:
            return OrbiterColor.panelRaised
        case .ghost:
            return .clear
        }
    }
}

struct OrbiterIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    var isSelected = false
    var size: CGFloat = 30

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.medium))
            .foregroundStyle(isSelected ? OrbiterColor.accent : Color.primary)
            .frame(width: size, height: size)
            .background(backgroundColor(isPressed: configuration.isPressed), in: RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous)
                    .stroke(isSelected ? OrbiterColor.accent.opacity(0.32) : OrbiterColor.border, lineWidth: OrbiterMetric.hairline)
            }
            .opacity(isEnabled ? 1 : 0.48)
            .contentShape(.rect(cornerRadius: OrbiterMetric.radius))
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isPressed {
            return OrbiterColor.panelPressed
        }

        return isSelected ? OrbiterColor.accentSoft : OrbiterColor.panelRaised
    }
}

extension ButtonStyle where Self == OrbiterButtonStyle {
    static func orbiter(_ role: OrbiterButtonRole = .secondary, size: OrbiterButtonSize = .regular) -> Self {
        OrbiterButtonStyle(role: role, size: size)
    }
}

extension ButtonStyle where Self == OrbiterIconButtonStyle {
    static func orbiterIcon(isSelected: Bool = false, size: CGFloat = 30) -> Self {
        OrbiterIconButtonStyle(isSelected: isSelected, size: size)
    }
}

struct OrbiterPanelModifier: ViewModifier {
    var padding: CGFloat
    var radius: CGFloat
    var surface: Color

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(OrbiterColor.border, lineWidth: OrbiterMetric.hairline)
            }
    }
}

struct OrbiterFieldChromeModifier: ViewModifier {
    var isInvalid: Bool

    func body(content: Content) -> some View {
        content
            .background(OrbiterColor.field, in: RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous)
                    .stroke(isInvalid ? OrbiterColor.danger.opacity(0.75) : OrbiterColor.border, lineWidth: OrbiterMetric.hairline)
            }
    }
}

extension View {
    func orbiterPanel(
        padding: CGFloat = 14,
        radius: CGFloat = OrbiterMetric.radius,
        surface: Color = OrbiterColor.panel
    ) -> some View {
        modifier(OrbiterPanelModifier(padding: padding, radius: radius, surface: surface))
    }

    func orbiterFieldChrome(isInvalid: Bool = false) -> some View {
        modifier(OrbiterFieldChromeModifier(isInvalid: isInvalid))
    }

    func orbiterInputChrome(isInvalid: Bool = false) -> some View {
        textFieldStyle(.plain)
            .font(.callout)
            .padding(.horizontal, 10)
            .frame(height: OrbiterMetric.controlHeight)
            .orbiterFieldChrome(isInvalid: isInvalid)
    }

    func orbiterPageBackground() -> some View {
        background(OrbiterColor.canvas.ignoresSafeArea())
    }
}

enum OrbiterBadgeTone {
    case neutral
    case accent
    case success
    case warning
    case danger

    var foreground: Color {
        switch self {
        case .neutral:
            OrbiterColor.textMuted
        case .accent:
            OrbiterColor.accent
        case .success:
            OrbiterColor.success
        case .warning:
            OrbiterColor.warning
        case .danger:
            OrbiterColor.danger
        }
    }

    var background: Color {
        switch self {
        case .neutral:
            OrbiterColor.panelPressed
        case .accent:
            OrbiterColor.accentSoft
        case .success:
            OrbiterColor.successSoft
        case .warning:
            OrbiterColor.warningSoft
        case .danger:
            OrbiterColor.dangerSoft
        }
    }
}

struct OrbiterBadge: View {
    var text: String
    var systemImage: String?
    var tone: OrbiterBadgeTone = .neutral

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.semibold))
            }
            Text(text)
                .lineLimit(1)
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(tone.foreground)
        .padding(.horizontal, 7)
        .frame(height: 22)
        .background(tone.background, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(tone.foreground.opacity(0.18), lineWidth: OrbiterMetric.hairline)
        }
    }
}

struct OrbiterSectionLabel: View {
    var title: String

    var body: some View {
        Text(LocalizedStringKey(title))
            .textCase(.uppercase)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(OrbiterColor.textSubtle)
            .padding(.horizontal, 8)
            .padding(.top, 2)
    }
}

struct OrbiterSidebarSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            OrbiterSectionLabel(title: title)
            VStack(spacing: 2) {
                content
            }
        }
    }
}

struct OrbiterSidebarRow<Accessory: View>: View {
    var title: String
    var subtitle: String?
    var systemImage: String
    var isSelected: Bool
    var isMuted = false
    var action: () -> Void
    @ViewBuilder var accessory: Accessory

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        isSelected: Bool,
        isMuted: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.isMuted = isMuted
        self.action = action
        self.accessory = accessory()
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? OrbiterColor.accent : OrbiterColor.textMuted)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 1) {
                    Text(LocalizedStringKey(title))
                        .font(.callout.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isMuted ? OrbiterColor.textSubtle : Color.primary)
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(OrbiterColor.textSubtle)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)
                accessory
            }
            .padding(.horizontal, 8)
            .frame(minHeight: subtitle == nil ? OrbiterMetric.sidebarRowHeight : 42)
            .background(rowBackground, in: RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous)
                    .stroke(isSelected ? OrbiterColor.accent.opacity(0.18) : .clear, lineWidth: OrbiterMetric.hairline)
            }
        }
        .buttonStyle(.plain)
        .disabled(isMuted)
    }

    private var rowBackground: Color {
        isSelected ? OrbiterColor.selected : .clear
    }
}

struct OrbiterDivider: View {
    var body: some View {
        Rectangle()
            .fill(OrbiterColor.border)
            .frame(height: OrbiterMetric.hairline)
    }
}

struct OrbiterEmptyStateView: View {
    var title: LocalizedStringKey
    var systemImage: String
    var message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(OrbiterColor.textSubtle)
                .frame(width: 56, height: 56)
                .background(OrbiterColor.panelPressed, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(OrbiterColor.border, lineWidth: OrbiterMetric.hairline)
                }

            VStack(spacing: 5) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(OrbiterColor.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .orbiterPageBackground()
    }
}

struct OrbiterSegmentedIconControl<Selection: Hashable>: View {
    struct Item: Identifiable {
        var id: Selection
        var systemImage: String
        var title: String
    }

    @Binding var selection: Selection
    var items: [Item]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items) { item in
                Button {
                    selection = item.id
                } label: {
                    Image(systemName: item.systemImage)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.orbiterIcon(isSelected: selection == item.id, size: 26))
                .help(item.title)
            }
        }
        .padding(2)
        .background(OrbiterColor.panel, in: RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous)
                .stroke(OrbiterColor.border, lineWidth: OrbiterMetric.hairline)
        }
    }
}

struct OrbiterSegmentedTextControl<Selection: Hashable>: View {
    struct Item: Identifiable {
        var id: Selection
        var title: LocalizedStringKey
    }

    @Binding var selection: Selection
    var items: [Item]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items) { item in
                Button {
                    selection = item.id
                } label: {
                    Text(item.title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(selection == item.id ? Color.primary : OrbiterColor.textMuted)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 8)
                        .frame(height: 26)
                        .background(selection == item.id ? OrbiterColor.panelRaised : .clear, in: RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: OrbiterMetric.radiusSmall, style: .continuous)
                                .stroke(selection == item.id ? OrbiterColor.border : .clear, lineWidth: OrbiterMetric.hairline)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(OrbiterColor.panelPressed, in: RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OrbiterMetric.radius, style: .continuous)
                .stroke(OrbiterColor.border, lineWidth: OrbiterMetric.hairline)
        }
    }
}

private extension NSColor {
    convenience init(hex: UInt32) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        self.init(srgbRed: red, green: green, blue: blue, alpha: 1)
    }
}
