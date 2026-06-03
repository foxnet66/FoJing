import SwiftUI

@main
struct FoJingApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            AppShellView(appModel: appModel)
        }
    }
}
