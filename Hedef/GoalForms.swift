import SwiftUI
import UIKit

struct NewGoalView: View {
    @EnvironmentObject private var store: GoalStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var emoji = "🌴"
    @State private var target = ""
    @State private var initialSaved = ""
    @State private var daily = ""
    @State private var frequency: ContributionFrequency = .daily
    @State private var currency = "TRY"
    @State private var color = "#FFC3A8"
    @State private var size: GoalSize = .medium
    @State private var priority = 2
    @State private var hasDeadline = false
    @State private var deadline = Calendar.current.date(byAdding: .month, value: 6, to: .now) ?? .now

    private let colors = [("#FFC3A8", "Şeftali"), ("#DCC5FA", "Lila"), ("#B7E8D0", "Nane"), ("#FFE0A3", "Bal"), ("#BBDDF5", "Gökyüzü")]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Hayaline bir isim ver ✨").font(.title2.bold())
                    TextField("Örn. Brezilya tatili", text: $name)
                        .font(.title3).padding(16).background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
                    HStack {
                        Text("Emoji").font(.headline)
                        TextField("🌴", text: $emoji).multilineTextAlignment(.trailing).font(.title)
                            .frame(maxWidth: 90)
                    }
                    HStack(spacing: 12) {
                        ForEach(colors.indices, id: \.self) { index in
                            let option = colors[index]
                            Button { color = option.0 } label: {
                                Circle().fill(Color(hex: option.0)).frame(width: 44, height: 44)
                                    .overlay(Circle().stroke(Palette.ink, lineWidth: color == option.0 ? 3 : 0).padding(3))
                            }
                            .accessibilityLabel("\(option.1) hedef rengi")
                            .accessibilityAddTraits(color == option.0 ? .isSelected : [])
                        }
                    }
                    Picker("Hedef boyutu", selection: $size) {
                        ForEach(GoalSize.allCases) { option in Text("\(option.emoji) \(option.title)").tag(option) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Öncelik", selection: $priority) {
                        Text("Rahat").tag(1)
                        Text("Önemli").tag(2)
                        Text("Öncelikli").tag(3)
                    }
                    .pickerStyle(.segmented)
                    Picker("Para birimi", selection: $currency) {
                        Text("₺ Türk lirası").tag("TRY")
                        Text("$ ABD doları").tag("USD")
                        Text("€ Euro").tag("EUR")
                        Text("£ Sterlin").tag("GBP")
                    }
                    .pickerStyle(.menu)
                    MoneyInput(title: "Hedef tutarı", text: $target, currency: currency)
                    MoneyInput(title: "Şimdiye kadar ayırdığın (isteğe bağlı)", text: $initialSaved, currency: currency)
                    Picker("Katkı sıklığı", selection: $frequency) {
                        ForEach(ContributionFrequency.allCases) { option in Text(option.title).tag(option) }
                    }.pickerStyle(.segmented)
                    MoneyInput(title: "\(frequency.title) ne kadar ayırabilirsin?", text: $daily, currency: currency)
                    Toggle("Bir hedef tarihim var", isOn: $hasDeadline).tint(Palette.coral)
                    if hasDeadline { DatePicker("Hedef tarihi", selection: $deadline, in: Date()..., displayedComponents: .date) }
                    if let targetMinor = InputAmount.minor(target), let dailyMinor = InputAmount.minor(daily), dailyMinor > 0 {
                        let remaining = max(0, targetMinor - (InputAmount.minor(initialSaved) ?? 0))
                        let dailyEquivalent = Double(dailyMinor) / (frequency == .weekly ? 7 : frequency == .monthly ? 30.44 : 1)
                        CozyCard(color: Palette.mint.opacity(0.5)) {
                            Text("Bu tempoyla yaklaşık \(Int(ceil(Double(remaining) / dailyEquivalent))) günde hedefindesin 🌱")
                                .font(.headline)
                        }
                    }
                    if hasDeadline, let targetMinor = InputAmount.minor(target) {
                        let remaining = max(0, targetMinor - (InputAmount.minor(initialSaved) ?? 0))
                        let days = max(1, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: deadline)).day ?? 1)
                        let required = Int64(ceil(Double(remaining) / Double(days)))
                        CozyCard(color: Palette.yellow.opacity(0.5)) {
                            Text("Bu tarihe yetişmek için günde yaklaşık \(Money.format(required, currency: currency)) ayırmalısın ✨")
                                .font(.headline)
                        }
                    }
                    PillButton(title: "Hayalimi oluşturalım", icon: "sparkles") {
                        guard let targetMinor = InputAmount.minor(target), !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        var goal = Goal(name: name.trimmingCharacters(in: .whitespaces), emoji: emoji.isEmpty ? "✨" : emoji, color: color, size: size, targetMinor: targetMinor, dailyMinor: InputAmount.minor(daily) ?? 0, currency: currency, deadline: hasDeadline ? deadline : nil, priority: priority)
                        goal.contributionFrequency = frequency
                        store.addGoal(goal)
                        if let saved = InputAmount.minor(initialSaved) {
                            store.contribute(goalID: goal.id, amountMinor: saved, note: "Başlangıç birikimi")
                        }
                        dismiss()
                    }
                    .disabled(InputAmount.minor(target) == nil || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(20)
            }
            .background(WarmBackground())
            .navigationTitle("Yeni hedef")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { dismiss() } } }
        }
    }
}

struct ContributionView: View {
    @EnvironmentObject private var store: GoalStore
    @Environment(\.dismiss) private var dismiss
    var initialGoalID: UUID? = nil
    var initialAmountMinor: Int64? = nil
    @State private var goalID: UUID?
    @State private var amount = ""
    @State private var note = ""
    @State private var celebrated = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Bir adım daha yaklaştın ✨").font(.title2.bold())
                if !store.state.goals.isEmpty {
                    Picker("Hedef", selection: $goalID) {
                        ForEach(store.state.goals) { goal in
                            Text("\(goal.emoji) \(goal.name)").tag(Optional(goal.id))
                        }
                    }
                    .pickerStyle(.menu)
                }
                MoneyInput(title: "Gerçekten ayırdığın tutar", text: $amount, currency: store.state.goals.first(where: { $0.id == goalID })?.currency ?? "TRY")
                TextField("İstersen bir not ekle", text: $note)
                    .padding(16).background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
                Text("Bu tutar, ancak gerçekten kenara ayırdığında hedefine eklenir.")
                    .font(.footnote).foregroundStyle(.secondary)
                PillButton(title: "Hedefime ekle", icon: "heart.fill") {
                    guard let goalID, let minor = InputAmount.minor(amount) else { return }
                    if store.contribute(goalID: goalID, amountMinor: minor, note: note) {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        celebrated = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { dismiss() }
                    }
                }
                .disabled(goalID == nil || InputAmount.minor(amount) == nil)
                if celebrated { CelebrationView().transition(.scale.combined(with: .opacity)) }
                Spacer()
            }
            .padding(20)
            .background(WarmBackground())
            .navigationTitle("Birikim ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { dismiss() } } }
            .onAppear {
                goalID = initialGoalID ?? store.selectedGoal?.id
                if let initialAmountMinor { amount = "\(Money.decimal(initialAmountMinor))" }
            }
        }
    }
}

struct EditGoalView: View {
    let goalID: UUID
    @EnvironmentObject private var store: GoalStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var emoji = ""
    @State private var target = ""
    @State private var daily = ""
    @State private var frequency: ContributionFrequency = .daily
    @State private var size: GoalSize = .medium
    @State private var priority = 2
    @State private var hasDeadline = false
    @State private var deadline = Date()
    @State private var paused = false

    private var original: Goal? { store.state.goals.first(where: { $0.id == goalID }) }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let goal = original {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Hayalin büyüyebilir, değişebilir 💛").font(.title2.bold())
                        TextField("Hedef adı", text: $name)
                            .padding(16).background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
                        HStack {
                            Text("Emoji").font(.headline)
                            TextField("✨", text: $emoji).multilineTextAlignment(.trailing).font(.title)
                        }
                        Picker("Hedef boyutu", selection: $size) {
                            ForEach(GoalSize.allCases) { option in Text("\(option.emoji) \(option.title)").tag(option) }
                        }
                        .pickerStyle(.segmented)
                        Picker("Öncelik", selection: $priority) {
                            Text("Rahat").tag(1)
                            Text("Önemli").tag(2)
                            Text("Öncelikli").tag(3)
                        }
                        .pickerStyle(.segmented)
                        MoneyInput(title: "Yeni hedef tutarı", text: $target, currency: goal.currency)
                        Picker("Katkı sıklığı", selection: $frequency) {
                            ForEach(ContributionFrequency.allCases) { option in Text(option.title).tag(option) }
                        }.pickerStyle(.segmented)
                        MoneyInput(title: "\(frequency.title) katkı planı", text: $daily, currency: goal.currency)
                        Toggle("Hedef tarihi var", isOn: $hasDeadline).tint(Palette.coral)
                        if hasDeadline { DatePicker("Hedef tarihi", selection: $deadline, displayedComponents: .date) }
                        Toggle("Hedefi duraklat", isOn: $paused).tint(Palette.coral)
                        Text("Biriktirdiğin \(Money.format(goal.savedMinor, currency: goal.currency)) korunur.")
                            .font(.footnote).foregroundStyle(.secondary)
                        PillButton(title: "Değişiklikleri kaydet", icon: "checkmark") {
                            guard let targetMinor = InputAmount.minor(target), !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            var updated = goal
                            updated.name = name.trimmingCharacters(in: .whitespaces)
                            updated.emoji = emoji.isEmpty ? "✨" : emoji
                            updated.size = size
                            updated.priority = priority
                            updated.targetMinor = targetMinor
                            updated.dailyMinor = InputAmount.minor(daily) ?? 0
                            updated.contributionFrequency = frequency
                            updated.deadline = hasDeadline ? deadline : nil
                            updated.paused = paused
                            store.updateGoal(updated)
                            dismiss()
                        }
                        .disabled(InputAmount.minor(target) == nil || name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(20)
                }
            }
            .background(WarmBackground())
            .navigationTitle("Hedefi düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { dismiss() } } }
            .onAppear {
                guard let goal = original else { return }
                name = goal.name
                emoji = goal.emoji
                target = "\(Money.decimal(goal.targetMinor))"
                daily = goal.dailyMinor == 0 ? "" : "\(Money.decimal(goal.dailyMinor))"
                frequency = goal.contributionFrequency
                size = goal.size
                priority = goal.priority
                hasDeadline = goal.deadline != nil
                deadline = goal.deadline ?? .now
                paused = goal.paused
            }
        }
    }
}
