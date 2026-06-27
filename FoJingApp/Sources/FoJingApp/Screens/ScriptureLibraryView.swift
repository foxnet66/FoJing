import SwiftUI

struct ScriptureLibraryView: View {
    let appModel: AppModel

    @State private var query = ""
    @State private var selectedCategory = "日课"

    private let categories = ["日课", "常诵经典", "净土", "般若", "观音", "地藏", "药师", "咒语"]

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var listTitle: String {
        trimmedQuery.isEmpty ? selectedCategory : "搜索结果"
    }

    private var visibleScriptures: [Scripture] {
        appModel.scriptures.filter { scripture in
            if trimmedQuery.isEmpty {
                if selectedCategory == "日课" {
                    return dailyPracticeScriptureIDs.contains(scripture.id)
                }
                return scripture.category == selectedCategory
            }

            return scripture.title.localizedStandardContains(trimmedQuery) ||
                scripture.shortTitle.localizedStandardContains(trimmedQuery) ||
                scripture.translator.localizedStandardContains(trimmedQuery) ||
                scripture.category.localizedStandardContains(trimmedQuery)
        }
    }

    private var recentReadableScriptures: [Scripture] {
        var seenIDs = Set<String>()
        var result: [Scripture] = []

        if let recent = appModel.scripture(id: appModel.recentScriptureID), !recent.isPrototypeContent {
            result.append(recent)
            seenIDs.insert(recent.id)
        }

        for scripture in appModel.scriptures where !scripture.isPrototypeContent {
            guard !seenIDs.contains(scripture.id), readingProgress(for: scripture) > 0 else { continue }
            result.append(scripture)
            seenIDs.insert(scripture.id)
        }

        return result
    }

    private var dailyPracticeScriptureIDs: Set<String> {
        Set(appModel.practiceItems.compactMap(\.scriptureID))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                searchField
                if trimmedQuery.isEmpty, !recentReadableScriptures.isEmpty {
                    recentReadingSection
                }
                categoryScroller
                scriptureList
            }
            .padding(20)
            .padding(.bottom, AppTheme.tabContentBottomPadding)
        }
        .navigationTitle("经藏")
        .sutraPageBackground()
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.secondaryInk)
            TextField("搜索经名、译者、关键词", text: $query)
                .textInputAutocapitalization(.never)
        }
        .padding(13)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.separator, lineWidth: 1)
        }
    }

    private var recentReadingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近阅读")
                .font(.headline)

            ForEach(recentReadableScriptures.prefix(3)) { scripture in
                NavigationLink {
                    ScriptureReaderView(
                        appModel: appModel,
                        scripture: scripture,
                        mode: scripture.category == "咒语" ? .chanting : .reading,
                        practiceID: nil
                    )
                } label: {
                    PaperCard {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.title3)
                                .foregroundStyle(AppTheme.gold)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(scripture.title)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(AppTheme.ink)
                                Text(readingProgressText(for: scripture))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.secondaryInk)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.secondaryInk)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var categoryScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(categories, id: \.self) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .foregroundStyle(selectedCategory == category ? Color.white : AppTheme.bamboo)
                            .background(selectedCategory == category ? AppTheme.bamboo : AppTheme.surfaceSubtle, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var scriptureList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(listTitle)
                .font(.headline)

            ForEach(visibleScriptures) { scripture in
                NavigationLink {
                    ScriptureDetailView(appModel: appModel, scripture: scripture)
                } label: {
                    PaperCard {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: scripture.hasAudio ? "play.circle" : "text.book.closed")
                                .font(.title3)
                                .foregroundStyle(AppTheme.gold)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 7) {
                                Text(scripture.title)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.ink)
                                Text("\(scripture.subtitle) · \(scripture.duration)")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.secondaryInk)
                                if readingProgress(for: scripture) > 0 {
                                    Label(readingProgressText(for: scripture), systemImage: "bookmark.circle")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondaryInk)
                                }
                                HStack(spacing: 8) {
                                    if scripture.isPrototypeContent {
                                        Label("待接入全文", systemImage: "exclamationmark.circle")
                                    }
                                    if scripture.hasAudio {
                                        Label("音频", systemImage: "speaker.wave.2")
                                    }
                                    if scripture.hasNotes {
                                        Label("注释", systemImage: "note.text")
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(AppTheme.bamboo)
                            }
                            Spacer()
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            if visibleScriptures.isEmpty {
                Text("没有找到匹配的经文")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryInk)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 28)
            }
        }
    }

    private func readingProgress(for scripture: Scripture) -> Int {
        appModel.readingProgress[scripture.id] ?? 0
    }

    private func readingProgressText(for scripture: Scripture) -> String {
        let progress = readingProgress(for: scripture)
        guard progress > 0 else {
            return "尚未开始"
        }
        let paragraphCount = max(scripture.simplifiedParagraphs.count, scripture.traditionalParagraphs.count)
        guard paragraphCount > 0 else {
            return "已开始阅读"
        }
        return "读到第 \(min(progress + 1, paragraphCount))/\(paragraphCount) 段"
    }
}

struct ScriptureDetailView: View {
    let appModel: AppModel
    let scripture: Scripture

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(scripture.category)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.bamboo)
                    Text(scripture.title)
                        .font(.largeTitle.weight(.semibold))
                    Text("\(scripture.subtitle) · \(scripture.duration)")
                        .foregroundStyle(AppTheme.secondaryInk)
                }

                PaperCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("版本说明")
                            .font(.headline)
                        Text(scripture.source)
                            .foregroundStyle(AppTheme.secondaryInk)
                            .lineSpacing(5)
                        HStack(spacing: 12) {
                            Label(scripture.hasModernPunctuation ? "现代标点" : "原始标点", systemImage: "textformat")
                            if scripture.isPrototypeContent {
                                Label("待接入全文", systemImage: "exclamationmark.circle")
                            }
                            if scripture.hasAudio {
                                Label("音频", systemImage: "speaker.wave.2")
                            }
                            if scripture.hasNotes {
                                Label("注释", systemImage: "note.text")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(AppTheme.bamboo)
                    }
                }

                if scripture.isPrototypeContent {
                    Label("待接入可追溯全文", systemImage: "exclamationmark.circle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .foregroundStyle(AppTheme.secondaryInk)
                        .background(AppTheme.paperDeep.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
                } else {
                    NavigationLink {
                        ScriptureReaderView(
                            appModel: appModel,
                            scripture: scripture,
                            mode: scripture.category == "咒语" ? .chanting : .reading,
                            practiceID: nil
                        )
                    } label: {
                        Label(primaryActionTitle, systemImage: "book.pages")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .foregroundStyle(Color.white)
                            .background(AppTheme.bamboo, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }

                PaperCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("章节")
                            .font(.headline)
                        ForEach(scripture.chapters) { chapter in
                            HStack {
                                Text(chapter.title)
                                Spacer()
                                Text("第 \(chapter.paragraphStart + 1) 段")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.secondaryInk)
                            }
                            .font(.subheadline)
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, AppTheme.tabContentBottomPadding)
        }
        .navigationTitle("经文详情")
        .navigationBarTitleDisplayMode(.inline)
        .sutraPageBackground()
    }

    private var primaryActionTitle: String {
        let progress = appModel.readingProgress[scripture.id] ?? 0
        return progress > 0 ? "继续阅读" : "开始阅读"
    }
}

#Preview {
    NavigationStack {
        ScriptureLibraryView(appModel: AppModel())
    }
}
