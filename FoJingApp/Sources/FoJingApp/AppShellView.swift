import SwiftUI

enum AppTab: Hashable {
    case today
    case library
    case chant
    case profile
}

struct AppShellView: View {
    let appModel: AppModel
    @State private var selectedTab: AppTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TodayView(appModel: appModel)
            }
            .tabItem {
                Label("今日", systemImage: "checkmark.circle")
            }
            .tag(AppTab.today)

            NavigationStack {
                ScriptureLibraryView(appModel: appModel)
            }
            .tabItem {
                Label("经藏", systemImage: "text.book.closed")
            }
            .tag(AppTab.library)

            NavigationStack {
                ChantPracticeView(appModel: appModel)
            }
            .tabItem {
                Label("诵持", systemImage: "speaker.wave.2")
            }
            .tag(AppTab.chant)

            NavigationStack {
                ProfileView(appModel: appModel)
            }
            .tabItem {
                Label("我的", systemImage: "person.circle")
            }
            .tag(AppTab.profile)
        }
        .tint(AppTheme.bamboo)
    }
}

#Preview {
    AppShellView(appModel: AppModel())
}
