import SwiftUI

enum AppTab: Hashable {
    case today
    case library
    case chant
    case profile
}

struct AppShellView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

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
        .toolbarBackground(AppTheme.paper, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(colorScheme, for: .tabBar)
        .task {
            await syncReminderSettings()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                appModel.refreshDailyPracticeIfNeeded()
                Task {
                    await syncReminderSettings()
                }
            }
        }
    }

    private func syncReminderSettings() async {
        let settings = appModel.dailyPracticeReminderSettings
        let didSync = await DailyPracticeReminderScheduler.sync(settings: settings)

        guard !didSync, settings.isEnabled else { return }
        await MainActor.run {
            var disabledSettings = appModel.dailyPracticeReminderSettings
            disabledSettings.isEnabled = false
            appModel.updateDailyPracticeReminderSettings(disabledSettings)
        }
    }
}

#Preview {
    AppShellView(appModel: AppModel())
}
