import SwiftUI

struct PurchaseView: View {
    @EnvironmentObject private var store: GoalStore
    @State private var price = ""
    @State private var item = ""
    @State private var selectedGoalID: UUID?
    @State private var fromPlan = false
    @State private var decision: String?
    @State private var showContribution = false
    @State private var category: ExpenseCategory = .shopping
    @State private var needLevel = 1
    @State private var purchaseRecorded = false

    private var goal: Goal? { store.state.goals.first(where: { $0.id == selectedGoalID }) ?? store.selectedGoal }
    private var priceMinor: Int64? { InputAmount.minor(price) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Bunu alsam mı? 🛍️").font(.title.bold())
                    Text("Bir saniye durup hayaline etkisine bakalım.")
                        .foregroundStyle(Palette.ink.opacity(0.64))
                    TextField("Aklındaki şey ne?", text: $item)
                        .padding(16).background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
                    MoneyInput(title: "Fiyatı", text: $price, currency: goal?.currency ?? "TRY")
                    Picker("Kategori", selection: $category) {
                        ForEach(ExpenseCategory.allCases) { option in Text("\(option.emoji) \(option.title)").tag(option) }
                    }
                    .pickerStyle(.menu)
                    Picker("Bu senin için", selection: $needLevel) {
                        Text("İhtiyaç").tag(0)
                        Text("İstek").tag(1)
                        Text("Emin değilim").tag(2)
                    }
                    .pickerStyle(.segmented)
                    if !store.state.goals.isEmpty {
                        Picker("Hangi hedefle karşılaştıralım?", selection: $selectedGoalID) {
                            ForEach(store.state.goals) { goal in
                                Text("\(goal.emoji) \(goal.name)").tag(Optional(goal.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    if let goal, let priceMinor {
                        CozyCard(color: Palette.lilac.opacity(0.55)) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("\(goal.emoji) \(goal.name) açısından").font(.title3.bold())
                                Text("Bu fiyat, hedefinin %\(GoalMath.fractionOfTarget(priceMinor: priceMinor, goal: goal).formatted(.number.precision(.fractionLength(2))))'si.")
                                if let days = GoalMath.gainedDays(ifSaved: priceMinor, goal: goal) {
                                    Text("Bu parayı gerçekten hedefine ayırırsan yaklaşık \(days) gün öne geçebilirsin ✨")
                                }
                            }
                        }
                        Toggle("Bu alışverişi planlı birikimimden karşılayacağım", isOn: $fromPlan)
                            .tint(Palette.coral)
                        if fromPlan, let days = GoalMath.delayedDays(ifTakenFromPlan: priceMinor, goal: goal) {
                            CozyCard(color: Palette.peach.opacity(0.6)) {
                                Text("Birikim payından çıkarsa hedefin yaklaşık \(days) gün ötelenebilir. Karar yine senin 💛")
                                    .font(.headline)
                            }
                        } else {
                            Text("Günlük harcama bütçenden çıkıyorsa hedef tarihin değişmez.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        CozyCard {
                            VStack(alignment: .leading, spacing: 9) {
                                Text("Kendine minicik sor 💭").font(.headline)
                                Text("Buna gerçekten ihtiyacım var mı?")
                                Text("Bir hafta sonra da isteyecek miyim?")
                                Text("Elimde benzer bir şey var mı?")
                            }
                        }
                        HStack(spacing: 10) {
                            choice("Alacağım", emoji: "🛍️") {
                                guard !purchaseRecorded else { return }
                                purchaseRecorded = store.recordExpense(goalID: goal.id, amountMinor: priceMinor, currency: goal.currency, note: item.isEmpty ? "Alışveriş" : item, category: category)
                                decision = purchaseRecorded ? "Keyifle kullan! Harcamanı kaydettim 💛" : "Bu kayıt eklenemedi. Bir daha deneyebilirsin."
                            }
                            choice("Bekleteceğim", emoji: "⏳") { decision = "Biraz zaman tanımak da güzel bir karar 🌿" }
                        }
                        HStack(spacing: 10) {
                            choice("Vazgeçtim", emoji: "🌱") { decision = "Dilersen bu tutarı gerçekten ayırdığında hedefine ekleyebilirsin." }
                            choice("Hedefe ayırdım", emoji: "✨") { showContribution = true }
                        }
                        if let decision { Text(decision).font(.headline).frame(maxWidth: .infinity).padding().background(Palette.mint.opacity(0.5), in: RoundedRectangle(cornerRadius: 18)) }
                        HStack(spacing: 10) {
                            choice("24 saat sonra hatırlat", emoji: "🔔") {
                                store.scheduleWaitingReminder(item: item, hours: 24)
                                decision = "Yarın yeniden bakarsın 🌿"
                            }
                            choice("48 saat sonra", emoji: "🌙") {
                                store.scheduleWaitingReminder(item: item, hours: 48)
                                decision = "İki gün sonra hatırlatacağım 💛"
                            }
                        }
                    } else if store.state.goals.isEmpty {
                        Text("Karşılaştırmak için önce bir hedef oluştur 🌈").foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .background(WarmBackground())
            .navigationBarHidden(true)
            .onAppear { selectedGoalID = selectedGoalID ?? store.selectedGoal?.id }
            .onChange(of: price) { _ in purchaseRecorded = false; decision = nil }
            .onChange(of: item) { _ in purchaseRecorded = false; decision = nil }
            .sheet(isPresented: $showContribution) { ContributionView(initialGoalID: goal?.id, initialAmountMinor: priceMinor) }
        }
    }

    private func choice(_ title: String, emoji: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("\(emoji) \(title)")
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 17))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.ink)
    }
}
