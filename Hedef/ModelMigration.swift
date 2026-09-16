import Foundation

extension Goal {
    private enum CodingKeys: String, CodingKey {
        case id, name, emoji, color, size, targetMinor, savedMinor, dailyMinor, contributionFrequency, currency
        case deadline, priority, createdAt, paused, completedAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji) ?? "✨"
        color = try c.decodeIfPresent(String.self, forKey: .color) ?? "#FFC3A8"
        size = try c.decodeIfPresent(GoalSize.self, forKey: .size) ?? .medium
        targetMinor = try c.decode(Int64.self, forKey: .targetMinor)
        savedMinor = try c.decodeIfPresent(Int64.self, forKey: .savedMinor) ?? 0
        dailyMinor = try c.decodeIfPresent(Int64.self, forKey: .dailyMinor) ?? 0
        contributionFrequency = try c.decodeIfPresent(ContributionFrequency.self, forKey: .contributionFrequency) ?? .daily
        currency = try c.decodeIfPresent(String.self, forKey: .currency) ?? "TRY"
        deadline = try c.decodeIfPresent(Date.self, forKey: .deadline)
        priority = try c.decodeIfPresent(Int.self, forKey: .priority) ?? 2
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        paused = try c.decodeIfPresent(Bool.self, forKey: .paused) ?? false
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(emoji, forKey: .emoji)
        try c.encode(color, forKey: .color)
        try c.encode(size, forKey: .size)
        try c.encode(targetMinor, forKey: .targetMinor)
        try c.encode(savedMinor, forKey: .savedMinor)
        try c.encode(dailyMinor, forKey: .dailyMinor)
        try c.encode(contributionFrequency, forKey: .contributionFrequency)
        try c.encode(currency, forKey: .currency)
        try c.encodeIfPresent(deadline, forKey: .deadline)
        try c.encode(priority, forKey: .priority)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(paused, forKey: .paused)
        try c.encodeIfPresent(completedAt, forKey: .completedAt)
        try c.encode(updatedAt, forKey: .updatedAt)
    }
}

extension MoneyEntry {
    private enum CodingKeys: String, CodingKey {
        case id, goalID, kind, amountMinor, currency, category, expenseSource, note, date, sourceKey, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        goalID = try c.decodeIfPresent(UUID.self, forKey: .goalID)
        kind = try c.decode(EntryKind.self, forKey: .kind)
        amountMinor = try c.decode(Int64.self, forKey: .amountMinor)
        currency = try c.decodeIfPresent(String.self, forKey: .currency) ?? "TRY"
        category = try c.decodeIfPresent(ExpenseCategory.self, forKey: .category)
        expenseSource = try c.decodeIfPresent(ExpenseSource.self, forKey: .expenseSource) ?? .dailyBudget
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? .now
        sourceKey = try c.decodeIfPresent(String.self, forKey: .sourceKey)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? date
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(goalID, forKey: .goalID)
        try c.encode(kind, forKey: .kind)
        try c.encode(amountMinor, forKey: .amountMinor)
        try c.encode(currency, forKey: .currency)
        try c.encodeIfPresent(category, forKey: .category)
        try c.encode(expenseSource, forKey: .expenseSource)
        try c.encode(note, forKey: .note)
        try c.encode(date, forKey: .date)
        try c.encodeIfPresent(sourceKey, forKey: .sourceKey)
        try c.encode(updatedAt, forKey: .updatedAt)
    }
}

extension Budget {
    private enum CodingKeys: String, CodingKey {
        case currency, monthlyIncomeMinor, fixedMinor, essentialsMinor, bufferMinor, allocationPercent, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        currency = try c.decodeIfPresent(String.self, forKey: .currency) ?? "TRY"
        monthlyIncomeMinor = try c.decodeIfPresent(Int64.self, forKey: .monthlyIncomeMinor) ?? 0
        fixedMinor = try c.decodeIfPresent(Int64.self, forKey: .fixedMinor) ?? 0
        essentialsMinor = try c.decodeIfPresent(Int64.self, forKey: .essentialsMinor) ?? 0
        bufferMinor = try c.decodeIfPresent(Int64.self, forKey: .bufferMinor) ?? 0
        allocationPercent = try c.decodeIfPresent(Int.self, forKey: .allocationPercent) ?? 60
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .distantPast
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(currency, forKey: .currency)
        try c.encode(monthlyIncomeMinor, forKey: .monthlyIncomeMinor)
        try c.encode(fixedMinor, forKey: .fixedMinor)
        try c.encode(essentialsMinor, forKey: .essentialsMinor)
        try c.encode(bufferMinor, forKey: .bufferMinor)
        try c.encode(allocationPercent, forKey: .allocationPercent)
        try c.encode(updatedAt, forKey: .updatedAt)
    }
}

extension AppState {
    private enum CodingKeys: String, CodingKey {
        case goals, entries, budget, selectedGoalID, notificationsEnabled, showAmountsInNotifications
        case walletReminderFrequency, lastWalletReminderAt, updatedAt, deletedGoalIDs, deletedEntryIDs
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        goals = try c.decodeIfPresent([Goal].self, forKey: .goals) ?? []
        entries = try c.decodeIfPresent([MoneyEntry].self, forKey: .entries) ?? []
        budget = try c.decodeIfPresent(Budget.self, forKey: .budget) ?? Budget()
        selectedGoalID = try c.decodeIfPresent(UUID.self, forKey: .selectedGoalID)
        notificationsEnabled = try c.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? false
        showAmountsInNotifications = try c.decodeIfPresent(Bool.self, forKey: .showAmountsInNotifications) ?? false
        walletReminderFrequency = try c.decodeIfPresent(WalletReminderFrequency.self, forKey: .walletReminderFrequency) ?? .daily
        lastWalletReminderAt = try c.decodeIfPresent(Date.self, forKey: .lastWalletReminderAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .distantPast
        deletedGoalIDs = try c.decodeIfPresent([String: Date].self, forKey: .deletedGoalIDs) ?? [:]
        deletedEntryIDs = try c.decodeIfPresent([String: Date].self, forKey: .deletedEntryIDs) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(goals, forKey: .goals)
        try c.encode(entries, forKey: .entries)
        try c.encode(budget, forKey: .budget)
        try c.encodeIfPresent(selectedGoalID, forKey: .selectedGoalID)
        try c.encode(notificationsEnabled, forKey: .notificationsEnabled)
        try c.encode(showAmountsInNotifications, forKey: .showAmountsInNotifications)
        try c.encode(walletReminderFrequency, forKey: .walletReminderFrequency)
        try c.encodeIfPresent(lastWalletReminderAt, forKey: .lastWalletReminderAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(deletedGoalIDs, forKey: .deletedGoalIDs)
        try c.encode(deletedEntryIDs, forKey: .deletedEntryIDs)
    }
}
