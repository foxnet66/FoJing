import SwiftUI

struct DedicationView: View {
    let appModel: AppModel

    @State private var selectedRecipient = "法界众生"
    @State private var customRecipient = ""
    @State private var dedicationText = "愿以此功德，庄严佛净土\n上报四重恩，下济三途苦\n若有见闻者，悉发菩提心\n尽此一报身，同生极乐国"
    @State private var didSave = false

    private let recipients = ["法界众生", "家人", "自定义"]

    private var hasSavedToday: Bool {
        didSave || appModel.hasSavedDedicationToday
    }

    private var effectiveRecipient: String {
        let trimmedCustomRecipient = customRecipient.trimmingCharacters(in: .whitespacesAndNewlines)
        return selectedRecipient == "自定义" ? trimmedCustomRecipient : selectedRecipient
    }

    private var canSave: Bool {
        !hasSavedToday && !effectiveRecipient.isEmpty
    }

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
                        .foregroundStyle(AppTheme.ink)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 150)
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppTheme.separator, lineWidth: 1)
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
                                    .foregroundStyle(selectedRecipient == recipient ? Color.white : AppTheme.bamboo)
                                    .background(selectedRecipient == recipient ? AppTheme.bamboo : AppTheme.surfaceSubtle, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if selectedRecipient == "自定义" {
                        TextField("输入回向对象", text: $customRecipient)
                            .textInputAutocapitalization(.never)
                            .padding(13)
                            .foregroundStyle(AppTheme.ink)
                            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(AppTheme.separator, lineWidth: 1)
                            }
                    }
                }

                PrimaryActionButton(title: hasSavedToday ? "已保存" : "完成并保存", systemImage: "checkmark.circle.fill") {
                    appModel.saveDedication(recipient: effectiveRecipient, text: dedicationText)
                    didSave = true
                }
                .disabled(!canSave)
            }
            .padding(20)
            .padding(.bottom, AppTheme.tabContentBottomPadding)
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
