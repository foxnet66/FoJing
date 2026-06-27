import Foundation
@preconcurrency import AVFoundation
import SwiftUI

enum ReaderMode {
    case reading
    case chanting
}

private final class ScriptureSpeechController: NSObject, @unchecked Sendable, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var paragraphs: [String] = []
    private var language = "zh-Hans"
    private var loopCurrentParagraph = false
    private var isStopping = false
    private var utteranceIndexes: [ObjectIdentifier: Int] = [:]

    var onParagraphChange: ((Int) -> Void)?
    var onFinished: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(paragraphs: [String], from index: Int, language: String, loopCurrentParagraph: Bool) {
        stop()
        guard !paragraphs.isEmpty else { return }

        configureAudioSession()
        self.paragraphs = paragraphs
        self.language = language
        self.loopCurrentParagraph = loopCurrentParagraph
        isStopping = false
        enqueueSpeech(from: min(max(index, 0), paragraphs.count - 1))
    }

    func stop() {
        isStopping = true
        synthesizer.stopSpeaking(at: .immediate)
        utteranceIndexes.removeAll()
    }

    private func enqueueSpeech(from index: Int) {
        let safeIndex = min(max(index, 0), paragraphs.count - 1)
        let indexes = loopCurrentParagraph ? [safeIndex] : Array(safeIndex..<paragraphs.count)

        for paragraphIndex in indexes {
            let text = paragraphs[paragraphIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: language)
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.82
            utterance.pitchMultiplier = 0.95
            utterance.preUtteranceDelay = 0.08
            utterance.postUtteranceDelay = 0.18
            utteranceIndexes[ObjectIdentifier(utterance)] = paragraphIndex
            synthesizer.speak(utterance)
        }
    }

    private func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        guard let index = utteranceIndexes[ObjectIdentifier(utterance)] else { return }
        DispatchQueue.main.async {
            self.onParagraphChange?(index)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard !isStopping, let index = utteranceIndexes[ObjectIdentifier(utterance)] else { return }
        utteranceIndexes.removeValue(forKey: ObjectIdentifier(utterance))

        if loopCurrentParagraph {
            enqueueSpeech(from: index)
        } else if index >= paragraphs.count - 1 {
            DispatchQueue.main.async {
                self.onFinished?()
            }
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        utteranceIndexes.removeValue(forKey: ObjectIdentifier(utterance))
    }
}

struct ScriptureReaderView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
    @State private var scrollToTopTrigger = 0
    @State private var pendingPracticeCompletion: PracticeItem?
    @State private var showsPracticeCompletionConfirmation = false
    @State private var speechController = ScriptureSpeechController()

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
                                    .padding(.horizontal, 10)
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
                .onChange(of: activeParagraph) { _, newValue in
                    guard isPlaying, appModel.readerSettings.autoScroll else { return }
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(newValue, anchor: .top)
                    }
                }
                .onChange(of: scrollToTopTrigger) { _, _ in
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(0, anchor: .top)
                    }
                }
                .onAppear {
                    configureSpeechCallbacks()
                    restoreReadingProgress(with: proxy)
                    appModel.saveProgress(scripture: scripture, paragraphIndex: activeParagraph)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            miniPlayer
        }
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(primaryReaderText)
            }
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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSettings) {
            ReaderSettingsSheet(
                fontSize: readerSettingBinding(\.fontSize),
                useTraditional: readerSettingBinding(\.useTraditional),
                showNotes: readerSettingBinding(\.showNotes),
                autoScroll: readerSettingBinding(\.autoScroll),
                appearance: readerSettingBinding(\.appearance),
                showPinyin: readerSettingBinding(\.showPinyin)
            )
            .presentationDetents([.medium])
        }
        .confirmationDialog(
            practiceCompletionDialogTitle,
            isPresented: $showsPracticeCompletionConfirmation,
            titleVisibility: .visible
        ) {
            Button(practiceCompletionConfirmTitle) {
                completeLinkedPractice()
            }
            Button("取消", role: .cancel) {
                pendingPracticeCompletion = nil
            }
        } message: {
            Text(practiceCompletionDialogMessage)
        }
        .toolbarBackground(readerChromeBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(usesDarkReaderChrome ? .dark : .light, for: .navigationBar)
        .tint(primaryReaderText)
        .foregroundStyle(primaryReaderText)
        .onReceive(playbackTimer) { _ in
            advancePlaybackIfNeeded()
        }
        .onDisappear {
            speechController.stop()
        }
    }

    private var readerBackground: some View {
        Group {
            if usesDarkReaderChrome {
                Color(red: 0.08, green: 0.075, blue: 0.065)
            } else {
                AppTheme.pageGradient
            }
        }
    }

    private var usesDarkReaderChrome: Bool {
        switch appModel.readerSettings.appearance {
        case .system:
            colorScheme == .dark
        case .light:
            false
        case .dark:
            true
        }
    }

    private var readerChromeBackground: Color {
        usesDarkReaderChrome ? Color(red: 0.08, green: 0.075, blue: 0.065) : AppTheme.paper
    }

    private var primaryReaderText: Color {
        usesDarkReaderChrome ? Color(red: 0.89, green: 0.84, blue: 0.74) : AppTheme.ink
    }

    private var secondaryReaderText: Color {
        usesDarkReaderChrome ? Color(red: 0.64, green: 0.59, blue: 0.49) : AppTheme.secondaryInk
    }

    private var miniPlayerBackground: Color {
        usesDarkReaderChrome ? Color(red: 0.16, green: 0.155, blue: 0.13) : AppTheme.paper
    }

    private var miniPlayerDivider: Color {
        usesDarkReaderChrome ? Color.white.opacity(0.12) : AppTheme.paperDeep
    }

    private var miniPlayer: some View {
        HStack(spacing: usesCompactMiniPlayer ? 10 : 12) {
            Text(formatPlaybackTime(playbackSeconds))
                .font(.caption.monospacedDigit())
                .foregroundStyle(secondaryReaderText)
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
            if usesCompactMiniPlayer {
                Text(compactPositionText)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .foregroundStyle(primaryReaderText)
                    .layoutPriority(1)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(positionText)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(playerStatusText)
                        .font(.caption)
                        .foregroundStyle(secondaryReaderText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .layoutPriority(1)
            }
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
                if isPlaying {
                    startReadingAloud()
                }
            } label: {
                Image(systemName: loopCurrentParagraph ? "repeat.1.circle.fill" : "repeat.1.circle")
                    .font(.title3)
                    .foregroundStyle(loopCurrentParagraph ? AppTheme.bamboo : secondaryReaderText)
            }
            .accessibilityLabel(loopCurrentParagraph ? "关闭单句循环" : "开启单句循环")
            if linkedPractice != nil {
                Button {
                    requestLinkedPracticeCompletion()
                } label: {
                    Image(systemName: isLinkedPracticeComplete ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.title3)
                        .foregroundStyle(isLinkedPracticeComplete ? secondaryReaderText : AppTheme.bamboo)
                }
                .disabled(isLinkedPracticeComplete)
                .accessibilityLabel(linkedPracticeCompletionLabel)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(miniPlayerBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(miniPlayerDivider)
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
    @Binding var appearance: ReaderAppearance
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
                }
                Section("外观") {
                    Picker("阅读外观", selection: $appearance) {
                        Text("跟随系统").tag(ReaderAppearance.system)
                        Text("日间").tag(ReaderAppearance.light)
                        Text("夜间").tag(ReaderAppearance.dark)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("阅读设置")
            .navigationBarTitleDisplayMode(.inline)
        }
        .foregroundStyle(.primary)
        .tint(AppTheme.bamboo)
        .preferredColorScheme(preferredColorScheme)
    }

    private var preferredColorScheme: ColorScheme? {
        switch appearance {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
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

    var usesCompactMiniPlayer: Bool {
        dynamicTypeSize >= .xxLarge
    }

    var positionText: String {
        let label = mode == .chanting ? "句" : "段"
        return "第 \(min(activeParagraph + 1, paragraphs.count))/\(paragraphs.count) \(label)"
    }

    var compactPositionText: String {
        let label = mode == .chanting ? "句" : "段"
        return "\(min(activeParagraph + 1, paragraphs.count))/\(paragraphs.count)\(label)"
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

    var practiceCompletionDialogTitle: String {
        guard let item = pendingPracticeCompletion else { return "确认完成？" }
        return "确认完成第 \(item.current + 1) \(item.unit)？"
    }

    var practiceCompletionConfirmTitle: String {
        guard let item = pendingPracticeCompletion else { return "完成" }
        return "完成第 \(item.current + 1) \(item.unit)"
    }

    var practiceCompletionDialogMessage: String {
        guard let item = pendingPracticeCompletion else { return "" }
        let nextCount = min(item.current + 1, item.target)
        if nextCount >= item.target {
            return "将记录为 \(nextCount)/\(item.target) \(item.unit)，并标记今日\(item.title)已完成。"
        }
        return "将记录为 \(nextCount)/\(item.target) \(item.unit)，并回到开头继续下一遍。"
    }

    var linkedPracticeCompletionLabel: String {
        guard let item = linkedPractice else { return "完成" }
        if item.isComplete {
            return "已完成"
        }
        if item.target > 1 {
            return "完成第 \(item.current + 1) \(item.unit)"
        }
        return "完成"
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
        showsPracticeCompletionConfirmation = false
        pendingPracticeCompletion = nil
        speechController.stop()
        appModel.incrementPractice(id: item.id)
        appModel.resetProgress(scripture: scripture)
        activeParagraph = 0
        playbackSeconds = 0
        didTapComplete.toggle()
        isPlaying = false
    }

    func requestLinkedPracticeCompletion() {
        guard let item = linkedPractice, !item.isComplete else { return }
        if item.target > 1 {
            pendingPracticeCompletion = item
            showsPracticeCompletionConfirmation = true
        } else {
            completeLinkedPractice()
        }
    }

    func returnToBeginning() {
        speechController.stop()
        isPlaying = false
        activeParagraph = 0
        playbackSeconds = 0
        appModel.resetProgress(scripture: scripture)
        scrollToTopTrigger += 1
    }

    func restoreReadingProgress(with proxy: ScrollViewProxy) {
        guard !didRestoreProgress else { return }
        didRestoreProgress = true
        guard !paragraphs.isEmpty else { return }
        let savedIndex = appModel.readingProgress[scripture.id] ?? 0
        let index = min(max(savedIndex, 0), paragraphs.count - 1)
        activeParagraph = index
        playbackSeconds = paragraphStartSeconds(index)
        DispatchQueue.main.async {
            if index > 0 {
                proxy.scrollTo(index, anchor: .top)
            }
        }
    }

    func togglePlayback() {
        if isPlaying {
            speechController.stop()
            isPlaying = false
        } else {
            if playbackSeconds >= playbackDuration {
                playbackSeconds = 0
                activeParagraph = 0
            }
            startReadingAloud()
        }
    }

    func advancePlaybackIfNeeded() {
        guard isPlaying else { return }
        let nextSecond = min(playbackSeconds + 1, playbackDuration)
        if loopCurrentParagraph, nextSecond >= paragraphEndSeconds(activeParagraph) {
            playbackSeconds = paragraphStartSeconds(activeParagraph)
            return
        }

        playbackSeconds = nextSecond
    }

    func startReadingAloud() {
        let language = appModel.readerSettings.useTraditional ? "zh-Hant" : "zh-Hans"
        speechController.speak(
            paragraphs: paragraphs,
            from: activeParagraph,
            language: language,
            loopCurrentParagraph: loopCurrentParagraph
        )
        isPlaying = true
    }

    func configureSpeechCallbacks() {
        speechController.onParagraphChange = { index in
            activeParagraph = index
            playbackSeconds = paragraphStartSeconds(index)
            appModel.saveProgress(scripture: scripture, paragraphIndex: index)
        }
        speechController.onFinished = {
            playbackSeconds = playbackDuration
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
