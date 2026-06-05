import SwiftUI

enum AppTheme {
    static let paper = Color(red: 0.98, green: 0.96, blue: 0.91)
    static let paperDeep = Color(red: 0.93, green: 0.89, blue: 0.80)
    static let ink = Color(red: 0.13, green: 0.12, blue: 0.10)
    static let secondaryInk = Color(red: 0.42, green: 0.38, blue: 0.31)
    static let bamboo = Color(red: 0.25, green: 0.43, blue: 0.35)
    static let cinnabar = Color(red: 0.62, green: 0.18, blue: 0.13)
    static let gold = Color(red: 0.69, green: 0.54, blue: 0.26)

    static let pageGradient = LinearGradient(
        colors: [paper, Color(red: 0.96, green: 0.93, blue: 0.86)],
        startPoint: .top,
        endPoint: .bottom
    )
}

struct PaperCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(.white.opacity(0.42), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.paperDeep.opacity(0.7), lineWidth: 1)
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
    func body(content: Content) -> some View {
        content
            .background(AppTheme.pageGradient.ignoresSafeArea())
            .foregroundStyle(AppTheme.ink)
    }
}

extension View {
    func sutraPageBackground() -> some View {
        modifier(PageBackground())
    }
}
