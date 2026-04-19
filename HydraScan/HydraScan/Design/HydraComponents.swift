import SwiftUI

struct HydraShellBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [HydraTheme.Colors.shellTop, HydraTheme.Colors.shellBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(HydraTheme.Colors.navyGlow.opacity(0.38))
                .frame(width: 420, height: 420)
                .blur(radius: 80)
                .offset(x: 130, y: -240)

            Circle()
                .fill(HydraTheme.Colors.emberGlow.opacity(0.28))
                .frame(width: 360, height: 360)
                .blur(radius: 90)
                .offset(x: -150, y: 240)
        }
        .ignoresSafeArea()
    }
}

struct HydraBrandWordmark: View {
    var size: CGFloat = 30
    var reversed = false

    private var textColor: Color {
        reversed ? HydraTheme.Colors.ink : HydraTheme.Colors.primaryText
    }

    var body: some View {
        Group {
            if let image = UIImage(named: reversed ? "HydraWordmarkReversed" : "HydraWordmark") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: size)
            } else {
                HStack(spacing: size * 0.06) {
                    Text("HYDRASCA")
                        .font(HydraTypography.wordmark(size * 0.88))
                        .tracking(size * 0.08)
                        .foregroundStyle(textColor)
                        .lineLimit(1)

                    HydraBrandEmblem(size: size, reversed: reversed)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("HydraScan")
    }
}

struct HydraBrandEmblem: View {
    var size: CGFloat = 28
    var reversed = false

    var body: some View {
        Group {
            if let image = UIImage(named: reversed ? "HydraEmblemReversed" : "HydraEmblem") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                ZStack {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [HydraTheme.Colors.goldSoft, HydraTheme.Colors.goldDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: max(2, size * 0.1)
                        )
                        .background(
                            Circle()
                                .fill(reversed ? HydraTheme.Colors.ivory.opacity(0.95) : HydraTheme.Colors.surfaceRaised)
                        )

                    Text("N")
                        .font(HydraTypography.wordmark(size * 0.62))
                        .foregroundStyle(
                            reversed
                                ? HydraTheme.Colors.goldDeep
                                : HydraTheme.Colors.goldSoft
                        )
                }
            }
        }
        .frame(width: size, height: size)
    }
}

struct HydraEyebrow: View {
    let text: String
    var icon: String?

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(HydraTypography.ui(11, weight: .semibold))
            }

            Text(text.uppercased())
                .lineLimit(1)
        }
        .font(HydraTypography.capsule())
        .tracking(0.6)
        .foregroundStyle(HydraTheme.Colors.goldSoft)
        .padding(.horizontal, HydraTheme.Spacing.capsuleHorizontal)
        .padding(.vertical, HydraTheme.Spacing.capsuleVertical)
        .background(
            Capsule(style: .continuous)
                .fill(HydraTheme.Colors.surfaceRaised.opacity(0.92))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(HydraTheme.Colors.stroke, lineWidth: 1)
                )
        )
    }
}

struct HydraSectionHeader: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?

    init(eyebrow: String? = nil, title: String, subtitle: String? = nil) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let eyebrow {
                HydraEyebrow(text: eyebrow)
            }

            Text(title)
                .font(HydraTypography.display(44))
                .foregroundStyle(HydraTheme.Colors.primaryText)

            if let subtitle {
                Text(subtitle)
                    .font(HydraTypography.body(17))
                    .foregroundStyle(HydraTheme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HydraPageHeader: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?
    var showsWordmark = true

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if showsWordmark {
                HydraBrandWordmark(size: 30)
            }

            HydraSectionHeader(eyebrow: eyebrow, title: title, subtitle: subtitle)
        }
    }
}

struct HydraBrandStage: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?
    var showsProgress = false
    var role: HydraSurfaceRole = .elevated

    var body: some View {
        HydraCard(role: role, padding: 24) {
            VStack(alignment: .leading, spacing: 18) {
                HydraBrandWordmark(size: 34, reversed: role == .ivory)

                if let eyebrow {
                    HydraEyebrow(text: eyebrow)
                }

                Text(title)
                    .font(HydraTypography.display(38))
                    .foregroundStyle(role == .ivory ? HydraTheme.Colors.ink : HydraTheme.Colors.primaryText)

                if let subtitle {
                    Text(subtitle)
                        .font(HydraTypography.body(16))
                        .foregroundStyle(role == .ivory ? HydraTheme.Colors.inkSecondary : HydraTheme.Colors.secondaryText)
                }

                if showsProgress {
                    HStack(spacing: 14) {
                        ProgressView()
                            .tint(HydraTheme.Colors.gold)

                        Text("Preparing your premium recovery workspace…")
                            .font(HydraTypography.body(15, weight: .medium))
                            .foregroundStyle(role == .ivory ? HydraTheme.Colors.inkSecondary : HydraTheme.Colors.primaryText)
                    }
                    .padding(.top, 4)
                }
            }
        }
    }
}

struct HydraCard<Content: View>: View {
    let role: HydraSurfaceRole
    var padding: CGFloat = 20
    @ViewBuilder let content: Content

    init(role: HydraSurfaceRole = .elevated, padding: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.role = role
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: HydraTheme.Radius.card, style: .continuous)
                .fill(HydraTheme.fill(for: role))
                .overlay(
                    RoundedRectangle(cornerRadius: HydraTheme.Radius.card, style: .continuous)
                        .stroke(HydraTheme.stroke(for: role), lineWidth: 1)
                )
        )
        .shadow(
            color: role == .ivory ? Color.black.opacity(0.05) : Color.black.opacity(0.18),
            radius: role == .ivory ? 16 : 24,
            x: 0,
            y: 10
        )
    }
}

struct HydraInputShell<Content: View>: View {
    let role: HydraSurfaceRole
    @ViewBuilder let content: Content

    init(role: HydraSurfaceRole = .panel, @ViewBuilder content: () -> Content) {
        self.role = role
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: HydraTheme.Radius.field, style: .continuous)
                    .fill(HydraTheme.fill(for: role))
                    .overlay(
                        RoundedRectangle(cornerRadius: HydraTheme.Radius.field, style: .continuous)
                            .stroke(HydraTheme.stroke(for: role), lineWidth: 1)
                    )
            )
    }
}

struct HydraMetricRow: View {
    let label: String
    let value: String
    var accent: Color = HydraTheme.Colors.primaryText
    var labelWidth: CGFloat? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(HydraTypography.ui(14, weight: .medium))
                .foregroundStyle(HydraTheme.Colors.secondaryText)
                .frame(width: labelWidth, alignment: .leading)

            Text(value)
                .font(HydraTypography.ui(15, weight: .semibold))
                .foregroundStyle(accent)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

enum HydraBannerTone {
    case neutral
    case success
    case warning
    case error

    var tint: Color {
        switch self {
        case .neutral:
            return HydraTheme.Colors.goldSoft
        case .success:
            return HydraTheme.Colors.success
        case .warning:
            return HydraTheme.Colors.warning
        case .error:
            return HydraTheme.Colors.error
        }
    }
}

struct HydraStatusBanner: View {
    let message: String
    let tone: HydraBannerTone
    var icon: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .font(HydraTypography.ui(14, weight: .semibold))
                    .padding(.top, 2)
            }

            Text(message)
                .font(HydraTypography.body(14, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(tone.tint)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(tone.tint.opacity(0.11))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(tone.tint.opacity(0.28), lineWidth: 1)
                )
        )
    }
}

struct HydraButtonStyle: ButtonStyle {
    let kind: HydraButtonKind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HydraTypography.ui(16, weight: .semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(minHeight: 54)
            .background(background(configuration: configuration))
            .opacity(configuration.isPressed ? 0.92 : 1)
            .scaleEffect(configuration.isPressed ? 0.995 : 1)
            .animation(HydraTheme.Motion.standard, value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        switch kind {
        case .primary:
            return HydraTheme.Colors.ink
        case .secondary, .ghost:
            return HydraTheme.Colors.primaryText
        case .destructive:
            return HydraTheme.Colors.error
        }
    }

    @ViewBuilder
    private func background(configuration: Configuration) -> some View {
        RoundedRectangle(cornerRadius: HydraTheme.Radius.button, style: .continuous)
            .fill(backgroundFill(isPressed: configuration.isPressed))
            .overlay(
                RoundedRectangle(cornerRadius: HydraTheme.Radius.button, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
    }

    private func backgroundFill(isPressed: Bool) -> AnyShapeStyle {
        switch kind {
        case .primary:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        HydraTheme.Colors.goldSoft.opacity(isPressed ? 0.88 : 1),
                        HydraTheme.Colors.gold.opacity(isPressed ? 0.88 : 1),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .secondary:
            return AnyShapeStyle(HydraTheme.Colors.surfaceRaised.opacity(isPressed ? 0.86 : 0.96))
        case .ghost:
            return AnyShapeStyle(Color.clear)
        case .destructive:
            return AnyShapeStyle(HydraTheme.Colors.error.opacity(isPressed ? 0.15 : 0.08))
        }
    }

    private var borderColor: Color {
        switch kind {
        case .primary:
            return HydraTheme.Colors.goldOutline.opacity(0.55)
        case .secondary:
            return HydraTheme.Colors.stroke
        case .ghost:
            return HydraTheme.Colors.stroke.opacity(0.6)
        case .destructive:
            return HydraTheme.Colors.error.opacity(0.35)
        }
    }
}

struct HydraChipStyle: ButtonStyle {
    let selected: Bool
    var emphasized = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HydraTypography.ui(14, weight: .medium))
            .foregroundStyle(textColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(fill(configuration: configuration))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(strokeColor, lineWidth: 1)
                    )
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
    }

    private var textColor: Color {
        selected ? HydraTheme.Colors.ink : HydraTheme.Colors.primaryText
    }

    private func fill(configuration: Configuration) -> AnyShapeStyle {
        if selected {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [HydraTheme.Colors.goldSoft, HydraTheme.Colors.gold],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        return AnyShapeStyle(
            emphasized
                ? HydraTheme.Colors.gold.opacity(configuration.isPressed ? 0.18 : 0.12)
                : HydraTheme.Colors.surfaceRaised.opacity(configuration.isPressed ? 0.88 : 1)
        )
    }

    private var strokeColor: Color {
        selected ? HydraTheme.Colors.goldOutline.opacity(0.55) : (emphasized ? HydraTheme.Colors.goldOutline.opacity(0.45) : HydraTheme.Colors.stroke)
    }
}

struct HydraTelemetryBadge: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(HydraTypography.capsule(11))
                .tracking(0.6)
                .foregroundStyle(HydraTheme.Colors.secondaryText)

            Text(value)
                .font(HydraTypography.ui(15, weight: .semibold))
                .foregroundStyle(HydraTheme.Colors.primaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(HydraTheme.Colors.overlay)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(HydraTheme.Colors.gold.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

extension View {
    func hydraShell() -> some View {
        modifier(HydraShellModifier())
    }
}

private struct HydraShellModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            HydraShellBackground()
            content
        }
        .toolbarBackground(HydraTheme.Colors.shell, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
    }
}
