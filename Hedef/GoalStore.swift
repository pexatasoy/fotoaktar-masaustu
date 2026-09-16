import Foundation
import Combine
import UserNotifications
import Security

@MainActor
final class GoalStore: ObservableObject {
    static let shared = GoalStore()
    @Published private(set) var state: AppState
    @Published private(set) var syncStatus: CloudSyncStatus = .unavailable
    @Published private(set) var dataRecoveryNotice: String?
    @Published private(set) var recoveryFileURL: URL?
    @Published private(set) var storageBlocked = false
    @Published private(set) var storageError: String?

    private let folderURL: URL
    private var fileURL: URL?
    private var activeUserID: String?
    private var syncTask: Task<Void, Never>?

    private init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        folderURL = folder
        state = AppState()
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: "com.hedefapp.hedef.apple-user-id",
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
           let data = result as? Data,
           let userID = String(data: data, encoding: .utf8) {
            activate(userID: userID)
        }
    }

    func activate(userID: String) {
        syncTask?.cancel()
        syncTask = nil
        activeUserID = userID
        dataRecoveryNotice = nil
        recoveryFileURL = nil
        storageBlocked = false
        storageError = nil
        let safeName = Data(userID.utf8).base64EncodedString().replacingOccurrences(of: "/", with: "_")
        let url = folderURL.appendingPathComponent("hedef-\(safeName).json")
        let legacy = folderURL.appendingPathComponent("hedef-data.json")
        if !FileManager.default.fileExists(atPath: url.path), FileManager.default.fileExists(atPath: legacy.path) {
            try? FileManager.default.moveItem(at: legacy, to: url)
        }
        fileURL = url
        if let data = try? Data(contentsOf: url) {
            if let decoded = try? JSONDecoder().decode(AppState.self, from: data) {
                state = decoded
                dataRecoveryNotice = nil
                recoveryFileURL = nil
                storageBlocked = false
            } else {
                let backup = folderURL.appendingPathComponent("hedef-kurtarma-\(UUID().uuidString).json")
                do {
                    try FileManager.default.copyItem(at: url, to: backup)
                    dataRecoveryNotice = "Okunamayan kayıtların yedeği cihazda korundu: \(backup.lastPathComponent)"
                    recoveryFileURL = backup
                    storageBlocked = false
                    state = AppState()
                } catch {
                    dataRecoveryNotice = "Kayıt dosyası okunamadı ve yedeklenemedi. Yeni kayıtlar geçici olarak kapatıldı."
                    recoveryFileURL = url
                    storageBlocked = true
                    fileURL = nil
                    state = AppState()
                }
            }
        } else {
            state = AppState()
        }
        if fileURL != nil { syncNow() }
    }

    func stopSync() {
        syncTask?.cancel()
        syncTask = nil
        fileURL = nil
        activeUserID = nil
        state = AppState()
        syncStatus = .unavailable
        dataRecoveryNotice = nil
        recoveryFileURL = nil
        storageBlocked = false
        storageError = nil
    }

    func syncNow() {
        #if HEDEF_LOCAL_ONLY
        syncStatus = .unavailable
        return
        #endif
        guard let targetFileURL = fileURL, let activeUserID else { return }
        syncTask?.cancel()
        let snapshot = state
        syncStatus = .syncing
        syncTask = Task {
            do {
                let remote = try await CloudSyncService.shared.sync(local: snapshot, userID: activeUserID)
                guard !Task.isCancelled, self.activeUserID == activeUserID, self.fileURL == targetFileURL else { return }
                let merged = await CloudSyncService.shared.merge(local: state, remote: remote)
                guard !Task.isCancelled, self.activeUserID == activeUserID, self.fileURL == targetFileURL else { return }
                state = merged
                persist(sync: false, touchTimestamp: false)
                if let storageError {
                    syncStatus = .failed(storageError)
                    return
                }
                syncStatus = .ready
                if merged.updatedAt > remote.updatedAt { scheduleSync() }
            } catch {
                guard !Task.isCancelled else { return }
                syncStatus = .failed(error.localizedDescription)
            }
        }
    }

    private func scheduleSync() {
        guard fileURL != nil else { return }
        syncTask?.cancel()
        syncTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            syncNow()
        }
    }

    var selectedGoal: Goal? {
        state.goals.first(where: { $0.id == state.selectedGoalID }) ?? state.goals.first
    }

    func addGoal(_ goal: Goal) {
        state.goals.append(goal)
        if state.selectedGoalID == nil { state.selectedGoalID = goal.id }
        persist()
    }

    func selectGoal(_ id: UUID) { state.selectedGoalID = id; persist() }

    func updateGoal(_ goal: Goal) {
        guard let index = state.goals.firstIndex(where: { $0.id == goal.id }) else { return }
        state.goals[index] = goal
        state.goals[index].updatedAt = .now
        persist()
    }

    func setCompleted(_ completed: Bool, goalID: UUID) {
        guard let index = state.goals.firstIndex(where: { $0.id == goalID }) else { return }
        state.goals[index].completedAt = completed ? .now : nil
        state.goals[index].updatedAt = .now
        persist()
    }

    func deleteGoal(_ id: UUID) {
        state.deletedGoalIDs[id.uuidString] = .now
        for entry in state.entries where entry.goalID == id { state.deletedEntryIDs[entry.id.uuidString] = .now }
        state.goals.removeAll { $0.id == id }
        state.entries.removeAll { $0.goalID == id }
        if state.selectedGoalID == id { state.selectedGoalID = state.goals.first?.id }
        persist()
    }

    @discardableResult
    func contribute(goalID: UUID, amountMinor: Int64, note: String = "", sourceKey: String? = nil) -> Bool {
        guard amountMinor > 0, let index = state.goals.firstIndex(where: { $0.id == goalID }) else { return false }
        if let sourceKey, state.entries.contains(where: { $0.sourceKey == sourceKey }) { return false }
        guard amountMinor <= Int64.max - state.goals[index].savedMinor else { return false }
        state.goals[index].savedMinor += amountMinor
        state.goals[index].updatedAt = .now
        state.entries.insert(MoneyEntry(goalID: goalID, kind: .contribution, amountMinor: amountMinor, currency: state.goals[index].currency, note: note, sourceKey: sourceKey), at: 0)
        persist()
        return true
    }

    @discardableResult
    func recordExpense(goalID: UUID?, amountMinor: Int64, currency: String, note: String, category: ExpenseCategory = .other, date: Date = .now, sourceKey: String? = nil, deduplicateRecent: Bool = false, expenseSource: ExpenseSource = .dailyBudget) -> Bool {
        guard amountMinor > 0 else { return false }
        if expenseSource == .goalSavings {
            guard let goalID, let goal = state.goals.first(where: { $0.id == goalID }), goal.currency == currency, goal.savedMinor >= amountMinor else { return false }
        }
        if let sourceKey, state.entries.contains(where: { $0.sourceKey == sourceKey }) { return false }
        if deduplicateRecent && state.entries.contains(where: {
            $0.kind == .expense && $0.amountMinor == amountMinor && $0.currency == currency && $0.note == note && $0.date.timeIntervalSinceNow > -20
        }) { return false }
        var entry = MoneyEntry(goalID: goalID, kind: .expense, amountMinor: amountMinor, currency: currency, category: category, note: note, date: date, sourceKey: sourceKey)
        entry.expenseSource = expenseSource
        state.entries.insert(entry, at: 0)
        if expenseSource == .goalSavings, let goalID { recalculateSavings(for: goalID) }
        persist()
        return true
    }

    func deleteEntry(_ entry: MoneyEntry) {
        state.deletedEntryIDs[entry.id.uuidString] = .now
        state.entries.removeAll { $0.id == entry.id }
        if let goalID = entry.goalID { recalculateSavings(for: goalID) }
        persist()
    }

    func updateEntry(_ changed: MoneyEntry) {
        guard let oldIndex = state.entries.firstIndex(where: { $0.id == changed.id }) else { return }
        let old = state.entries[oldIndex]
        guard changed.amountMinor > 0 else { return }
        if changed.kind == .expense && changed.expenseSource == .goalSavings {
            guard let goalID = changed.goalID, let goal = state.goals.first(where: { $0.id == goalID }), goal.currency == changed.currency else { return }
            let previousDebit = old.expenseSource == .goalSavings ? old.amountMinor : 0
            guard changed.amountMinor <= goal.savedMinor + previousDebit else { return }
        }
        var updated = changed
        updated.updatedAt = .now
        state.entries[oldIndex] = updated
        if let goalID = old.goalID { recalculateSavings(for: goalID) }
        persist()
    }

    func updateBudget(_ budget: Budget) { state.budget = budget; state.budget.updatedAt = .now; persist() }

    func setNotifications(_ enabled: Bool) {
        guard enabled else {
            state.notificationsEnabled = false
            persist()
            return
        }
        Task {
            let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            state.notificationsEnabled = granted
            persist()
        }
    }

    func setNotificationAmounts(_ enabled: Bool) { state.showAmountsInNotifications = enabled; persist() }

    func setWalletReminderFrequency(_ frequency: WalletReminderFrequency) {
        state.walletReminderFrequency = frequency
        persist()
    }

    func notifyGoalReminder() {
        guard state.notificationsEnabled, state.walletReminderFrequency != .off, let goal = selectedGoal else { return }
        if state.walletReminderFrequency == .daily,
           let last = state.lastWalletReminderAt,
           Calendar.current.isDateInToday(last) { return }
        let content = UNMutableNotificationContent()
        content.title = "\(goal.emoji) \(goal.name) seni bekliyor"
        content.body = "Bugünkü kararını verirken hayalini de hatırla. Şimdiden %\(Int(goal.progress * 100)) yol aldın ✨"
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)))
        state.lastWalletReminderAt = .now
        persist()
    }

    func sendTestNotification() {
        guard state.notificationsEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "Hedef yanında! ✨"
        content.body = "Bildirimlerin çalışıyor. Şimdi Kestirmeler otomasyonunu kurabilirsin."
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)))
    }

    func scheduleWaitingReminder(item: String, hours: Int) {
        Task {
            let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Hâlâ aklında mı? 💭"
            content.body = item.isEmpty ? "Beklettiğin alışverişe yeniden, sakin sakin bakabilirsin." : "\(item) hâlâ sana iyi bir fikir gibi geliyor mu?"
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(hours * 3600), repeats: false)
            try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger))
        }
    }

    func notifyPayment(amountMinor: Int64, currency: String) {
        guard state.notificationsEnabled else { return }
        let goal = selectedGoal
        let content = UNMutableNotificationContent()
        content.title = goal.map { "\($0.emoji) \($0.name) hedefin aklında mı?" } ?? "Hedefini hatırla ✨"
        if state.showAmountsInNotifications {
            if let goal, goal.currency == currency, let days = GoalMath.delayedDays(ifTakenFromPlan: amountMinor, goal: goal) {
                content.body = "\(Money.format(amountMinor, currency: currency)) harcadın. Birikim payından çıktıysa hedefin yaklaşık \(days) gün ötelenebilir. 💛"
            } else {
                content.body = "\(Money.format(amountMinor, currency: currency)) harcadın. Hedefine etkisini birlikte gözden geçirelim. 💛"
            }
        } else {
            content.body = "Alışverişini kaydettik. Hedefine etkisini görmek için dokun."
        }
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)))
    }

    func clearAll() {
        let now = Date()
        for goal in state.goals { state.deletedGoalIDs[goal.id.uuidString] = now }
        for entry in state.entries { state.deletedEntryIDs[entry.id.uuidString] = now }
        state.goals = []
        state.entries = []
        state.budget = Budget()
        state.selectedGoalID = nil
        persist()
    }

    func deleteAccountData() async throws {
        guard let activeUserID else { return }
        #if HEDEF_LOCAL_ONLY
        clearAll()
        if let fileURL { try FileManager.default.removeItem(at: fileURL) }
        stopSync()
        return
        #endif
        syncTask?.cancel()
        let remote = try await CloudSyncService.shared.sync(local: state, userID: activeUserID)
        state = await CloudSyncService.shared.merge(local: state, remote: remote)
        clearAll()
        if let storageError { throw NSError(domain: "HedefStorage", code: 1, userInfo: [NSLocalizedDescriptionKey: storageError]) }
        syncTask?.cancel()
        _ = try await CloudSyncService.shared.sync(local: state, userID: activeUserID)
        if let fileURL { try FileManager.default.removeItem(at: fileURL) }
        stopSync()
    }

    func exportFile() throws -> URL {
        let formatter = ISO8601DateFormatter()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("hedef-verilerim-\(formatter.string(from: .now)).json")
        let data = try JSONEncoder().encode(state)
        try data.write(to: url, options: .atomic)
        return url
    }

    private func recalculateSavings(for goalID: UUID) {
        guard let index = state.goals.firstIndex(where: { $0.id == goalID }) else { return }
        state.goals[index].savedMinor = GoalMath.savingsBalance(entries: state.entries, goalID: goalID)
        state.goals[index].updatedAt = .now
    }

    private func persist(sync: Bool = true, touchTimestamp: Bool = true) {
        if touchTimestamp { state.updatedAt = .now }
        guard let fileURL else { return }
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: fileURL, options: .atomic)
            storageError = nil
            if sync { scheduleSync() }
        } catch {
            storageError = "Kayıt cihazda saklanamadı: \(error.localizedDescription)"
        }
    }
}
