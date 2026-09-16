import Foundation

enum Money {
    static func minor(_ amount: Decimal) -> Int64? {
        let scaled = NSDecimalNumber(decimal: amount * 100)
        let rounded = scaled.rounding(accordingToBehavior: NSDecimalNumberHandler(roundingMode: .plain, scale: 0, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false))
        guard rounded != NSDecimalNumber.notANumber,
              rounded.compare(scaled) == .orderedSame,
              rounded.compare(NSDecimalNumber(value: 0)) == .orderedDescending,
              rounded.compare(NSDecimalNumber(value: Int64.max)) != .orderedDescending else { return nil }
        return rounded.int64Value
    }

    static func decimal(_ minor: Int64) -> Decimal { Decimal(minor) / 100 }

    static func format(_ minor: Int64, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = Locale.current
        return formatter.string(from: NSDecimalNumber(decimal: decimal(minor))) ?? "\(decimal(minor)) \(currency)"
    }
}

struct Goal: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var emoji: String
    var color: String
    var size: GoalSize = .medium
    var targetMinor: Int64
    var savedMinor: Int64 = 0
    var dailyMinor: Int64
    var contributionFrequency: ContributionFrequency = .daily
    var currency: String
    var deadline: Date?
    var priority: Int = 2
    var createdAt: Date = .now
    var paused: Bool = false
    var completedAt: Date?
    var updatedAt: Date = .now

    var remainingMinor: Int64 { max(0, targetMinor - savedMinor) }
    var progress: Double { targetMinor > 0 ? min(1, Double(savedMinor) / Double(targetMinor)) : 0 }
    var daysUntilDeadline: Int? {
        guard let deadline else { return nil }
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: deadline)).day
    }
    var projectedDays: Int? {
        guard remainingMinor > 0 else { return 0 }
        guard !paused else { return nil }
        guard equivalentDailyMinor > 0 else { return nil }
        return Int(ceil(Double(remainingMinor) / equivalentDailyMinor))
    }
    var equivalentDailyMinor: Double {
        switch contributionFrequency {
        case .daily: return Double(dailyMinor)
        case .weekly: return Double(dailyMinor) / 7
        case .monthly: return Double(dailyMinor) / 30.44
        }
    }
    var requiredDailyMinor: Int64? {
        guard let days = daysUntilDeadline, days > 0 else { return nil }
        return Int64(ceil(Double(remainingMinor) / Double(days)))
    }
    var planDifferenceMinor: Int64? {
        guard equivalentDailyMinor > 0 else { return nil }
        let elapsed = max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: createdAt), to: Calendar.current.startOfDay(for: .now)).day ?? 0)
        let expected = min(Double(targetMinor), Double(elapsed) * equivalentDailyMinor)
        return Int64(Double(savedMinor) - expected)
    }
    var projectedDate: Date? {
        guard let projectedDays, projectedDays > 0 else { return nil }
        return Calendar.current.date(byAdding: .day, value: projectedDays, to: Calendar.current.startOfDay(for: .now))
    }
}

enum ContributionFrequency: String, Codable, CaseIterable, Identifiable {
    case daily, weekly, monthly
    var id: String { rawValue }
    var title: String {
        switch self {
        case .daily: return "Günlük"
        case .weekly: return "Haftalık"
        case .monthly: return "Aylık"
        }
    }
}

enum GoalSize: String, Codable, CaseIterable, Identifiable {
    case small, medium, large
    var id: String { rawValue }
    var title: String {
        switch self {
        case .small: return "Küçük"
        case .medium: return "Orta"
        case .large: return "Büyük"
        }
    }
    var emoji: String {
        switch self {
        case .small: return "🌱"
        case .medium: return "🌼"
        case .large: return "🚀"
        }
    }
}

enum EntryKind: String, Codable { case contribution, expense }
enum ExpenseSource: String, Codable { case dailyBudget, goalSavings }

struct MoneyEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var goalID: UUID?
    var kind: EntryKind
    var amountMinor: Int64
    var currency: String
    var category: ExpenseCategory? = nil
    var expenseSource: ExpenseSource = .dailyBudget
    var note: String
    var date: Date = .now
    var sourceKey: String?
    var updatedAt: Date = .now
}

enum ExpenseCategory: String, Codable, CaseIterable, Identifiable {
    case food, transport, shopping, entertainment, bills, health, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .food: return "Yeme içme"
        case .transport: return "Ulaşım"
        case .shopping: return "Alışveriş"
        case .entertainment: return "Eğlence"
        case .bills: return "Faturalar"
        case .health: return "Sağlık"
        case .other: return "Diğer"
        }
    }
    var emoji: String {
        switch self {
        case .food: return "🍜"
        case .transport: return "🚇"
        case .shopping: return "🛍️"
        case .entertainment: return "🎈"
        case .bills: return "🧾"
        case .health: return "💊"
        case .other: return "✨"
        }
    }
}

struct Budget: Codable {
    var currency: String = "TRY"
    var monthlyIncomeMinor: Int64 = 0
    var fixedMinor: Int64 = 0
    var essentialsMinor: Int64 = 0
    var bufferMinor: Int64 = 0
    var allocationPercent: Int = 60
    var updatedAt: Date = .distantPast

    var freeMinor: Int64 { max(0, monthlyIncomeMinor - fixedMinor - essentialsMinor - bufferMinor) }
    var suggestedMinMinor: Int64 { Int64(Double(freeMinor) * 0.4) }
    var suggestedMaxMinor: Int64 { Int64(Double(freeMinor) * 0.7) }
    var suggestedMonthlyMinor: Int64 { Int64(Double(freeMinor) * Double(min(100, max(0, allocationPercent))) / 100) }
    var suggestedDailyMinor: Int64 { Int64(Double(suggestedMonthlyMinor) / 30.44) }
}

struct AppState: Codable {
    var goals: [Goal] = []
    var entries: [MoneyEntry] = []
    var budget = Budget()
    var selectedGoalID: UUID?
    var notificationsEnabled = false
    var showAmountsInNotifications = false
    var walletReminderFrequency: WalletReminderFrequency = .daily
    var lastWalletReminderAt: Date?
    var updatedAt: Date = .now
    var deletedGoalIDs: [String: Date] = [:]
    var deletedEntryIDs: [String: Date] = [:]
}

enum WalletReminderFrequency: String, Codable, CaseIterable, Identifiable {
    case off, daily, always
    var id: String { rawValue }
    var title: String {
        switch self {
        case .off: return "Kapalı"
        case .daily: return "Günde bir"
        case .always: return "Her açılışta"
        }
    }
}

struct GoalAllocation: Identifiable {
    let goal: Goal
    let monthlyMinor: Int64
    let requiredMonthlyMinor: Int64?
    var id: UUID { goal.id }
    var shortfallMinor: Int64? { requiredMonthlyMinor.map { max(0, $0 - monthlyMinor) } }
}

enum BudgetPlanner {
    static func allocations(goals: [Goal], budget: Budget) -> [GoalAllocation] {
        let active = goals.filter { !$0.paused && $0.completedAt == nil && $0.remainingMinor > 0 }
            .sorted { left, right in
                if left.priority != right.priority { return left.priority > right.priority }
                return (left.deadline ?? .distantFuture) < (right.deadline ?? .distantFuture)
            }
        guard !active.isEmpty else { return [] }
        var remaining = budget.suggestedMonthlyMinor
        return active.map { goal in
            let required: Int64? = goal.requiredDailyMinor.map { Int64(ceil(Double($0) * 30.44)) }
            let wanted = required ?? Int64(ceil(goal.equivalentDailyMinor * 30.44))
            let portion = min(remaining, max(0, wanted))
            remaining -= portion
            return GoalAllocation(goal: goal, monthlyMinor: portion, requiredMonthlyMinor: required)
        }
    }
}

enum GoalMath {
    static func savingsBalance(entries: [MoneyEntry], goalID: UUID) -> Int64 {
        var contributions: Int64 = 0
        var expenses: Int64 = 0
        for entry in entries where entry.goalID == goalID {
            if entry.kind == .contribution {
                let result = contributions.addingReportingOverflow(entry.amountMinor)
                contributions = result.overflow ? Int64.max : result.partialValue
            } else if entry.expenseSource == .goalSavings {
                let result = expenses.addingReportingOverflow(entry.amountMinor)
                expenses = result.overflow ? Int64.max : result.partialValue
            }
        }
        return max(0, contributions - expenses)
    }

    static func fractionOfTarget(priceMinor: Int64, goal: Goal) -> Double {
        guard goal.targetMinor > 0 else { return 0 }
        return Double(priceMinor) / Double(goal.targetMinor) * 100
    }

    static func gainedDays(ifSaved priceMinor: Int64, goal: Goal) -> Int? {
        guard let before = goal.projectedDays, goal.equivalentDailyMinor > 0 else { return nil }
        let after = Int(ceil(Double(max(0, goal.remainingMinor - priceMinor)) / goal.equivalentDailyMinor))
        return max(0, before - after)
    }

    static func delayedDays(ifTakenFromPlan priceMinor: Int64, goal: Goal) -> Int? {
        guard goal.equivalentDailyMinor > 0 else { return nil }
        return Int(ceil(Double(priceMinor) / goal.equivalentDailyMinor))
    }
}
