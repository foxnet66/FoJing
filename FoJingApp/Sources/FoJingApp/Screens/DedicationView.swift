import SwiftUI

struct DedicationView: View {
    let appModel: AppModel

    @State private var selectedRecipient = "法界众生"
    @State private var dedicationText = "愿以此功德，庄严佛净土\n上报四重恩，下济三途苦\n若有见闻者，悉发菩提心\n尽此一报身，同生极乐国"
    @State private var didSave = false

    private let recipients = ["法界众生", "家人", "自定义"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PaperCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("今日已完成")
                            .font(.headline)
                        Text(completedSummary)
                            .lineSpacing(6)
                            .foregroundStyle(AppTheme.secondaryInk)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("回向文")
                        .font(.headline)
                    TextEditor(text: $dedicationText)
                        .font(.title3)
                        .lineSpacing(9)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 150)
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.42), in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppTheme.paperDeep.opacity(0.7), lineWidth: 1)
                        }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("回向对象")
                        .font(.headline)
                    HStack {
                        ForEach(recipients, id: \.self) { recipient in
                            Button {
                                selectedRecipient = recipient
                            } label: {
                                Text(recipient)
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .foregroundStyle(selectedRecipient == recipient ? .white : AppTheme.bamboo)
                                    .background(selectedRecipient == recipient ? AppTheme.bamboo : .white.opacity(0.34), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                PrimaryActionButton(title: didSave ? "已保存" : "完成并保存", systemImage: "checkmark.circle.fill") {
                    appModel.saveDedication(recipient: selectedRecipient, text: dedicationText)
                    didSave = true
                }
                .disabled(didSave)
            }
            .padding(20)
        }
        .navigationTitle("回向")
        .navigationBarTitleDisplayMode(.inline)
        .sutraPageBackground()
    }

    private var completedSummary: String {
        let completedItems = appModel.practiceItems.filter(\.isComplete)
        guard !completedItems.isEmpty else { return "今日尚未完成日课" }
        return completedItems
            .map { "\($0.title) \($0.current) \($0.unit)" }
            .joined(separator: "\n")
    }
}

#Preview {
    NavigationStack {
        DedicationView(appModel: AppModel())
    }
}
