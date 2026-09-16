import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: GoalStore
    @State private var tab = 0
    @State private var showNewGoal = false
    @State private var showContribution = false

    var body: some View {
        Group {
            if store.storageBlocked {
                VStack(spacing: 18) {
                    Text("Kayıtlarını koruyoruz 🔒").font(.title.bold())
                    Text(store.dataRecoveryNotice ?? "Kayıt dosyası açılamadı.").multilineTextAlignment(.center)
                    if let url = store.recoveryFileURL {
                        ShareLink(item: url) { Text("Kayıt dosyasını dışa aktar") }
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(WarmBackground())
            } else {
                TabView(selection: $tab) {
                    home.tabItem { Label("Hedeflerim", systemImage: "sparkles") }.tag(0)
                    PurchaseView().tabItem { Label("Bunu alsam?", systemImage: "heart.text.square") }.tag(1)
                    BudgetView().tabItem { Label("Planım", systemImage: "chart.pie.fill") }.tag(2)
                    EntriesView().tabItem { Label("Hareketler", systemImage: "list.bullet.rectangle") }.tag(3)
                    SettingsView().tabItem { Label("Ayarlar", systemImage: "gearshape.fill") }.tag(4)
                }
                .tint(Palette.coral)
                .sheet(isPresented: $showNewGoal) { NewGoalView() }
                .sheet(isPresented: $showContribution) { ContributionView() }
                .safeAreaInset(edge: .top) {
                    if let error = store.storageError {
                        Text(error)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(.red)
                    }
                }
            }
        }
    }

    private var home: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Küçük adımlar, büyük hayaller ✨")
                            .font(.title.bold())
                        Text("Bugün hayaline biraz daha yaklaşalım.")
                            .foregroundStyle(Palette.ink.opacity(0.62))
                    }
                    .padding(.top, 12)

                    if store.state.goals.isEmpty {
                        CozyCard(color: Palette.peach.opacity(0.54)) {
                            VStack(alignment: .leading, spacing: 15) {
                                Text("🌴").font(.system(size: 64))
                                Text("İlk hayalini buraya koyalım")
                                    .font(.title2.bold())
                                Text("Bir yolculuk, küçük bir hediye ya da kocaman bir plan. Nereden başlayalım?")
                                    .foregroundStyle(Palette.ink.opacity(0.7))
                                PillButton(title: "Hedef oluştur", icon: "plus") { showNewGoal = true }
                            }
                        }
                    } else {
                        if let goal = store.selectedGoal {
                            GoalHeroCard(goal: goal)
                            PillButton(title: "Hedefime para ayır", icon: "plus.circle.fill") { showContribution = true }
                        }
                        HStack {
                            Text("Bütün hayallerim").font(.title2.bold())
                            Spacer()
                            Button { showNewGoal = true } label: { Image(systemName: "plus.circle.fill").font(.title2) }
                        }
                        ForEach(store.state.goals) { goal in
                            NavigationLink {
                                GoalDetailView(goalID: goal.id)
                            } label: {
                                HStack(spacing: 14) {
                                    Text(goal.emoji).font(.system(size: 34))
                                        .frame(width: 58, height: 58)
                                        .background(Color(hex: goal.color).opacity(0.36), in: RoundedRectangle(cornerRadius: 17))
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(goal.name).font(.headline)
                                        Text("%\(Int(goal.progress * 100)) tamamlandı")
                                            .font(.subheadline).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                                }
                                .foregroundStyle(Palette.ink)
                                .padding(13)
                                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 22))
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(WarmBackground())
            .navigationBarHidden(true)
        }
    }
}

struct GoalHeroCard: View {
    let goal: Goal
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedProgress = 0.0

    var body: some View {
        CozyCard(color: Color(hex: goal.color).opacity(0.42)) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Şu anki hayalin").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink.opacity(0.65))
                        Text(goal.name).font(.title2.bold())
                        Text("\(goal.size.emoji) \(goal.size.title) hedef")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Palette.surface.opacity(0.64), in: Capsule())
                    }
                    Spacer()
                    Text(goal.emoji).font(.system(size: 57))
                        .rotationEffect(.degrees(animatedProgress > 0 ? -7 : 0))
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.surface.opacity(0.63))
                        Capsule().fill(Palette.coral).frame(width: geo.size.width * animatedProgress)
                    }
                }
                .frame(height: 14)
                .accessibilityLabel("Hedef ilerlemesi yüzde \(Int(goal.progress * 100))")
                HStack(alignment: .lastTextBaseline) {
                    Text(Money.format(goal.savedMinor, currency: goal.currency)).font(.title2.bold())
                    Text("/ \(Money.format(goal.targetMinor, currency: goal.currency))")
                        .font(.subheadline).foregroundStyle(Palette.ink.opacity(0.65))
                    Spacer()
                }
                if goal.completedAt != nil {
                    Text("Bu hayali gerçekleştirdin! 🎉")
                        .font(.subheadline.weight(.semibold))
                } else if goal.paused {
                    Text("Bu hedef şimdilik dinleniyor 🌙")
                        .font(.subheadline.weight(.medium))
                } else if let days = goal.projectedDays {
                    Text(days == 0 ? "Başardın! Bu hayal gerçek oldu 🎉" : "Bu tempoyla yaklaşık \(days) gün kaldı 🌱")
                        .font(.subheadline.weight(.medium))
                } else {
                    Text("Günlük birikim planı ekleyince tahmini tarihi göreceksin 🌱")
                        .font(.subheadline)
                }
            }
        }
        .onAppear { withAnimation(reduceMotion ? nil : .spring(response: 0.8, dampingFraction: 0.75)) { animatedProgress = goal.progress } }
        .onChange(of: goal.progress) { newValue in
            withAnimation(reduceMotion ? nil : .spring(response: 0.8, dampingFraction: 0.75)) { animatedProgress = newValue }
        }
    }
}

struct GoalDetailView: View {
    let goalID: UUID
    @EnvironmentObject private var store: GoalStore
    @Environment(\.dismiss) private var dismiss
    @State private var showContribution = false
    @State private var confirmDelete = false
    @State private var showEdit = false

    var body: some View {
        ScrollView {
            if let goal = store.state.goals.first(where: { $0.id == goalID }) {
                VStack(alignment: .leading, spacing: 18) {
                    GoalHeroCard(goal: goal)
                    if store.selectedGoal?.id != goalID {
                        Button("Ana hedefim yap ⭐️") { store.selectGoal(goalID) }
                            .font(.subheadline.weight(.semibold))
                    }
                    Button(goal.completedAt == nil ? "Hedefi tamamlandı olarak işaretle 🎉" : "Hedefi yeniden aç") {
                        store.setCompleted(goal.completedAt == nil, goalID: goalID)
                    }
                    .font(.subheadline.weight(.semibold))
                    Button("Hedefi düzenle") { showEdit = true }
                        .font(.subheadline.weight(.semibold))
                    PillButton(title: "Biraz para ayır", icon: "plus.circle.fill") { showContribution = true }
                    CozyCard(color: Palette.mint.opacity(0.5)) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Planın 🌿").font(.title3.bold())
                            Text("\(goal.contributionFrequency.title) katkı: \(Money.format(goal.dailyMinor, currency: goal.currency))")
                            if let days = goal.daysUntilDeadline, days <= 0, goal.remainingMinor > 0 {
                                Text("Hedef tarihi geçti. Yeni bir tarih seçebilirsin.")
                            }
                            if let required = goal.requiredDailyMinor {
                                Text("Hedef tarihine yetişmek için: günde \(Money.format(required, currency: goal.currency))")
                            }
                            Text("Kalan: \(Money.format(goal.remainingMinor, currency: goal.currency))")
                            if let date = goal.projectedDate {
                                Text("Tahmini bitiş: \(date.formatted(date: .abbreviated, time: .omitted))")
                            }
                            if let difference = goal.planDifferenceMinor {
                                Text(difference >= 0 ? "Planının \(Money.format(difference, currency: goal.currency)) önündesin ✨" : "Planından \(Money.format(-difference, currency: goal.currency)) geridesin; küçük adımlarla devam 🌱")
                            }
                        }
                    }
                    Text("Hareketler").font(.title2.bold())
                    ForEach(store.state.entries.filter { $0.goalID == goalID }) { entry in
                        HStack {
                            Text(entry.kind == .contribution ? "✨" : "🛍️")
                            VStack(alignment: .leading) {
                                Text(entry.note.isEmpty ? (entry.kind == .contribution ? "Birikim" : "Harcama") : entry.note)
                                Text(entry.date, style: .date).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(Money.format(entry.amountMinor, currency: entry.currency)).bold()
                        }
                        .padding(15).background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
                        .contextMenu { Button("Kaydı sil", role: .destructive) { store.deleteEntry(entry) } }
                    }
                    Button("Hedefi sil", role: .destructive) { confirmDelete = true }
                        .frame(maxWidth: .infinity).padding(.top)
                }
                .padding(20)
            }
        }
        .background(WarmBackground())
        .navigationTitle("Hedefim")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showContribution) { ContributionView(initialGoalID: goalID) }
        .sheet(isPresented: $showEdit) { EditGoalView(goalID: goalID) }
        .confirmationDialog("Bu hedef ve kayıtları silinsin mi?", isPresented: $confirmDelete) {
            Button("Sil", role: .destructive) { store.deleteGoal(goalID); dismiss() }
        }
    }
}
