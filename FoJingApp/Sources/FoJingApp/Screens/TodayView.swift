import SwiftUI

struct TodayView: View {
    let appModel: AppModel

    private var completedCount: Int {
        appModel.completedPracticeCount
    }

    private var completionFraction: Double {
        appModel.completionFraction
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                practiceCard
                startAction
                dailyVerse
                recentReading
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
        .navigationTitle("今日")
        .sutraPageBackground()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(Date.now, format: .dateTime.year().month().day().weekday())
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryInk)
                    Text(appModel.firstIncompletePractice == nil ? "今日功课已圆满" : "愿以清净心")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text(headerSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryInk)
                }
                Spacer()
                VStack(spacing: 4) {
                    Text("晚")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.cinnabar)
                    Text("课")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.cinnabar)
                }
                .frame(width: 48, height: 64)
                .background(AppTheme.paperDeep.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.gold.opacity(0.45), lineWidth: 1)
                }
            }

            HStack(spacing: 12) {
                Label("今日无特别斋日", systemImage: "calendar")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.bamboo)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.42), in: Capsule())

                Spacer()

                Text("\(completedCount)/\(appModel.practiceItems.count) 项")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryInk)
            }
        }
    }

    private var practiceCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("今日功课")
                        .font(.headline)
                    Spacer()
                    Text(appModel.firstIncompletePractice == nil ? "已完成" : "进行中")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(appModel.firstIncompletePractice == nil ? AppTheme.bamboo : AppTheme.secondaryInk)
                }

                ProgressView(value: completionFraction)
                    .tint(AppTheme.bamboo)
                    .scaleEffect(y: 0.7, anchor: .center)

                ForEach(appModel.practiceItems) { item in
                    practiceRow(item)
                }
            }
        }
    }

    private func practiceRow(_ item: PracticeItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(item.isComplete ? AppTheme.bamboo : AppTheme.secondaryInk.opacity(0.72))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.body.weight(.medium))
                Text(item.isComplete ? "今日已完成" : rowHint(for: item))
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryInk)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                Text("\(item.current)/\(item.target)")
                    .font(.body.monospacedDigit().weight(.medium))
                    .foregroundStyle(AppTheme.ink)
                Text(item.unit)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryInk)
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private var startAction: some View {
        if let practice = appModel.firstIncompletePractice {
            if practice.kind == .counter {
                NavigationLink {
                    ChantPracticeView(appModel: appModel)
                } label: {
                    primaryActionLabel("开始今日功课", systemImage: "play.fill")
                }
                .buttonStyle(.plain)
            } else if let scripture = appModel.scripture(for: practice) {
                NavigationLink {
                    ScriptureReaderView(
                        appModel: appModel,
                        scripture: scripture,
                        mode: practice.kind == .chanting ? .chanting : .reading,
                        practiceID: practice.id
                    )
                } label: {
                    primaryActionLabel("开始今日功课", systemImage: "play.fill")
                }
                .buttonStyle(.plain)
            }
        } else {
            if appModel.hasSavedDedicationToday {
                primaryActionLabel("今日记录已保存", systemImage: "checkmark.seal.fill")
                    .opacity(0.78)
            } else {
                NavigationLink {
                    DedicationView(appModel: appModel)
                } label: {
                    primaryActionLabel("进入回向", systemImage: "arrow.right.circle")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func primaryActionLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(.white)
            .background(AppTheme.bamboo, in: RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel(title)
    }

    private func rowHint(for item: PracticeItem) -> String {
        switch item.kind {
        case .reading:
            "诵读一遍"
        case .chanting:
            "逐句诵持"
        case .counter:
            "念佛计数"
        }
    }

    private var headerSubtitle: String {
        if appModel.firstIncompletePractice != nil {
            return "安住当下，完成今日功课。"
        }
        if appModel.hasSavedDedicationToday {
            return "回向已保存，可在我的页面查看记录。"
        }
        return "可以进入回向，保存今日记录。"
    }

    private var recentReading: some View {
        PaperCard {
            NavigationLink {
                ScriptureReaderView(appModel: appModel, scripture: appModel.recentScripture, mode: .reading, practiceID: nil)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "book.pages")
                        .font(.title3)
                        .foregroundStyle(AppTheme.gold)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("最近阅读")
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                        Text(appModel.recentScripture.title)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryInk)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryInk)
                }
            }
        }
    }

    private var dailyVerse: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日一句")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                Rectangle()
                    .fill(AppTheme.gold.opacity(0.55))
                    .frame(width: 34, height: 2)
                Text("照见五蕴皆空")
                    .font(.system(size: 25, weight: .regular, design: .serif))
                    .foregroundStyle(AppTheme.bamboo)
                    .lineSpacing(8)
                Text("出自《般若波罗蜜多心经》")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryInk)
            }
            .padding(.top, 2)
        }
        .padding(.top, 2)
    }
}

#Preview {
    NavigationStack {
        TodayView(appModel: AppModel())
    }
}
