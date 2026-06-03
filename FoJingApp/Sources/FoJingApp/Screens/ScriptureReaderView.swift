import SwiftUI

enum ReaderMode {
    case reading
    case chanting
}

struct ScriptureReaderView: View {
    @Bindable var appModel: AppModel
    let scripture: Scripture
    let mode: ReaderMode

    @State private var isPlaying = false
    @State private var showSettings = false
    @State private var activeParagraph = 0

    private var title: String {
        scripture.shortTitle
    }

    private var paragraphs: [String] {
        appModel.readerSettings.useTraditional ? scripture.traditionalParagraphs : scripture.simplifiedParagraphs
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, text in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(text)
                            .font(.system(size: appModel.readerSettings.fontSize, weight: .regular, design: .serif))
                            .lineSpacing(10)
                            .foregroundStyle(appModel.readerSettings.nightMode ? Color(red: 0.89, green: 0.84, blue: 0.74) : AppTheme.ink)
                            .padding(.vertical, 4)
                            .padding(.horizontal, isPlaying && index == activeParagraph ? 10 : 0)
                            .background(isPlaying && index == activeParagraph ? AppTheme.gold.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 6))
                            .onAppear {
                                activeParagraph = index
                                appModel.saveProgress(scripture: scripture, paragraphIndex: index)
                            }

                        ForEach(scripture.notes.filter { $0.paragraphIndex == index && appModel.readerSettings.showNotes }) { note in
                            Text("注：\(note.text)")
                                .font(.footnote)
                                .lineSpacing(4)
                                .foregroundStyle(appModel.readerSettings.nightMode ? Color(red: 0.64, green: 0.59, blue: 0.49) : AppTheme.secondaryInk)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 110)
        }
        .safeAreaInset(edge: .bottom) {
            miniPlayer
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "textformat.size")
                }
                Button {
                    appModel.toggleBookmark(scripture)
                } label: {
                    Image(systemName: appModel.isBookmarked(scripture) ? "bookmark.fill" : "bookmark")
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSettings) {
            ReaderSettingsSheet(
                fontSize: $appModel.readerSettings.fontSize,
                useTraditional: $appModel.readerSettings.useTraditional,
                showNotes: $appModel.readerSettings.showNotes,
                autoScroll: $appModel.readerSettings.autoScroll,
                nightMode: $appModel.readerSettings.nightMode
            )
            .presentationDetents([.medium])
        }
        .background {
            if appModel.readerSettings.nightMode {
                Color(red: 0.08, green: 0.075, blue: 0.065).ignoresSafeArea()
            } else {
                AppTheme.pageGradient.ignoresSafeArea()
            }
        }
        .foregroundStyle(appModel.readerSettings.nightMode ? Color(red: 0.89, green: 0.84, blue: 0.74) : AppTheme.ink)
    }

    private var miniPlayer: some View {
        HStack(spacing: 16) {
            Text(isPlaying ? "00:42" : "00:00")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(AppTheme.secondaryInk)
            Button {
                isPlaying.toggle()
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(AppTheme.bamboo)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(mode == .chanting ? "当前第 \(min(activeParagraph + 1, paragraphs.count)) / \(paragraphs.count) 句" : "第 \(min(activeParagraph + 1, paragraphs.count)) / \(paragraphs.count) 段")
                    .font(.subheadline.weight(.medium))
                Text(appModel.readerSettings.autoScroll ? "自动滚动开启" : "手动阅读")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryInk)
            }
            Spacer()
            Button {
                completeLinkedPractice()
            } label: {
                Label("完成", systemImage: "checkmark.circle")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.bamboo)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.thinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.paperDeep)
                .frame(height: 1)
        }
    }
}

struct ReaderSettingsSheet: View {
    @Binding var fontSize: Double
    @Binding var useTraditional: Bool
    @Binding var showNotes: Bool
    @Binding var autoScroll: Bool
    @Binding var nightMode: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("字号") {
                    Slider(value: $fontSize, in: 18...30, step: 1)
                    Text("当前 \(Int(fontSize)) pt")
                        .foregroundStyle(.secondary)
                }
                Section("字体") {
                    Picker("字体", selection: $useTraditional) {
                        Text("简体").tag(false)
                        Text("繁体").tag(true)
                    }
                    .pickerStyle(.segmented)
                }
                Section("显示") {
                    Toggle("注释", isOn: $showNotes)
                    Toggle("自动滚动", isOn: $autoScroll)
                    Toggle("夜间模式", isOn: $nightMode)
                }
            }
            .navigationTitle("阅读设置")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private extension ScriptureReaderView {
    func completeLinkedPractice() {
        guard let item = appModel.practiceItems.first(where: { $0.scriptureID == scripture.id && $0.kind == mode.practiceKind }) else { return }
        appModel.markPracticeComplete(id: item.id)
        isPlaying = false
    }
}

private extension ReaderMode {
    var practiceKind: PracticeKind {
        switch self {
        case .reading:
            .reading
        case .chanting:
            .chanting
        }
    }
}

#Preview {
    NavigationStack {
        ScriptureReaderView(appModel: AppModel(), scripture: ScriptureCatalog.scriptures[0], mode: .reading)
    }
}
