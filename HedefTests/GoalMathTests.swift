import XCTest
@testable import Hedef

final class GoalMathTests: XCTestCase {
    func testContributionMustBeRealToChangeProgress() {
        let goal = Goal(name: "Tatil", emoji: "🌴", color: "#FFC3A8", targetMinor: 100_000, savedMinor: 10_000, dailyMinor: 200, currency: "USD")
        XCTAssertEqual(goal.progress, 0.1)
        XCTAssertEqual(GoalMath.gainedDays(ifSaved: 10_000, goal: goal), 50)
        XCTAssertEqual(goal.savedMinor, 10_000)
    }

    func testZeroContributionHasNoForecast() {
        let goal = Goal(name: "Tatil", emoji: "🌴", color: "#FFC3A8", targetMinor: 100_000, dailyMinor: 0, currency: "USD")
        XCTAssertNil(goal.projectedDays)
        XCTAssertNil(GoalMath.delayedDays(ifTakenFromPlan: 1_000, goal: goal))
    }

    func testBudgetNeverSuggestsMoreThanAvailable() {
        let budget = Budget(monthlyIncomeMinor: 200_000, fixedMinor: 150_000, essentialsMinor: 40_000, bufferMinor: 20_000)
        XCTAssertEqual(budget.freeMinor, 0)
        XCTAssertEqual(budget.suggestedMonthlyMinor, 0)
    }

    func testGoalAllocationsNeverExceedBudget() {
        let a = Goal(name: "Tatil", emoji: "🌴", color: "#FFC3A8", targetMinor: 100_000, dailyMinor: 1_000, currency: "USD", priority: 3)
        let b = Goal(name: "Bisiklet", emoji: "🚲", color: "#B7E8D0", targetMinor: 80_000, dailyMinor: 800, currency: "USD", priority: 2)
        let budget = Budget(currency: "USD", monthlyIncomeMinor: 200_000, fixedMinor: 100_000, essentialsMinor: 40_000, bufferMinor: 10_000)
        let allocations = BudgetPlanner.allocations(goals: [a, b], budget: budget)
        XCTAssertLessThanOrEqual(allocations.reduce(0) { $0 + $1.monthlyMinor }, budget.suggestedMonthlyMinor)
        XCTAssertEqual(allocations.first?.goal.id, a.id)
    }

    func testOlderSavedDataDecodesWithNewDefaults() throws {
        let json = #"{"goals":[{"name":"Tatil","targetMinor":10000}],"entries":[]}"#
        let state = try JSONDecoder().decode(AppState.self, from: Data(json.utf8))
        XCTAssertEqual(state.goals.first?.currency, "TRY")
        XCTAssertEqual(state.goals.first?.size, .medium)
        XCTAssertEqual(state.walletReminderFrequency, .daily)
    }

    func testConcurrentContributionsMergeWithoutLosingMoney() async {
        let id = UUID()
        var goal = Goal(id: id, name: "Tatil", emoji: "🌴", color: "#FFC3A8", targetMinor: 100_000, dailyMinor: 500, currency: "USD")
        goal.updatedAt = Date(timeIntervalSince1970: 1_000)
        let first = MoneyEntry(goalID: id, kind: .contribution, amountMinor: 1_000, currency: "USD", note: "A")
        let second = MoneyEntry(goalID: id, kind: .contribution, amountMinor: 2_000, currency: "USD", note: "B")
        var local = AppState()
        local.goals = [goal]
        local.entries = [first]
        var remote = AppState()
        remote.goals = [goal]
        remote.entries = [second]
        let merged = await CloudSyncService.shared.merge(local: local, remote: remote)
        XCTAssertEqual(merged.entries.count, 2)
        XCTAssertEqual(merged.goals.first?.savedMinor, 3_000)
    }

    func testDeletedGoalDoesNotReturnFromOlderDevice() async {
        var goal = Goal(name: "Tatil", emoji: "🌴", color: "#FFC3A8", targetMinor: 100_000, dailyMinor: 500, currency: "USD")
        goal.updatedAt = Date(timeIntervalSince1970: 1_000)
        var local = AppState()
        local.deletedGoalIDs[goal.id.uuidString] = Date(timeIntervalSince1970: 2_000)
        var remote = AppState()
        remote.goals = [goal]
        let merged = await CloudSyncService.shared.merge(local: local, remote: remote)
        XCTAssertTrue(merged.goals.isEmpty)
    }

    func testDeadlineNeedsFourDollarsPerDayForThreeThousandInSevenHundredFiftyDays() {
        let deadline = Calendar.current.date(byAdding: .day, value: 750, to: Calendar.current.startOfDay(for: .now))!
        let goal = Goal(name: "Amerika", emoji: "🗽", color: "#FFC3A8", targetMinor: 300_000, dailyMinor: 400, currency: "USD", deadline: deadline)
        XCTAssertEqual(goal.requiredDailyMinor, 400)
    }

    func testMoneyRejectsOverflowAndKeepsCents() {
        XCTAssertEqual(Money.minor(Decimal(string: "12.34")!), 1_234)
        XCTAssertNil(Money.minor(Decimal(string: "999999999999999999999")!))
    }

    func testWeeklyAndMonthlyPlansUseDailyEquivalent() {
        var goal = Goal(name: "Tatil", emoji: "🌴", color: "#FFC3A8", targetMinor: 7_000, dailyMinor: 1_000, currency: "USD")
        goal.contributionFrequency = .weekly
        XCTAssertEqual(goal.projectedDays, 49)
        goal.contributionFrequency = .monthly
        XCTAssertEqual(goal.projectedDays, 214)
    }

    func testGoalFundedExpenseReducesMergedSavings() async {
        let goal = Goal(name: "Tatil", emoji: "🌴", color: "#FFC3A8", targetMinor: 10_000, dailyMinor: 100, currency: "USD")
        let contribution = MoneyEntry(goalID: goal.id, kind: .contribution, amountMinor: 5_000, currency: "USD", note: "Birikim")
        var expense = MoneyEntry(goalID: goal.id, kind: .expense, amountMinor: 2_000, currency: "USD", note: "Bilet")
        expense.expenseSource = .goalSavings
        var local = AppState()
        local.goals = [goal]
        local.entries = [contribution]
        var remote = AppState()
        remote.goals = [goal]
        remote.entries = [expense]
        let merged = await CloudSyncService.shared.merge(local: local, remote: remote)
        XCTAssertEqual(merged.goals.first?.savedMinor, 3_000)
    }
}
