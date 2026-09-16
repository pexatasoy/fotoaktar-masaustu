import AppIntents
import Foundation

struct RecordWalletPaymentIntent: AppIntent {
    static var title: LocalizedStringResource = "Harcamayı Kaydet"
    static var description = IntentDescription("Wallet işleminden gelen tutarı Hedef'e kaydeder ve hedef hatırlatması gönderir.")

    @Parameter(title: "Tutar") var amount: Double
    @Parameter(title: "Para birimi") var currency: String
    @Parameter(title: "İş yeri") var merchant: String?
    @Parameter(title: "İşlem kimliği") var transactionID: String?

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$amount) \(\.$currency) harcamayı kaydet")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount > 0, amount.isFinite else {
            return .result(dialog: "Geçerli bir tutar gerekli.")
        }
        guard let decimal = Decimal(string: String(amount)), let minor = Money.minor(decimal) else { return .result(dialog: "Geçerli bir tutar gerekli.") }
        let cleanCurrency = currency.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanMerchant = merchant?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanID = transactionID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let didRecord = await MainActor.run { () -> Bool in
            let store = GoalStore.shared
            let key = cleanID.flatMap { $0.isEmpty ? nil : "wallet:\($0)" }
            let didRecord = store.recordExpense(goalID: store.selectedGoal?.id, amountMinor: minor, currency: cleanCurrency, note: cleanMerchant?.isEmpty == false ? cleanMerchant! : "Wallet harcaması", sourceKey: key, deduplicateRecent: true)
            if didRecord {
                store.notifyPayment(amountMinor: minor, currency: cleanCurrency)
            }
            return didRecord
        }
        return .result(dialog: didRecord ? "Harcama kaydedildi. Hedefine etkisini uygulamada görebilirsin." : "Bu işlem zaten kayıtlı veya tutar işlenemedi.")
    }
}

struct RemindGoalIntent: AppIntent {
    static var title: LocalizedStringResource = "Hedefimi Hatırlat"
    static var description = IntentDescription("Wallet açıldığında seçili hedefini hatırlatır.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let hasGoal = await MainActor.run { () -> Bool in
            guard GoalStore.shared.selectedGoal != nil else { return false }
            GoalStore.shared.notifyGoalReminder()
            return true
        }
        if hasGoal {
            return .result(dialog: "Hedefini hatırladın! ✨")
        }
        return .result(dialog: "Önce Hedef uygulamasında bir hedef oluştur.")
    }
}

struct AddContributionIntent: AppIntent {
    static var title: LocalizedStringResource = "Birikim Ekle"
    static var description = IntentDescription("Seçili hedefe gerçekten ayrılmış para ekler.")

    @Parameter(title: "Tutar") var amount: Double

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount > 0, amount.isFinite else { return .result(dialog: "Geçerli bir tutar gerekli.") }
        guard let decimal = Decimal(string: String(amount)), let minor = Money.minor(decimal) else { return .result(dialog: "Geçerli bir tutar gerekli.") }
        let success = await MainActor.run { () -> Bool in
            guard let goal = GoalStore.shared.selectedGoal else { return false }
            return GoalStore.shared.contribute(goalID: goal.id, amountMinor: minor, note: "Kestirmeler ile eklendi")
        }
        if success {
            return .result(dialog: "Birikimin hedefine eklendi. Harika!")
        }
        return .result(dialog: "Önce Hedef uygulamasında bir hedef oluştur.")
    }
}

struct HedefShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: RecordWalletPaymentIntent(), phrases: ["\(.applicationName) ile harcamayı kaydet"], shortTitle: "Harcamayı Kaydet", systemImageName: "bag.fill")
        AppShortcut(intent: RemindGoalIntent(), phrases: ["\(.applicationName) hedefimi hatırlat"], shortTitle: "Hedefimi Hatırlat", systemImageName: "sparkles")
        AppShortcut(intent: AddContributionIntent(), phrases: ["\(.applicationName) birikim ekle"], shortTitle: "Birikim Ekle", systemImageName: "plus.circle.fill")
    }
}
