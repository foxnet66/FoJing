import SwiftUI

struct ScriptureLibraryView: View {
    let appModel: AppModel

    @State private var query = ""
    @State private var selectedCategory = "常诵经典"

    private let categories = ["常诵经典", "净土", "般若", "观音", "地藏", "药师", "咒语"]

    private var visibleScriptures: [Scripture] {
        appModel.scriptures.filter { scripture in
            let matchesCategory = scripture.category == selectedCategory
            let matchesQuery = query.isEmpty ||
                scripture.title.localizedStandardContains(query) ||
                scripture.shortTitle.localizedStandardContains(query) ||
                scripture.translator.localizedStandardContains(query)
            return matchesCategory && matchesQuery
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                searchField
                categoryScroller
                scriptureList
            }
            .padding(20)
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
        .background(.white.opacity(0.46), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.paperDeep, lineWidth: 1)
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
                            .foregroundStyle(selectedCategory == category ? .white : AppTheme.bamboo)
                            .background(selectedCategory == category ? AppTheme.bamboo : .white.opacity(0.34), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var scriptureList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedCategory)
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
                                HStack(spacing: 8) {
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

                NavigationLink {
                    ScriptureReaderView(
                        appModel: appModel,
                        scripture: scripture,
                        mode: scripture.category == "咒语" ? .chanting : .reading
                    )
                } label: {
                    Label("开始阅读", systemImage: "book.pages")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .foregroundStyle(.white)
                        .background(AppTheme.bamboo, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

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
        }
        .navigationTitle("经文详情")
        .navigationBarTitleDisplayMode(.inline)
        .sutraPageBackground()
    }
}

#Preview {
    NavigationStack {
        ScriptureLibraryView(appModel: AppModel())
    }
}
