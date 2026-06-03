import SwiftUI

struct ChantPracticeView: View {
    @Bindable var appModel: AppModel
    @State private var woodFishEnabled = true
    @State private var bellEnabled = false

    private var counterPractice: PracticeItem {
        appModel.practiceItems.first { $0.kind == .counter } ??
            PracticeItem(id: "practice-amitabha", title: "阿弥陀佛", scriptureID: nil, current: 0, target: 108, unit: "声", kind: .counter)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PaperCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("今日诵持")
                            .font(.headline)
                        HStack {
                            Text(counterPractice.title)
                            Spacer()
                            Text("\(counterPractice.current) / \(counterPractice.target)")
                                .monospacedDigit()
                                .foregroundStyle(AppTheme.secondaryInk)
                        }
                    }
                }

                VStack(spacing: 18) {
                    Text("今日目标")
                        .font(.headline)
                    Text("\(counterPractice.target) \(counterPractice.unit)")
                        .foregroundStyle(AppTheme.secondaryInk)
                    Text("\(counterPractice.current)")
                        .font(.system(size: 76, weight: .light, design: .serif))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.bamboo)
                    Button {
                        appModel.incrementPractice(id: counterPractice.id)
                    } label: {
                        Text(counterPractice.isComplete ? "已完成" : "记一声")
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .foregroundStyle(.white)
                            .background(AppTheme.bamboo, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(counterPractice.isComplete)
                    .sensoryFeedback(.increase, trigger: counterPractice.current)
                }
                .frame(maxWidth: .infinity)
                .padding(22)
                .background(.white.opacity(0.42), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.paperDeep.opacity(0.7), lineWidth: 1)
                }

                PaperCard {
                    VStack(spacing: 14) {
                        Toggle(isOn: $woodFishEnabled) {
                            Label("木鱼", systemImage: "circle.hexagongrid")
                        }
                        Toggle(isOn: $bellEnabled) {
                            Label("引磬", systemImage: "bell")
                        }
                    }
                    .tint(AppTheme.bamboo)
                }

                NavigationLink {
                    DedicationView(appModel: appModel)
                } label: {
                    Label("进入回向", systemImage: "arrow.right.circle")
                        .font(.headline)
                        .foregroundStyle(appModel.firstIncompletePractice == nil ? AppTheme.bamboo : AppTheme.secondaryInk)
                }
                .disabled(appModel.firstIncompletePractice != nil)
            }
            .padding(20)
        }
        .navigationTitle("诵持")
        .sutraPageBackground()
    }
}

#Preview {
    NavigationStack {
        ChantPracticeView(appModel: AppModel())
    }
}
