import SwiftUI

struct ProfileView: View {
    let appModel: AppModel

    @State private var showsResetPracticeConfirmation = false

    var body: some View {
        List {
            Section {
                profileRow(title: "书签", detail: "\(appModel.bookmarkedScriptureIDs.count) 条", icon: "bookmark")
                    .profileListRowStyle()
                profileRow(title: "回向记录", detail: "\(appModel.dedicationRecords.count) 条", icon: "clock.arrow.circlepath")
                    .profileListRowStyle()
                profileRow(title: "日课设置", detail: "\(appModel.completedPracticeCount)/\(appModel.practiceItems.count) 项完成", icon: "calendar")
                    .profileListRowStyle()
                profileRow(title: "阅读设置", detail: "\(Int(appModel.readerSettings.fontSize)) pt", icon: "textformat.size")
                    .profileListRowStyle()
                profileRow(title: "文本来源", detail: "待接入可追溯版本", icon: "checkmark.seal")
                    .profileListRowStyle()
                profileRow(title: "隐私说明", detail: "当前仅本机保存", icon: "hand.raised")
                    .profileListRowStyle()
            }
            if !appModel.dedicationRecords.isEmpty {
                Section("最近回向") {
                    ForEach(appModel.dedicationRecords.prefix(5)) { record in
                        dedicationRecordRow(record)
                            .profileListRowStyle()
                    }
                }
            }
            Section("操作") {
                Button(role: .destructive) {
                    showsResetPracticeConfirmation = true
                } label: {
                    Label("重置今日功课", systemImage: "arrow.counterclockwise")
                }
                .profileListRowStyle()
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
                .profileListRowStyle()
            }
        }
        .id(appModel.stateRevision)
        .scrollContentBackground(.hidden)
        .navigationTitle("我的")
        .sutraPageBackground()
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: AppTheme.tabContentBottomPadding)
        }
        .confirmationDialog("重置今日功课？", isPresented: $showsResetPracticeConfirmation, titleVisibility: .visible) {
            Button("重置今日功课", role: .destructive) {
                appModel.resetTodayPractice()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("仅重置今日功课进度，不会删除书签或回向记录。")
        }
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

    private func dedicationRecordRow(_ record: DedicationRecord) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(record.recipient)
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Text(record.date, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryInk)
            }
            if !record.completedItems.isEmpty {
                Text(record.completedItems.joined(separator: "、"))
                    .font(.caption)
                    .foregroundStyle(AppTheme.bamboo)
                    .lineLimit(2)
            }
            Text(record.text)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryInk)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

private extension View {
    func profileListRowStyle() -> some View {
        self
            .listRowBackground(AppTheme.surface)
            .listRowSeparatorTint(AppTheme.separator)
    }
}

#Preview {
    NavigationStack {
        ProfileView(appModel: AppModel())
    }
}
