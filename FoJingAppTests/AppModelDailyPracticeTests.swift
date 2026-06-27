import XCTest
@testable import FoJing

final class AppModelDailyPracticeTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "FoJingAppTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testPracticeProgressSurvivesRepeatedLaunchesOnSameDay() {
        let today = makeDate(year: 2026, month: 6, day: 12)

        let firstLaunch = AppModel(userDefaults: userDefaults, dateProvider: { today })
        firstLaunch.markPracticeComplete(id: "practice-heart")

        let secondLaunch = AppModel(userDefaults: userDefaults, dateProvider: { today })
        XCTAssertTrue(secondLaunch.practiceItem(id: "practice-heart").isComplete)

        let thirdLaunch = AppModel(userDefaults: userDefaults, dateProvider: { today })
        XCTAssertTrue(thirdLaunch.practiceItem(id: "practice-heart").isComplete)
    }

    func testRefreshDailyPracticeResetsAndPersistsCountersAfterDateChanges() {
        var currentDate = makeDate(year: 2026, month: 6, day: 12)
        let appModel = AppModel(userDefaults: userDefaults, dateProvider: { currentDate })

        appModel.markPracticeComplete(id: "practice-heart")
        for _ in 0..<5 {
            appModel.incrementPractice(id: "practice-amitabha")
        }

        currentDate = makeDate(year: 2026, month: 6, day: 13)

        XCTAssertTrue(appModel.refreshDailyPracticeIfNeeded())
        XCTAssertFalse(appModel.practiceItem(id: "practice-heart").isComplete)
        XCTAssertEqual(appModel.practiceItem(id: "practice-amitabha").current, 0)

        let relaunched = AppModel(userDefaults: userDefaults, dateProvider: { currentDate })
        XCTAssertFalse(relaunched.practiceItem(id: "practice-heart").isComplete)
        XCTAssertEqual(relaunched.practiceItem(id: "practice-amitabha").current, 0)
    }

    func testCompletingDailyPracticeRecordsHistoryOnceAndPersistsIt() {
        let today = makeDate(year: 2026, month: 6, day: 12)
        let appModel = AppModel(userDefaults: userDefaults, dateProvider: { today })

        appModel.markPracticeComplete(id: "practice-heart")
        appModel.markPracticeComplete(id: "practice-great-compassion")
        for _ in 0..<108 {
            appModel.incrementPractice(id: "practice-amitabha")
        }
        appModel.incrementPractice(id: "practice-amitabha")

        XCTAssertEqual(appModel.dailyPracticeRecords.count, 1)
        XCTAssertEqual(appModel.dailyPracticeRecords[0].id, "2026-06-12")
        XCTAssertEqual(appModel.dailyPracticeRecords[0].completedItems.count, 3)

        let relaunched = AppModel(userDefaults: userDefaults, dateProvider: { today })
        XCTAssertEqual(relaunched.dailyPracticeRecords.count, 1)
        XCTAssertEqual(relaunched.dailyPracticeRecords[0].id, "2026-06-12")
    }

    func testCustomPracticePlanPersistsAndResetsNextDay() {
        var currentDate = makeDate(year: 2026, month: 6, day: 12)
        let appModel = AppModel(userDefaults: userDefaults, dateProvider: { currentDate })
        let amitabhaSutraPractice = ScriptureCatalog.practiceTemplate(for: ScriptureCatalog.amitabhaSutra)

        appModel.setPracticeEnabled(amitabhaSutraPractice, isEnabled: true)
        appModel.updatePracticeTarget(id: amitabhaSutraPractice.id, target: 2)
        appModel.markPracticeComplete(id: amitabhaSutraPractice.id)

        XCTAssertEqual(appModel.practicePlan.count, 4)
        XCTAssertEqual(appModel.practiceItem(id: amitabhaSutraPractice.id).target, 2)
        XCTAssertTrue(appModel.practiceItem(id: amitabhaSutraPractice.id).isComplete)

        currentDate = makeDate(year: 2026, month: 6, day: 13)

        XCTAssertTrue(appModel.refreshDailyPracticeIfNeeded())
        XCTAssertEqual(appModel.practicePlan.count, 4)
        XCTAssertEqual(appModel.practiceItem(id: amitabhaSutraPractice.id).current, 0)
        XCTAssertEqual(appModel.practiceItem(id: amitabhaSutraPractice.id).target, 2)

        let relaunched = AppModel(userDefaults: userDefaults, dateProvider: { currentDate })
        XCTAssertEqual(relaunched.practicePlan.count, 4)
        XCTAssertEqual(relaunched.practiceItem(id: amitabhaSutraPractice.id).current, 0)
        XCTAssertEqual(relaunched.practiceItem(id: amitabhaSutraPractice.id).target, 2)
    }

    func testMovingPracticePlanPersistsOrderAndKeepsProgress() {
        let today = makeDate(year: 2026, month: 6, day: 12)
        let appModel = AppModel(userDefaults: userDefaults, dateProvider: { today })

        appModel.markPracticeComplete(id: "practice-heart")
        appModel.movePracticePlanItems(from: IndexSet(integer: 2), to: 0)

        XCTAssertEqual(appModel.practicePlan.map(\.id), ["practice-amitabha", "practice-heart", "practice-great-compassion"])
        XCTAssertEqual(appModel.practiceItems.map(\.id), ["practice-amitabha", "practice-heart", "practice-great-compassion"])
        XCTAssertTrue(appModel.practiceItem(id: "practice-heart").isComplete)

        let relaunched = AppModel(userDefaults: userDefaults, dateProvider: { today })
        XCTAssertEqual(relaunched.practicePlan.map(\.id), ["practice-amitabha", "practice-heart", "practice-great-compassion"])
        XCTAssertEqual(relaunched.practiceItems.map(\.id), ["practice-amitabha", "practice-heart", "practice-great-compassion"])
        XCTAssertTrue(relaunched.practiceItem(id: "practice-heart").isComplete)
    }

    func testAmitabhaSutraUsesFullResourceContent() {
        let appModel = AppModel(userDefaults: userDefaults)
        let scripture = appModel.scripture(id: "amitabha-sutra")

        XCTAssertNotNil(scripture)
        XCTAssertEqual(scripture?.source.contains("T12n0366"), true)
        XCTAssertEqual(scripture?.isPrototypeContent, false)
        XCTAssertEqual(scripture?.simplifiedParagraphs.count, 20)
        XCTAssertEqual(scripture?.traditionalParagraphs.count, 20)
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = .current
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return components.date!
    }
}

private extension AppModel {
    func practiceItem(id: String) -> PracticeItem {
        guard let item = practiceItems.first(where: { $0.id == id }) else {
            XCTFail("Missing practice item \(id)")
            return PracticeItem(id: id, title: id, scriptureID: nil, current: -1, target: 0, unit: "", kind: .counter)
        }
        return item
    }
}
