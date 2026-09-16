import SwiftUI

struct EntriesView: View {
    @EnvironmentObject private var store: GoalStore
    @State private var showExpense = false
    @State private var editing: MoneyEntry?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    Text("Küçük adımlarının izi ✨").font(.title.bold())
                    Text("Ayırdığın parayı ve harcamalarını burada görebilirsin.")
                        .foregroundStyle(Palette.ink.opacity(0.65))
                    PillButton(title: "Harcama ekle", icon: "plus") { showExpense = true }
                    if store.state.entries.isEmpty {
                        CozyCard(color: Palette.peach.opacity(0.42)) {
                            Text("Henüz hareket yok. İlk küçük adımı attığında burada olacak 🌱")
                        }
                    }
                    ForEach(store.state.entries.sorted(by: { $0.date > $1.date })) { entry in
                        Button { editing = entry } label: {
                            HStack(spacing: 13) {
                                Text(entry.kind == .contribution ? "✨" : (entry.category ?? .other).emoji)
                                    .font(.title2).frame(width: 48, height: 48)
                                    .background(Palette.peach.opacity(0.4), in: RoundedRectangle(cornerRadius: 15))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.note.isEmpty ? (entry.kind == .contribution ? "Birikim" : "Harcama") : entry.note)
                                        .font(.headline)
                                    Text(entry.date, style: .date).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(entry.kind == .contribution ? "+" : "−")\(Money.format(entry.amountMinor, currency: entry.currency))")
                                    .font(.subheadline.bold())
                            }
                            .foregroundStyle(Palette.ink)
                            .padding(14)
                            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 19))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .background(WarmBackground())
            .navigationBarHidden(true)
            .sheet(isPresented: $showExpense) { ExpenseFormView() }
            .sheet(item: $editing) { entry in EntryEditView(entry: entry) }
        }
    }
}

struct ExpenseFormView: View {
    @EnvironmentObject private var store: GoalStore
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var note = ""
    @State private var currency = "TRY"
    @State private var category: ExpenseCategory = .shopping
    @State private var date = Date()
    @State private var source: ExpenseSource = .dailyBudget
    @State private var goalID: UUID?
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Harcamayı kaydedelim 🛍️").font(.title2.bold())
                    Picker("Para birimi", selection: $currency) {
                        Text("₺ TRY").tag("TRY")
                        Text("$ USD").tag("USD")
                        Text("€ EUR").tag("EUR")
                        Text("£ GBP").tag("GBP")
                    }.pickerStyle(.menu)
                    MoneyInput(title: "Tutar", text: $amount, currency: currency)
                    TextField("Ne aldın?", text: $note)
                        .padding(16).background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
                    Picker("Kategori", selection: $category) {
                        ForEach(ExpenseCategory.allCases) { option in Text("\(option.emoji) \(option.title)").tag(option) }
                    }.pickerStyle(.menu)
                    DatePicker("Tarih", selection: $date, displayedComponents: .date)
                    Picker("Nereden karşılandı?", selection: $source) {
                        Text("Günlük bütçemden").tag(ExpenseSource.dailyBudget)
                        Text("Hedef birikimimden").tag(ExpenseSource.goalSavings)
                    }.pickerStyle(.segmented)
                    if source == .goalSavings {
                        Picker("Hangi hedeften?", selection: $goalID) {
                            ForEach(store.state.goals.filter { $0.currency == currency }) { goal in
                                Text("\(goal.emoji) \(goal.name)").tag(Optional(goal.id))
                            }
                        }.pickerStyle(.menu)
                    }
                    Text(source == .dailyBudget ? "Günlük bütçenden yapılan harcama hedefine ayrılmış parayı azaltmaz." : "Hedef birikiminden karşılanan tutar, birikmiş toplamdan düşer.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if let errorText { Text(errorText).foregroundStyle(.red).font(.footnote) }
                    PillButton(title: "Harcamayı kaydet", icon: "checkmark") {
                        guard let minor = InputAmount.minor(amount) else { return }
                        if store.recordExpense(goalID: source == .goalSavings ? goalID : nil, amountMinor: minor, currency: currency, note: note, category: category, date: date, expenseSource: source) {
                            dismiss()
                        } else { errorText = "Hedef ve tutarı kontrol et. Birikimden ayırdığından fazlasını harcayamazsın." }
                    }
                    .disabled(InputAmount.minor(amount) == nil || (source == .goalSavings && goalID == nil))
                }
                .padding(20)
            }
            .background(WarmBackground())
            .navigationTitle("Yeni harcama")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { dismiss() } } }
            .onAppear { currency = store.state.budget.currency }
            .onChange(of: currency) { _ in goalID = store.state.goals.first(where: { $0.currency == currency })?.id }
            .onChange(of: source) { _ in goalID = store.state.goals.first(where: { $0.currency == currency })?.id }
        }
    }
}

struct EntryEditView: View {
    let entry: MoneyEntry
    @EnvironmentObject private var store: GoalStore
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var note = ""
    @State private var date = Date()
    @State private var category: ExpenseCategory = .other
    @State private var confirmDelete = false
    @State private var source: ExpenseSource = .dailyBudget
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(entry.kind == .contribution ? "Birikimi düzelt ✨" : "Harcamayı düzelt 🛍️")
                        .font(.title2.bold())
                    MoneyInput(title: "Tutar", text: $amount, currency: entry.currency)
                    TextField("Not", text: $note).padding(16).background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
                    if entry.kind == .expense {
                        Picker("Kategori", selection: $category) {
                            ForEach(ExpenseCategory.allCases) { option in Text("\(option.emoji) \(option.title)").tag(option) }
                        }.pickerStyle(.menu)
                        if entry.goalID != nil {
                            Picker("Nereden karşılandı?", selection: $source) {
                                Text("Günlük bütçemden").tag(ExpenseSource.dailyBudget)
                                Text("Hedef birikimimden").tag(ExpenseSource.goalSavings)
                            }.pickerStyle(.segmented)
                        }
                    }
                    DatePicker("Tarih", selection: $date, displayedComponents: .date)
                    if let errorText { Text(errorText).foregroundStyle(.red).font(.footnote) }
                    PillButton(title: "Değişiklikleri kaydet", icon: "checkmark") {
                        guard let minor = InputAmount.minor(amount) else { return }
                        var changed = entry
                        changed.amountMinor = minor
                        changed.note = note
                        changed.date = date
                        changed.category = entry.kind == .expense ? category : nil
                        changed.expenseSource = source
                        store.updateEntry(changed)
                        if store.state.entries.first(where: { $0.id == entry.id })?.amountMinor == minor { dismiss() }
                        else { errorText = "Tutar hedefte birikenden fazla olamaz." }
                    }
                    .disabled(InputAmount.minor(amount) == nil)
                    Button("Bu kaydı sil", role: .destructive) { confirmDelete = true }
                        .frame(maxWidth: .infinity).padding(.top)
                }.padding(20)
            }
            .background(WarmBackground())
            .navigationTitle("Hareketi düzenle")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { dismiss() } } }
            .confirmationDialog("Kayıt silinsin mi?", isPresented: $confirmDelete) {
                Button("Sil", role: .destructive) { store.deleteEntry(entry); dismiss() }
            }
            .onAppear {
                amount = "\(Money.decimal(entry.amountMinor))"
                note = entry.note
                date = entry.date
                category = entry.category ?? .other
                source = entry.expenseSource
            }
        }
    }
}
