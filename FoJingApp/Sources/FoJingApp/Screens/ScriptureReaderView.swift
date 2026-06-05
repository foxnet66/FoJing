import Foundation
import SwiftUI

enum ReaderMode {
    case reading
    case chanting
}

struct ScriptureReaderView: View {
    @Bindable var appModel: AppModel
    let scripture: Scripture
    let mode: ReaderMode
    let practiceID: String?

    @State private var isPlaying = false
    @State private var showSettings = false
    @State private var activeParagraph = 0
    @State private var didTapComplete = false
    @State private var playbackSeconds = 0.0
    @State private var loopCurrentParagraph = false
    @State private var didRestoreProgress = false
    @State private var canTrackVisibleProgress = false
    @State private var scrollToTopTrigger = 0
    @State private var visibleParagraph: Int?

    private let playbackTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var title: String {
        scripture.shortTitle
    }

    private var paragraphs: [String] {
        appModel.readerSettings.useTraditional ? scripture.traditionalParagraphs : scripture.simplifiedParagraphs
    }

    var body: some View {
        ZStack {
            readerBackground.ignoresSafeArea()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, text in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(text)
                                    .font(.system(size: appModel.readerSettings.fontSize, weight: .regular, design: .serif))
                                    .lineSpacing(10)
                                    .foregroundStyle(primaryReaderText)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, isPlaying && index == activeParagraph ? 10 : 0)
                                    .background(isPlaying && index == activeParagraph ? AppTheme.gold.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 6))

                                if appModel.readerSettings.showPinyin {
                                    Text(pinyinText(for: text, at: index))
                                        .font(.system(size: max(13, appModel.readerSettings.fontSize * 0.55), weight: .regular, design: .rounded))
                                        .lineSpacing(5)
                                        .foregroundStyle(secondaryReaderText)
                                        .textSelection(.enabled)
                                }

                                ForEach(scripture.notes.filter { $0.paragraphIndex == index && appModel.readerSettings.showNotes }) { note in
                                    Text("注：\(note.text)")
                                        .font(.footnote)
                                        .lineSpacing(4)
                                        .foregroundStyle(secondaryReaderText)
                                }
                            }
                            .id(index)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, appModel.readerSettings.showPinyin ? 96 : 72)
                }
                .scrollPosition(id: $visibleParagraph, anchor: .top)
                .onChange(of: activeParagraph) { _, newValue in
                    guard isPlaying, appModel.readerSettings.autoScroll else { return }
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
                .onChange(of: scrollToTopTrigger) { _, _ in
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(0, anchor: .top)
                    }
                }
                .onChange(of: visibleParagraph) { _, newValue in
                    saveVisibleReadingProgress(newValue)
                }
                .onAppear {
                    restoreReadingProgress(with: proxy)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            miniPlayer
        }
        .toolbar(.hidden, for: .tabBar)
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
                fontSize: readerSettingBinding(\.fontSize),
                useTraditional: readerSettingBinding(\.useTraditional),
                showNotes: readerSettingBinding(\.showNotes),
                autoScroll: readerSettingBinding(\.autoScroll),
                nightMode: readerSettingBinding(\.nightMode),
                showPinyin: readerSettingBinding(\.showPinyin)
            )
            .presentationDetents([.medium])
        }
        .toolbarBackground(appModel.readerSettings.nightMode ? Color(red: 0.08, green: 0.075, blue: 0.065) : AppTheme.paper, for: .navigationBar)
        .toolbarColorScheme(appModel.readerSettings.nightMode ? .dark : .light, for: .navigationBar)
        .foregroundStyle(primaryReaderText)
        .onReceive(playbackTimer) { _ in
            advancePlaybackIfNeeded()
        }
    }

    private var readerBackground: some View {
        Group {
            if appModel.readerSettings.nightMode {
                Color(red: 0.08, green: 0.075, blue: 0.065)
            } else {
                AppTheme.pageGradient
            }
        }
    }

    private var primaryReaderText: Color {
        appModel.readerSettings.nightMode ? Color(red: 0.89, green: 0.84, blue: 0.74) : AppTheme.ink
    }

    private var secondaryReaderText: Color {
        appModel.readerSettings.nightMode ? Color(red: 0.64, green: 0.59, blue: 0.49) : AppTheme.secondaryInk
    }

    private var miniPlayer: some View {
        HStack(spacing: 12) {
            Text(formatPlaybackTime(playbackSeconds))
                .font(.caption.monospacedDigit())
                .foregroundStyle(AppTheme.secondaryInk)
                .frame(width: 44, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Button {
                togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(AppTheme.bamboo)
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(positionText)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(playerStatusText)
                    .font(.caption)
                    .foregroundStyle(secondaryReaderText)
                    .lineLimit(1)
            }
            .layoutPriority(1)
            Spacer()
            Button {
                returnToBeginning()
            } label: {
                Image(systemName: "arrow.up.to.line.circle")
                    .font(.title3)
                    .foregroundStyle(secondaryReaderText)
            }
            .accessibilityLabel("回到开头")
            Button {
                loopCurrentParagraph.toggle()
                playbackSeconds = paragraphStartSeconds(activeParagraph)
            } label: {
                Image(systemName: loopCurrentParagraph ? "repeat.1.circle.fill" : "repeat.1.circle")
                    .font(.title3)
                    .foregroundStyle(loopCurrentParagraph ? AppTheme.bamboo : secondaryReaderText)
            }
            .accessibilityLabel(loopCurrentParagraph ? "关闭单句循环" : "开启单句循环")
            if linkedPractice != nil {
                Button {
                    completeLinkedPractice()
                } label: {
                    Image(systemName: isLinkedPracticeComplete ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.title3)
                        .foregroundStyle(isLinkedPracticeComplete ? AppTheme.secondaryInk : AppTheme.bamboo)
                }
                .disabled(isLinkedPracticeComplete)
                .accessibilityLabel(isLinkedPracticeComplete ? "已完成" : "完成")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(appModel.readerSettings.nightMode ? .regularMaterial : .thinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(appModel.readerSettings.nightMode ? Color.white.opacity(0.12) : AppTheme.paperDeep)
                .frame(height: 1)
        }
        .sensoryFeedback(.success, trigger: didTapComplete)
    }
}

struct ReaderSettingsSheet: View {
    @Binding var fontSize: Double
    @Binding var useTraditional: Bool
    @Binding var showNotes: Bool
    @Binding var autoScroll: Bool
    @Binding var nightMode: Bool
    @Binding var showPinyin: Bool

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
                    Toggle("拼音", isOn: $showPinyin)
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
    var playbackDuration: Double {
        max(Double(scripture.durationMinutes * 60), Double(max(paragraphs.count, 1)) * 4)
    }

    var secondsPerParagraph: Double {
        playbackDuration / Double(max(paragraphs.count, 1))
    }

    var positionText: String {
        let label = mode == .chanting ? "句" : "段"
        return "第 \(min(activeParagraph + 1, paragraphs.count))/\(paragraphs.count) \(label)"
    }

    var playerStatusText: String {
        if loopCurrentParagraph {
            return "单句循环"
        }
        return appModel.readerSettings.autoScroll ? "自动滚动开启" : "手动阅读"
    }

    var isLinkedPracticeComplete: Bool {
        guard let item = linkedPractice else { return false }
        return item.isComplete
    }

    var linkedPractice: PracticeItem? {
        guard let practiceID else { return nil }
        return appModel.practiceItems.first { $0.id == practiceID }
    }

    func readerSettingBinding<Value>(_ keyPath: WritableKeyPath<ReaderSettings, Value>) -> Binding<Value> {
        Binding {
            appModel.readerSettings[keyPath: keyPath]
        } set: { newValue in
            var settings = appModel.readerSettings
            settings[keyPath: keyPath] = newValue
            appModel.updateReaderSettings(settings)
        }
    }

    func completeLinkedPractice() {
        guard let item = linkedPractice, !item.isComplete else { return }
        appModel.markPracticeComplete(id: item.id)
        appModel.resetProgress(scripture: scripture)
        activeParagraph = 0
        playbackSeconds = 0
        didTapComplete.toggle()
        isPlaying = false
    }

    func returnToBeginning() {
        isPlaying = false
        activeParagraph = 0
        playbackSeconds = 0
        visibleParagraph = 0
        appModel.resetProgress(scripture: scripture)
        scrollToTopTrigger += 1
    }

    func restoreReadingProgress(with proxy: ScrollViewProxy) {
        guard !didRestoreProgress else { return }
        didRestoreProgress = true
        canTrackVisibleProgress = false
        guard !paragraphs.isEmpty else { return }
        let savedIndex = appModel.readingProgress[scripture.id] ?? 0
        let index = min(max(savedIndex, 0), paragraphs.count - 1)
        activeParagraph = index
        visibleParagraph = index
        playbackSeconds = paragraphStartSeconds(index)
        DispatchQueue.main.async {
            if index > 0 {
                proxy.scrollTo(index, anchor: .top)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                canTrackVisibleProgress = true
            }
        }
    }

    func saveVisibleReadingProgress(_ paragraphIndex: Int?) {
        guard canTrackVisibleProgress, !isPlaying else { return }
        guard let paragraphIndex else { return }
        let index = min(max(paragraphIndex, 0), max(paragraphs.count - 1, 0))
        activeParagraph = index
        if loopCurrentParagraph {
            playbackSeconds = paragraphStartSeconds(index)
        }
        appModel.saveProgress(scripture: scripture, paragraphIndex: index)
    }

    func togglePlayback() {
        if playbackSeconds >= playbackDuration {
            playbackSeconds = 0
            activeParagraph = 0
        }
        isPlaying.toggle()
    }

    func advancePlaybackIfNeeded() {
        guard isPlaying else { return }
        let nextSecond = min(playbackSeconds + 1, playbackDuration)
        if loopCurrentParagraph, nextSecond >= paragraphEndSeconds(activeParagraph) {
            playbackSeconds = paragraphStartSeconds(activeParagraph)
            return
        }

        playbackSeconds = nextSecond
        activeParagraph = paragraphIndex(at: nextSecond)
        if nextSecond >= playbackDuration {
            isPlaying = false
        }
    }

    func paragraphIndex(at seconds: Double) -> Int {
        guard !paragraphs.isEmpty else { return 0 }
        let index = Int(seconds / secondsPerParagraph)
        return min(max(index, 0), paragraphs.count - 1)
    }

    func paragraphStartSeconds(_ index: Int) -> Double {
        Double(min(max(index, 0), max(paragraphs.count - 1, 0))) * secondsPerParagraph
    }

    func paragraphEndSeconds(_ index: Int) -> Double {
        min(paragraphStartSeconds(index) + secondsPerParagraph, playbackDuration)
    }

    func formatPlaybackTime(_ seconds: Double) -> String {
        let totalSeconds = max(Int(seconds.rounded()), 0)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func pinyinText(for text: String, at paragraphIndex: Int) -> String {
        if let pinyinParagraphs = scripture.pinyinParagraphs,
           pinyinParagraphs.indices.contains(paragraphIndex) {
            let pinyin = pinyinParagraphs[paragraphIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            if !pinyin.isEmpty {
                return pinyin
            }
        }

        var output = ""
        var index = text.startIndex

        while index < text.endIndex {
            if let override = buddhistPinyinOverrides.first(where: { text[index...].hasPrefix($0.text) }) {
                appendPinyinToken(override.pinyin, to: &output)
                text.formIndex(&index, offsetBy: override.text.count)
                continue
            }

            let character = String(text[index])
            if character.rangeOfCharacter(from: .letters) != nil {
                appendPinyinToken(transformedPinyin(for: character), to: &output)
            } else if character.rangeOfCharacter(from: .punctuationCharacters) != nil {
                appendPunctuation(character, to: &output)
            } else if character.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
                appendSpace(to: &output)
            } else {
                appendPinyinToken(character, to: &output)
            }
            text.formIndex(after: &index)
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func transformedPinyin(for text: String) -> String {
        let mutable = NSMutableString(string: text)
        CFStringTransform(mutable as CFMutableString, nil, kCFStringTransformToLatin, false)
        return (mutable as String)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func appendPinyinToken(_ token: String, to output: inout String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !output.isEmpty, !output.hasSuffix(" ") {
            output += " "
        }
        output += trimmed
    }

    func appendPunctuation(_ punctuation: String, to output: inout String) {
        output = output.trimmingCharacters(in: .whitespaces)
        output += punctuation
        output += " "
    }

    func appendSpace(to output: inout String) {
        if !output.isEmpty, !output.hasSuffix(" ") {
            output += " "
        }
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

private let buddhistPinyinOverrides: [(text: String, pinyin: String)] = [
    ("南無", "na mo"),
    ("南无", "na mo"),
    ("般若", "bo re"),
    ("阿彌陀", "a mi tuo"),
    ("阿弥陀", "a mi tuo"),
    ("伽梵達摩", "qie fan da mo"),
    ("伽梵达摩", "qie fan da mo"),
    ("菩提薩埵", "pu ti sa duo"),
    ("菩提萨埵", "pu ti sa duo"),
    ("罣礙", "gua ai"),
    ("挂碍", "gua ai")
]

#Preview {
    NavigationStack {
        ScriptureReaderView(appModel: AppModel(), scripture: ScriptureCatalog.scriptures[0], mode: .reading, practiceID: nil)
    }
}
