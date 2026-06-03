import Foundation
import Observation

struct PracticeItem: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let scriptureID: String?
    var current: Int
    let target: Int
    let unit: String
    let kind: PracticeKind

    var isComplete: Bool {
        current >= target
    }
}

enum PracticeKind: String, Hashable, Codable {
    case reading
    case chanting
    case counter
}

struct Scripture: Identifiable, Hashable {
    let id: String
    let title: String
    let shortTitle: String
    let translator: String
    let dynasty: String
    let category: String
    let durationMinutes: Int
    let source: String
    let hasModernPunctuation: Bool
    let hasAudio: Bool
    let hasNotes: Bool
    let chapters: [ScriptureChapter]
    let simplifiedParagraphs: [String]
    let traditionalParagraphs: [String]
    let notes: [ScriptureNote]

    var subtitle: String {
        "\(dynasty) · \(translator)译"
    }

    var duration: String {
        "约 \(durationMinutes) 分钟"
    }
}

struct ScriptureChapter: Identifiable, Hashable {
    let id: String
    let title: String
    let paragraphStart: Int
}

struct ScriptureNote: Identifiable, Hashable {
    let id: String
    let paragraphIndex: Int
    let text: String
}

struct ReaderSettings: Hashable, Codable {
    var fontSize = 22.0
    var useTraditional = false
    var showNotes = true
    var autoScroll = true
    var nightMode = false
}

struct DedicationRecord: Identifiable, Hashable, Codable {
    let id: UUID
    let date: Date
    let recipient: String
    let text: String
    let completedItems: [String]
}

@Observable
final class AppModel {
    var scriptures = ScriptureCatalog.scriptures
    var practiceItems: [PracticeItem] = []
    var readerSettings = ReaderSettings() {
        didSet { save() }
    }
    var bookmarkedScriptureIDs: Set<String> = []
    var readingProgress: [String: Int] = [:]
    var dedicationRecords: [DedicationRecord] = []
    var stateRevision = 0

    private let persistenceKey = "FoJing.AppModel.State.v1"

    init() {
        load()
        if practiceItems.isEmpty {
            practiceItems = ScriptureCatalog.defaultPractices
        }
    }

    var completedPracticeCount: Int {
        practiceItems.filter(\.isComplete).count
    }

    var completionFraction: Double {
        guard !practiceItems.isEmpty else { return 0 }
        return Double(completedPracticeCount) / Double(practiceItems.count)
    }

    var firstIncompletePractice: PracticeItem? {
        practiceItems.first { !$0.isComplete }
    }

    var hasSavedDedicationToday: Bool {
        dedicationRecords.contains { Calendar.current.isDateInToday($0.date) }
    }

    var recentScripture: Scripture {
        scripture(id: readingProgress.keys.first ?? "heart-sutra") ?? scriptures[0]
    }

    func scripture(id: String?) -> Scripture? {
        guard let id else { return nil }
        return scriptures.first { $0.id == id }
    }

    func scripture(for practice: PracticeItem) -> Scripture? {
        scripture(id: practice.scriptureID)
    }

    func isBookmarked(_ scripture: Scripture) -> Bool {
        bookmarkedScriptureIDs.contains(scripture.id)
    }

    func toggleBookmark(_ scripture: Scripture) {
        var bookmarks = bookmarkedScriptureIDs
        if isBookmarked(scripture) {
            bookmarks.remove(scripture.id)
        } else {
            bookmarks.insert(scripture.id)
        }
        bookmarkedScriptureIDs = bookmarks
        save()
    }

    func markPracticeComplete(id: String) {
        var items = practiceItems
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].current = items[index].target
        practiceItems = items
        save()
    }

    func incrementPractice(id: String) {
        var items = practiceItems
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].current = min(items[index].current + 1, items[index].target)
        practiceItems = items
        save()
    }

    func saveProgress(scripture: Scripture, paragraphIndex: Int) {
        var progress = readingProgress
        progress[scripture.id] = paragraphIndex
        readingProgress = progress
        save()
    }

    func updateReaderSettings(_ settings: ReaderSettings) {
        readerSettings = settings
    }

    func saveDedication(recipient: String, text: String) {
        let completed = practiceItems
            .filter(\.isComplete)
            .map { "\($0.title) \($0.target) \($0.unit)" }
        let record = DedicationRecord(
                id: UUID(),
                date: Date(),
                recipient: recipient,
                text: text,
                completedItems: completed
        )
        dedicationRecords = [record] + dedicationRecords
        save()
    }

    func resetTodayPractice() {
        practiceItems = ScriptureCatalog.defaultPractices
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else { return }
        do {
            let state = try JSONDecoder().decode(PersistedState.self, from: data)
            practiceItems = state.practiceItems
            readerSettings = state.readerSettings
            bookmarkedScriptureIDs = Set(state.bookmarkedScriptureIDs)
            readingProgress = state.readingProgress
            dedicationRecords = state.dedicationRecords
        } catch {
            practiceItems = ScriptureCatalog.defaultPractices
        }
    }

    private func save() {
        stateRevision += 1
        let state = PersistedState(
            practiceItems: practiceItems,
            readerSettings: readerSettings,
            bookmarkedScriptureIDs: Array(bookmarkedScriptureIDs),
            readingProgress: readingProgress,
            dedicationRecords: dedicationRecords
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: persistenceKey)
    }
}

private struct PersistedState: Codable {
    let practiceItems: [PracticeItem]
    let readerSettings: ReaderSettings
    let bookmarkedScriptureIDs: [String]
    let readingProgress: [String: Int]
    let dedicationRecords: [DedicationRecord]
}

enum ScriptureCatalog {
    static let defaultPractices = [
        PracticeItem(id: "practice-heart", title: "心经", scriptureID: "heart-sutra", current: 0, target: 1, unit: "遍", kind: .reading),
        PracticeItem(id: "practice-great-compassion", title: "大悲咒", scriptureID: "great-compassion-mantra", current: 0, target: 3, unit: "遍", kind: .chanting),
        PracticeItem(id: "practice-amitabha", title: "阿弥陀佛", scriptureID: nil, current: 36, target: 108, unit: "声", kind: .counter)
    ]

    static let scriptures: [Scripture] = [
        heartSutra,
        diamondSutra,
        amitabhaSutra,
        ksitigarbhaSutra,
        greatCompassionMantra,
        surangamaMantra,
        medicineBuddhaSutra,
        infiniteLifeSutra,
        contemplationSutra,
        universalGate
    ]

    static let heartSutra: Scripture = Scripture(
            id: "heart-sutra",
            title: "般若波罗蜜多心经",
            shortTitle: "心经",
            translator: "玄奘",
            dynasty: "唐",
            category: "常诵经典",
            durationMinutes: 3,
            source: "待接入可追溯大藏经文本；当前为原型节选",
            hasModernPunctuation: true,
            hasAudio: true,
            hasNotes: true,
            chapters: [ScriptureChapter(id: "heart-main", title: "全文", paragraphStart: 0)],
            simplifiedParagraphs: [
                "观自在菩萨，行深般若波罗蜜多时，照见五蕴皆空，度一切苦厄。",
                "舍利子，色不异空，空不异色，色即是空，空即是色。",
                "受想行识，亦复如是。",
                "舍利子，是诸法空相，不生不灭，不垢不净，不增不减。",
                "故空中无色，无受想行识，无眼耳鼻舌身意，无色声香味触法。",
                "无无明，亦无无明尽，乃至无老死，亦无老死尽。",
                "无苦集灭道，无智亦无得，以无所得故。",
                "菩提萨埵，依般若波罗蜜多故，心无挂碍。",
                "故知般若波罗蜜多，是大神咒，是大明咒，是无上咒，是无等等咒。",
                "揭谛揭谛，波罗揭谛，波罗僧揭谛，菩提萨婆诃。"
            ],
            traditionalParagraphs: [
                "觀自在菩薩，行深般若波羅蜜多時，照見五蘊皆空，度一切苦厄。",
                "舍利子，色不異空，空不異色，色即是空，空即是色。",
                "受想行識，亦復如是。",
                "舍利子，是諸法空相，不生不滅，不垢不淨，不增不減。",
                "故空中無色，無受想行識，無眼耳鼻舌身意，無色聲香味觸法。",
                "無無明，亦無無明盡，乃至無老死，亦無老死盡。",
                "無苦集滅道，無智亦無得，以無所得故。",
                "菩提薩埵，依般若波羅蜜多故，心無罣礙。",
                "故知般若波羅蜜多，是大神咒，是大明咒，是無上咒，是無等等咒。",
                "揭諦揭諦，波羅揭諦，波羅僧揭諦，菩提薩婆訶。"
            ],
            notes: [
                ScriptureNote(id: "heart-note-0", paragraphIndex: 0, text: "五蕴指色、受、想、行、识。正式版本需显示出处与术语来源。")
            ]
    )

    static let diamondSutra: Scripture = scriptureStub(id: "diamond-sutra", title: "金刚般若波罗蜜经", shortTitle: "金刚经", translator: "鸠摩罗什", dynasty: "姚秦", category: "般若", durationMinutes: 45, hasAudio: false)
    static let amitabhaSutra: Scripture = scriptureStub(id: "amitabha-sutra", title: "佛说阿弥陀经", shortTitle: "阿弥陀经", translator: "鸠摩罗什", dynasty: "姚秦", category: "净土", durationMinutes: 12, hasAudio: true)
    static let ksitigarbhaSutra: Scripture = scriptureStub(id: "ksitigarbha-sutra", title: "地藏菩萨本愿经", shortTitle: "地藏经", translator: "实叉难陀", dynasty: "唐", category: "地藏", durationMinutes: 120, hasAudio: false)

    static let greatCompassionMantra: Scripture = Scripture(
            id: "great-compassion-mantra",
            title: "大悲咒",
            shortTitle: "大悲咒",
            translator: "伽梵达摩",
            dynasty: "唐",
            category: "咒语",
            durationMinutes: 7,
            source: "待接入可追溯大藏经文本；当前为原型节选",
            hasModernPunctuation: true,
            hasAudio: true,
            hasNotes: false,
            chapters: [ScriptureChapter(id: "great-compassion-main", title: "全文", paragraphStart: 0)],
            simplifiedParagraphs: [
                "南无喝啰怛那哆啰夜耶。",
                "南无阿唎耶。",
                "婆卢羯帝烁钵啰耶。",
                "菩提萨埵婆耶。",
                "摩诃萨埵婆耶。",
                "摩诃迦卢尼迦耶。",
                "唵，萨皤啰罚曳。"
            ],
            traditionalParagraphs: [
                "南無喝囉怛那哆囉夜耶。",
                "南無阿唎耶。",
                "婆盧羯帝爍鉢囉耶。",
                "菩提薩埵婆耶。",
                "摩訶薩埵婆耶。",
                "摩訶迦盧尼迦耶。",
                "唵，薩皤囉罰曳。"
            ],
            notes: []
    )

    static let surangamaMantra: Scripture = scriptureStub(id: "surangama-mantra", title: "楞严咒", shortTitle: "楞严咒", translator: "般剌蜜帝", dynasty: "唐", category: "咒语", durationMinutes: 25, hasAudio: false)
    static let medicineBuddhaSutra: Scripture = scriptureStub(id: "medicine-buddha-sutra", title: "药师琉璃光如来本愿功德经", shortTitle: "药师经", translator: "玄奘", dynasty: "唐", category: "药师", durationMinutes: 35, hasAudio: false)
    static let infiniteLifeSutra: Scripture = scriptureStub(id: "infinite-life-sutra", title: "佛说无量寿经", shortTitle: "无量寿经", translator: "康僧铠", dynasty: "曹魏", category: "净土", durationMinutes: 80, hasAudio: false)
    static let contemplationSutra: Scripture = scriptureStub(id: "contemplation-sutra", title: "佛说观无量寿佛经", shortTitle: "观无量寿经", translator: "畺良耶舍", dynasty: "刘宋", category: "净土", durationMinutes: 45, hasAudio: false)
    static let universalGate: Scripture = scriptureStub(id: "universal-gate", title: "妙法莲华经观世音菩萨普门品", shortTitle: "普门品", translator: "鸠摩罗什", dynasty: "姚秦", category: "观音", durationMinutes: 25, hasAudio: false)

    private static func scriptureStub(
        id: String,
        title: String,
        shortTitle: String,
        translator: String,
        dynasty: String,
        category: String,
        durationMinutes: Int,
        hasAudio: Bool
    ) -> Scripture {
        Scripture(
            id: id,
            title: title,
            shortTitle: shortTitle,
            translator: translator,
            dynasty: dynasty,
            category: category,
            durationMinutes: durationMinutes,
            source: "待接入可追溯大藏经文本；当前为原型占位",
            hasModernPunctuation: true,
            hasAudio: hasAudio,
            hasNotes: true,
            chapters: [
                ScriptureChapter(id: "\(id)-intro", title: "经题与发起", paragraphStart: 0),
                ScriptureChapter(id: "\(id)-main", title: "正文节选", paragraphStart: 1)
            ],
            simplifiedParagraphs: [
                "如是我闻。一时佛在舍卫国，祇树给孤独园，与大比丘众俱。",
                "尔时，世尊告诸大众：应当安住正念，随顺清净法门。",
                "此处为原型节选。正式版本会接入完整经文、章节结构、注释和来源校验。"
            ],
            traditionalParagraphs: [
                "如是我聞。一時佛在舍衛國，祇樹給孤獨園，與大比丘眾俱。",
                "爾時，世尊告諸大眾：應當安住正念，隨順清淨法門。",
                "此處為原型節選。正式版本會接入完整經文、章節結構、註釋和來源校驗。"
            ],
            notes: [
                ScriptureNote(id: "\(id)-note-0", paragraphIndex: 2, text: "该条目已保留元数据，正文仍需替换为可追溯版本。")
            ]
        )
    }
}
