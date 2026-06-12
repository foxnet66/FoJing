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
                profileRow(title: "文本来源", detail: scriptureSourceStatusText, icon: "checkmark.seal")
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
            if !appModel.dailyPracticeRecords.isEmpty {
                Section("日课记录") {
                    profileRow(title: "本月完成", detail: "\(monthlyPracticeCompletionCount) 天", icon: "calendar")
                        .profileListRowStyle()
                    profileRow(title: "最近连续", detail: "\(recentConsecutivePracticeDays) 天", icon: "leaf")
                        .profileListRowStyle()
                    NavigationLink {
                        DailyPracticeHistoryView(appModel: appModel)
                    } label: {
                        Label("查看全部日课", systemImage: "list.bullet.rectangle")
                            .foregroundStyle(AppTheme.ink)
                    }
                    .profileListRowStyle()
                }
                Section("最近日课") {
                    ForEach(appModel.dailyPracticeRecords.prefix(5)) { record in
                        NavigationLink {
                            DailyPracticeRecordDetailView(appModel: appModel, record: record)
                        } label: {
                            dailyPracticeRecordRow(record)
                        }
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
            Section("支持") {
                Link(destination: feedbackMailURL) {
                    HStack {
                        Label("反馈与支持", systemImage: "questionmark.bubble")
                            .foregroundStyle(AppTheme.ink)
                        Spacer()
                        Text("邮件")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryInk)
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryInk)
                    }
                }
                .profileListRowStyle()
            }
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("净诵")
                        .font(.headline)
                    Text("版本 \(appVersionText) · 开发者 James Wang")
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

    private var feedbackMailURL: URL {
        let subject = "净诵反馈"
        let body = """
        App 版本：\(appVersionText)
        iOS 版本：\(UIDevice.current.systemVersion)
        设备：\(UIDevice.current.model)
        问题页面：
        问题描述：
        复现步骤：
        """
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "foxnet2000@gmail.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url ?? URL(string: "mailto:foxnet2000@gmail.com")!
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

    private func dailyPracticeRecordRow(_ record: DailyPracticeRecord) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text("日课已完成")
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Text(record.completedAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryInk)
            }
            Text(record.completedItems.joined(separator: "、"))
                .font(.caption)
                .foregroundStyle(AppTheme.bamboo)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        guard let build, !build.isEmpty, build != version else {
            return version
        }
        return "\(version) (\(build))"
    }

    private var scriptureSourceStatusText: String {
        let availableCount = appModel.scriptures.filter { !$0.isPrototypeContent }.count
        let pendingCount = appModel.scriptures.count - availableCount

        if pendingCount == 0 {
            return "\(availableCount) 部正式"
        }

        return "\(availableCount) 部正式，\(pendingCount) 部待接入"
    }

    private var monthlyPracticeCompletionCount: Int {
        let calendar = Calendar.current
        let now = Date()
        return Set(appModel.dailyPracticeRecords.compactMap { record -> Date? in
            guard calendar.isDate(record.date, equalTo: now, toGranularity: .month) else {
                return nil
            }
            return calendar.startOfDay(for: record.date)
        }).count
    }

    private var recentConsecutivePracticeDays: Int {
        let calendar = Calendar.current
        let completedDays = Set(appModel.dailyPracticeRecords.map { calendar.startOfDay(for: $0.date) })
        guard var currentDay = completedDays.max() else {
            return 0
        }

        var count = 0
        while completedDays.contains(currentDay) {
            count += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDay) else {
                break
            }
            currentDay = previousDay
        }
        return count
    }
}

struct DailyPracticeHistoryView: View {
    let appModel: AppModel

    private var records: [DailyPracticeRecord] {
        appModel.dailyPracticeRecords.sorted { $0.date > $1.date }
    }

    private var monthlyPracticeCompletionCount: Int {
        let calendar = Calendar.current
        let now = Date()
        return Set(records.compactMap { record -> Date? in
            guard calendar.isDate(record.date, equalTo: now, toGranularity: .month) else {
                return nil
            }
            return calendar.startOfDay(for: record.date)
        }).count
    }

    private var recentConsecutivePracticeDays: Int {
        let calendar = Calendar.current
        let completedDays = Set(records.map { calendar.startOfDay(for: $0.date) })
        guard var currentDay = completedDays.max() else {
            return 0
        }

        var count = 0
        while completedDays.contains(currentDay) {
            count += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDay) else {
                break
            }
            currentDay = previousDay
        }
        return count
    }

    var body: some View {
        List {
            Section("愿力相续") {
                historySummaryRow(title: "本月完成", value: "\(monthlyPracticeCompletionCount) 天", icon: "calendar")
                historySummaryRow(title: "最近连续", value: "\(recentConsecutivePracticeDays) 天", icon: "leaf")
            }

            Section("全部日课") {
                ForEach(records) { record in
                    NavigationLink {
                        DailyPracticeRecordDetailView(appModel: appModel, record: record)
                    } label: {
                        dailyPracticeRecordRow(record)
                    }
                    .profileListRowStyle()
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("日课记录")
        .navigationBarTitleDisplayMode(.inline)
        .sutraPageBackground()
    }

    private func historySummaryRow(title: String, value: String, icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .foregroundStyle(AppTheme.ink)
            Spacer()
            Text(value)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(AppTheme.secondaryInk)
        }
        .profileListRowStyle()
    }

    private func dailyPracticeRecordRow(_ record: DailyPracticeRecord) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(record.date, format: .dateTime.year().month().day().weekday())
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Text(record.completedAt, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryInk)
            }
            Text(record.completedItems.joined(separator: "、"))
                .font(.caption)
                .foregroundStyle(AppTheme.bamboo)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

struct DailyPracticeRecordDetailView: View {
    let appModel: AppModel
    let record: DailyPracticeRecord

    private var matchingDedications: [DedicationRecord] {
        appModel.dedicationRecords.filter { Calendar.current.isDate($0.date, inSameDayAs: record.date) }
    }

    var body: some View {
        List {
            Section("完成时间") {
                detailRow(title: "日期", value: record.date.formatted(.dateTime.year().month().day().weekday()))
                detailRow(title: "时间", value: record.completedAt.formatted(.dateTime.hour().minute()))
            }

            Section("完成项目") {
                ForEach(record.completedItems, id: \.self) { item in
                    Label(item, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.ink)
                        .profileListRowStyle()
                }
            }

            Section("当日回向") {
                if matchingDedications.isEmpty {
                    Text("当日未保存回向")
                        .foregroundStyle(AppTheme.secondaryInk)
                        .profileListRowStyle()
                } else {
                    ForEach(matchingDedications) { dedication in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(dedication.recipient)
                                .font(.body.weight(.medium))
                                .foregroundStyle(AppTheme.ink)
                            Text(dedication.text)
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryInk)
                                .lineLimit(4)
                        }
                        .padding(.vertical, 4)
                        .profileListRowStyle()
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("日课详情")
        .navigationBarTitleDisplayMode(.inline)
        .sutraPageBackground()
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(AppTheme.ink)
            Spacer()
            Text(value)
                .foregroundStyle(AppTheme.secondaryInk)
        }
        .profileListRowStyle()
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
