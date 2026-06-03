import SwiftUI

struct ProfileView: View {
    let appModel: AppModel

    var body: some View {
        List {
            Section {
                profileRow(title: "书签", detail: "\(appModel.bookmarkedScriptureIDs.count) 条", icon: "bookmark")
                profileRow(title: "回向记录", detail: "\(appModel.dedicationRecords.count) 条", icon: "clock.arrow.circlepath")
                profileRow(title: "日课设置", detail: "\(appModel.completedPracticeCount)/\(appModel.practiceItems.count) 项完成", icon: "calendar")
                profileRow(title: "阅读设置", detail: "\(Int(appModel.readerSettings.fontSize)) pt", icon: "textformat.size")
                profileRow(title: "文本来源", detail: "待接入可追溯版本", icon: "checkmark.seal")
                profileRow(title: "隐私说明", detail: "当前仅本机保存", icon: "hand.raised")
            }
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("佛经")
                        .font(.headline)
                    Text("清净阅读型 SwiftUI MVP 骨架")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .id(appModel.stateRevision)
        .scrollContentBackground(.hidden)
        .navigationTitle("我的")
        .sutraPageBackground()
    }

    private func profileRow(title: String, detail: String, icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .foregroundStyle(AppTheme.ink)
            Spacer()
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryInk)
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView(appModel: AppModel())
    }
}
