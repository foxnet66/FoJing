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
