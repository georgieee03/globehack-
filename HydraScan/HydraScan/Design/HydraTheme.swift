import SwiftUI
import UIKit

enum HydraSurfaceRole {
    case shell
    case elevated
    case panel
    case ivory
    case overlay
}

enum HydraButtonKind {
    case primary
    case secondary
    case ghost
    case destructive
}

enum HydraTheme {
    enum Colors {
        static let shellTop = Color(hex: 0x0A1015)
        static let shellBottom = Color(hex: 0x111824)
        static let shell = Color(hex: 0x0D131B)
        static let navyGlow = Color(hex: 0x1B2D53)
        static let emberGlow = Color(hex: 0x3D1B1C)
        static let surface = Color(hex: 0x161F29)
        static let surfaceRaised = Color(hex: 0x1B2632)
        static let panel = Color(hex: 0x202A36)
        static let overlay = Color.black.opacity(0.66)
        static let ivory = Color(hex: 0xF1E8DD)
        static let ivoryBorder = Color(hex: 0xDDC7A8)
        static let gold = Color(hex: 0xD0A773)
        static let goldSoft = Color(hex: 0xE3C095)
        static let goldDeep = Color(hex: 0xB68856)
        static let goldOutline = Color(hex: 0x7C6244)
        static let stroke = Color.white.opacity(0.08)
        static let primaryText = Color(hex: 0xF7F2EA)
        static let secondaryText = Color(hex: 0xC5BBB0)
        static let mutedText = Color(hex: 0x938A86)
        static let ink = Color(hex: 0x1B1512)
        static let inkSecondary = Color(hex: 0x5F564E)
        static let success = Color(hex: 0x78BF9A)
        static let warning = Color(hex: 0xD7A86C)
        static let error = Color(hex: 0xD88585)
        static let chart = Color(hex: 0xCFA66E)
        static let chartFill = Color(hex: 0xD8B88E).opacity(0.18)
    }

    enum Spacing {
        static let page: CGFloat = 24
        static let section: CGFloat = 24
        static let block: CGFloat = 18
        static let compact: CGFloat = 12
        static let capsuleHorizontal: CGFloat = 16
        static let capsuleVertical: CGFloat = 8
    }

    enum Radius {
        static let card: CGFloat = 28
        static let field: CGFloat = 22
        static let button: CGFloat = 20
        static let pill: CGFloat = 999
        static let media: CGFloat = 30
        static let tabBar: CGFloat = 28
    }

    enum Motion {
        static let standard = Animation.easeInOut(duration: 0.28)
        static let hero = Animation.easeInOut(duration: 0.42)
    }

    static func fill(for role: HydraSurfaceRole) -> AnyShapeStyle {
        switch role {
        case .shell:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Colors.shellTop, Colors.shellBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .elevated:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Colors.surfaceRaised, Colors.surface],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .panel:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Colors.panel, Colors.surface],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .ivory:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Colors.ivory, Color(hex: 0xEAE0D4)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .overlay:
            return AnyShapeStyle(Colors.overlay)
        }
    }

    static func stroke(for role: HydraSurfaceRole) -> Color {
        switch role {
        case .ivory:
            return Colors.ivoryBorder.opacity(0.55)
        case .overlay:
            return Colors.gold.opacity(0.18)
        case .shell, .elevated, .panel:
            return Colors.stroke
        }
    }
}

enum HydraTypography {
    private static let displayCandidates = [
        "Canela-Regular",
        "Baskerville",
        "IowanOldStyle-Roman",
    ]
    private static let serifCandidates = [
        "Canela-Medium",
        "Baskerville-SemiBold",
        "TimesNewRomanPSMT",
    ]
    private static let sansCandidates = [
        "AvenirNext-Regular",
        "Avenir Next",
    ]
    private static let sansMediumCandidates = [
        "AvenirNext-Medium",
        "Avenir Next Demi Bold",
    ]
    private static let sansBoldCandidates = [
        "AvenirNext-DemiBold",
        "Avenir Next Bold",
    ]
    private static let monoCandidates = [
        "Menlo-Regular",
        "Courier",
    ]
    private static var didRegister = false

    static func registerBrandFonts() {
        guard !didRegister else { return }
        didRegister = true

        let bundledFonts = [
            "Canela-Regular.otf",
            "Canela-Medium.otf",
            "SuisseIntl-Regular.otf",
            "SuisseIntl-Medium.otf",
        ]

        for fileName in bundledFonts {
            guard
                let url = Bundle.main.url(forResource: fileName, withExtension: nil),
                let provider = CGDataProvider(url: url as CFURL),
                let font = CGFont(provider)
            else {
                continue
            }

            CTFontManagerRegisterGraphicsFont(font, nil)
        }
    }

    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        resolvedFont(candidates: displayCandidates, size: size, fallback: .system(size: size, weight: weight, design: .serif))
    }

    static func section(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        resolvedFont(candidates: serifCandidates, size: size, fallback: .system(size: size, weight: weight, design: .serif))
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        resolvedFont(candidates: sansCandidates, size: size, fallback: .system(size: size, weight: weight, design: .rounded))
    }

    static func ui(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        let candidates: [String]
        switch weight {
        case .bold, .semibold, .heavy, .black:
            candidates = sansBoldCandidates
        case .medium:
            candidates = sansMediumCandidates
        default:
            candidates = sansCandidates
        }

        return resolvedFont(candidates: candidates, size: size, fallback: .system(size: size, weight: weight, design: .rounded))
    }

    static func numeric(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded).monospacedDigit()
    }

    static func capsule(_ size: CGFloat = 12) -> Font {
        ui(size, weight: .semibold)
    }

    static func wordmark(_ size: CGFloat) -> Font {
        resolvedFont(candidates: sansBoldCandidates, size: size, fallback: .system(size: size, weight: .bold, design: .rounded))
    }

    static func mono(_ size: CGFloat) -> Font {
        resolvedFont(candidates: monoCandidates, size: size, fallback: .system(size: size, design: .monospaced))
    }

    private static func resolvedFont(candidates: [String], size: CGFloat, fallback: Font) -> Font {
        registerBrandFonts()
        for name in candidates where UIFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        }
        return fallback
    }
}

enum HydraAppearance {
    static func install() {
        HydraTypography.registerBrandFonts()

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(HydraTheme.Colors.shell)
        navAppearance.shadowColor = .clear
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(HydraTheme.Colors.primaryText),
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(HydraTheme.Colors.primaryText),
        ]

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(HydraTheme.Colors.gold)

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(HydraTheme.Colors.surface)
        tabAppearance.shadowColor = .clear

        let normalColor = UIColor(HydraTheme.Colors.mutedText)
        let selectedColor = UIColor(HydraTheme.Colors.gold)
        for layout in [
            tabAppearance.stackedLayoutAppearance,
            tabAppearance.inlineLayoutAppearance,
            tabAppearance.compactInlineLayoutAppearance,
        ] {
            layout.normal.iconColor = normalColor
            layout.normal.titleTextAttributes = [.foregroundColor: normalColor]
            layout.selected.iconColor = selectedColor
            layout.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        }

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().tintColor = selectedColor
        UITabBar.appearance().unselectedItemTintColor = normalColor

        UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(HydraTheme.Colors.gold)
        UISegmentedControl.appearance().backgroundColor = UIColor(HydraTheme.Colors.surfaceRaised)
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: UIColor(HydraTheme.Colors.ink)],
            for: .selected
        )
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: UIColor(HydraTheme.Colors.primaryText)],
            for: .normal
        )

        UISlider.appearance().minimumTrackTintColor = UIColor(HydraTheme.Colors.gold)
        UISlider.appearance().maximumTrackTintColor = UIColor(HydraTheme.Colors.stroke)
        UIProgressView.appearance().progressTintColor = UIColor(HydraTheme.Colors.gold)
        UIProgressView.appearance().trackTintColor = UIColor(HydraTheme.Colors.stroke)
    }
}

extension Color {
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
