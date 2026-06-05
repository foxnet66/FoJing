import SwiftUI
import UIKit

enum AppTheme {
    static let tabContentBottomPadding: CGFloat = 116

    static let paper = adaptiveColor(
        light: UIColor(red: 0.98, green: 0.96, blue: 0.91, alpha: 1),
        dark: UIColor(red: 0.08, green: 0.075, blue: 0.065, alpha: 1)
    )
    static let paperDeep = adaptiveColor(
        light: UIColor(red: 0.93, green: 0.89, blue: 0.80, alpha: 1),
        dark: UIColor(red: 0.23, green: 0.21, blue: 0.17, alpha: 1)
    )
    static let ink = adaptiveColor(
        light: UIColor(red: 0.13, green: 0.12, blue: 0.10, alpha: 1),
        dark: UIColor(red: 0.92, green: 0.88, blue: 0.78, alpha: 1)
    )
    static let secondaryInk = adaptiveColor(
        light: UIColor(red: 0.42, green: 0.38, blue: 0.31, alpha: 1),
        dark: UIColor(red: 0.68, green: 0.63, blue: 0.53, alpha: 1)
    )
    static let bamboo = adaptiveColor(
        light: UIColor(red: 0.25, green: 0.43, blue: 0.35, alpha: 1),
        dark: UIColor(red: 0.47, green: 0.70, blue: 0.58, alpha: 1)
    )
    static let cinnabar = adaptiveColor(
        light: UIColor(red: 0.62, green: 0.18, blue: 0.13, alpha: 1),
        dark: UIColor(red: 0.86, green: 0.43, blue: 0.35, alpha: 1)
    )
    static let gold = adaptiveColor(
        light: UIColor(red: 0.69, green: 0.54, blue: 0.26, alpha: 1),
        dark: UIColor(red: 0.78, green: 0.66, blue: 0.43, alpha: 1)
    )
    static let surface = adaptiveColor(
        light: UIColor(white: 1, alpha: 0.46),
        dark: UIColor(red: 0.13, green: 0.125, blue: 0.115, alpha: 0.96)
    )
    static let surfaceSubtle = adaptiveColor(
        light: UIColor(white: 1, alpha: 0.34),
        dark: UIColor(red: 0.18, green: 0.17, blue: 0.15, alpha: 0.88)
    )
    static let separator = adaptiveColor(
        light: UIColor(red: 0.86, green: 0.81, blue: 0.70, alpha: 0.7),
        dark: UIColor(white: 1, alpha: 0.14)
    )

    static let pageGradient = LinearGradient(
        colors: [
            paper,
            adaptiveColor(
                light: UIColor(red: 0.96, green: 0.93, blue: 0.86, alpha: 1),
                dark: UIColor(red: 0.105, green: 0.098, blue: 0.085, alpha: 1)
            )
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    private static func adaptiveColor(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

struct PaperCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.separator, lineWidth: 1)
            }
    }
}

struct PrimaryActionButton: View {
    @Environment(\.isEnabled) private var isEnabled

    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .foregroundStyle(isEnabled ? .white : AppTheme.secondaryInk)
                .background(isEnabled ? AppTheme.bamboo : AppTheme.paperDeep.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.78)
        .accessibilityLabel(title)
    }
}

struct PageBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(AppTheme.pageGradient.ignoresSafeArea())
            .foregroundStyle(AppTheme.ink)
            .toolbarBackground(AppTheme.paper, for: .navigationBar)
            .toolbarColorScheme(colorScheme, for: .navigationBar)
    }
}

extension View {
    func sutraPageBackground() -> some View {
        modifier(PageBackground())
    }
}
