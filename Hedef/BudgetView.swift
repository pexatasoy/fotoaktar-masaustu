import SwiftUI

struct BudgetView: View {
    @EnvironmentObject private var store: GoalStore
    @State private var income = ""
    @State private var currency = "TRY"
    @State private var fixed = ""
    @State private var essentials = ""
    @State private var buffer = ""
    @State private var allocationPercent = 60.0

    private var draft: Budget {
        Budget(currency: currency, monthlyIncomeMinor: InputAmount.minor(income) ?? 0,
               fixedMinor: InputAmount.minor(fixed) ?? 0,
               essentialsMinor: InputAmount.minor(essentials) ?? 0,
               bufferMinor: InputAmount.minor(buffer) ?? 0,
               allocationPercent: Int(allocationPercent))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Kendine uygun bir plan 🌼").font(.title.bold())
                    Text("Önce yaşam giderlerini koruyalım, sonra hayallerine yer açalım.")
                        .foregroundStyle(Palette.ink.opacity(0.64))
                    Picker("Bütçe para birimi", selection: $currency) {
                        Text("₺ Türk lirası").tag("TRY")
                        Text("$ ABD doları").tag("USD")
                        Text("€ Euro").tag("EUR")
                        Text("£ Sterlin").tag("GBP")
                    }
                    .pickerStyle(.menu)
                    MoneyInput(title: "Aylık net gelir", text: $income, currency: currency)
                    MoneyInput(title: "Sabit zorunlu giderler", text: $fixed, currency: currency)
                    MoneyInput(title: "Değişken temel giderler", text: $essentials, currency: currency)
                    MoneyInput(title: "Kenarda kalsın istediğin pay", text: $buffer, currency: currency)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Kullanılabilir tutarın %\(Int(allocationPercent))'ini hedeflere ayır")
                            .font(.headline)
                        Slider(value: $allocationPercent, in: 0...100, step: 5).tint(Palette.coral)
                        Text("Bu oranı istediğin zaman değiştirebilirsin.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    CozyCard(color: Palette.mint.opacity(0.56)) {
                        VStack(alignment: .leading, spacing: 9) {
                            Text("Senin için olası tempo ✨").font(.title3.bold())
                            Text("Aylık kullanılabilir: \(Money.format(draft.freeMinor, currency: currency))")
                            Text("Önerilen başlangıç: ayda \(Money.format(draft.suggestedMonthlyMinor, currency: currency))")
                                .font(.headline)
                            Text("Yaklaşık günde \(Money.format(draft.suggestedDailyMinor, currency: currency))")
                            Text("Başlangıç aralığı: ayda \(Money.format(draft.suggestedMinMinor, currency: currency)) – \(Money.format(draft.suggestedMaxMinor, currency: currency))")
                                .font(.subheadline)
                            Text("Bu bir öneri; miktarı ve hedeflerini sen belirlersin.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    let allocations = BudgetPlanner.allocations(goals: store.state.goals.filter { $0.currency == currency }, budget: draft)
                    if !allocations.isEmpty {
                        Text("Hedeflere dağılım 🎯").font(.title2.bold())
                        ForEach(allocations) { allocation in
                            CozyCard(color: Color(hex: allocation.goal.color).opacity(0.36)) {
                                VStack(alignment: .leading, spacing: 7) {
                                    Text("\(allocation.goal.emoji) \(allocation.goal.name)").font(.headline)
                                    Text("Önerilen: ayda \(Money.format(allocation.monthlyMinor, currency: currency))")
                                    if let needed = allocation.requiredMonthlyMinor {
                                        Text("Tarihe yetişmek için gereken: \(Money.format(needed, currency: currency))")
                                            .font(.subheadline)
                                        if let shortfall = allocation.shortfallMinor, shortfall > 0 {
                                            Text("Aylık \(Money.format(shortfall, currency: currency)) açık var. Katkıyı, tarihi veya hedef tutarını değiştirebilirsin.")
                                                .font(.footnote.weight(.medium)).foregroundStyle(Palette.ink.opacity(0.75))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if store.state.goals.contains(where: { $0.currency != currency }) {
                        Text("Başka para birimindeki hedefler bu dağılıma katılmadı; kur çevrimi yapılmıyor.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    PillButton(title: "Planımı kaydet", icon: "checkmark") { store.updateBudget(draft) }
                }
                .padding(20)
            }
            .background(WarmBackground())
            .navigationBarHidden(true)
            .onAppear {
                let budget = store.state.budget
                currency = budget.currency
                income = budget.monthlyIncomeMinor == 0 ? "" : "\(Money.decimal(budget.monthlyIncomeMinor))"
                fixed = budget.fixedMinor == 0 ? "" : "\(Money.decimal(budget.fixedMinor))"
                essentials = budget.essentialsMinor == 0 ? "" : "\(Money.decimal(budget.essentialsMinor))"
                buffer = budget.bufferMinor == 0 ? "" : "\(Money.decimal(budget.bufferMinor))"
                allocationPercent = Double(budget.allocationPercent)
            }
        }
    }
}
