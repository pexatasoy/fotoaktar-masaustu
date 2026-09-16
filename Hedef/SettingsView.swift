import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: GoalStore
    @EnvironmentObject private var account: AccountManager
    @State private var showDelete = false
    @State private var showAccountDelete = false
    @State private var exportURL: URL?
    @State private var actionError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Küçük ayarlar ⚙️").font(.title.bold())
                    CozyCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Toggle("Alışveriş sonrası bildirim", isOn: Binding(get: { store.state.notificationsEnabled }, set: { store.setNotifications($0) }))
                            Toggle("Bildirimde tutarı göster", isOn: Binding(get: { store.state.showAmountsInNotifications }, set: { store.setNotificationAmounts($0) }))
                                .disabled(!store.state.notificationsEnabled)
                            Picker("Wallet hatırlatması", selection: Binding(get: { store.state.walletReminderFrequency }, set: { store.setWalletReminderFrequency($0) })) {
                                ForEach(WalletReminderFrequency.allCases) { option in Text(option.title).tag(option) }
                            }
                            .disabled(!store.state.notificationsEnabled)
                        }
                        .tint(Palette.coral)
                    }
                    NavigationLink { ShortcutsSetupView() } label: {
                        CozyCard(color: Palette.lilac.opacity(0.45)) {
                            HStack {
                                Text("📲  Wallet ve Kestirmeler kurulumu").font(.headline)
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                        }
                    }
                    .foregroundStyle(Palette.ink)
                    NavigationLink { PrivacyView() } label: {
                        CozyCard(color: Palette.mint.opacity(0.42)) {
                            HStack {
                                Text("🔒  Gizlilik ve verilerim").font(.headline)
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                        }
                    }
                    .foregroundStyle(Palette.ink)
                    CozyCard(color: Palette.peach.opacity(0.45)) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Gizliliğin önemli 🔒").font(.headline)
                            Text(account.isLocalDemo ? "Bu deneme paketindeki kayıtların yalnızca bu iPhone'da saklanır. Kestirmeler yalnızca sen kurarsan çalışır." : "Kayıtların cihazında ve iCloud açıksa yalnızca senin özel iCloud alanında saklanır. Kestirmeler yalnızca sen kurarsan çalışır. Otomatik banka bağlantısı yok.")
                                .font(.subheadline)
                        }
                    }
                    CozyCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Hesabım ☁️").font(.headline)
                            if let notice = store.dataRecoveryNotice {
                                Text(notice).font(.footnote).foregroundStyle(Palette.coral)
                            }
                            switch store.syncStatus {
                            case .ready: Text("iCloud eşitlemesi güncel").foregroundStyle(.green)
                            case .syncing: Text("Eşitleniyor…")
                            case .unavailable: Text("iCloud eşitlemesi kullanılmıyor; kayıtların cihazında kalır.")
                            case .failed(let message): Text("Eşitleme bekliyor: \(message)").foregroundStyle(Palette.coral)
                            }
                            if !account.isLocalDemo { Button("Şimdi eşitle") { store.syncNow() } }
                            Button(account.isLocalDemo ? "Denemeden çık" : "Çıkış yap") { account.signOut() }
                        }
                    }
                    CozyCard(color: Palette.mint.opacity(0.4)) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Verilerim 📦").font(.headline)
                            if let exportURL {
                                ShareLink(item: exportURL) { Label("JSON dosyamı paylaş", systemImage: "square.and.arrow.up") }
                            } else {
                                Button("Verilerimi dışa aktar") {
                                    do { exportURL = try store.exportFile() }
                                    catch { actionError = error.localizedDescription }
                                }
                            }
                        }
                    }
                    Button("Bütün hedef ve hareketlerimi sil", role: .destructive) { showDelete = true }
                        .frame(maxWidth: .infinity).padding(.top)
                    Button(account.isLocalDemo ? "Yerel deneme verilerimi sil" : "Hesabımı ve tüm verilerimi sil", role: .destructive) { showAccountDelete = true }
                        .frame(maxWidth: .infinity)
                    if let actionError { Text(actionError).font(.footnote).foregroundStyle(Palette.coral) }
                }
                .padding(20)
            }
            .background(WarmBackground())
            .navigationBarHidden(true)
            .confirmationDialog("Tüm hedefler ve kayıtlar bu cihazdan ve iCloud'dan silinsin mi?", isPresented: $showDelete) {
                Button("Tümünü sil", role: .destructive) { store.clearAll() }
            }
            .confirmationDialog("Hesap ve iCloud kayıtları silinsin mi? Bu işlem geri alınamaz.", isPresented: $showAccountDelete) {
                Button("Hesabımı sil", role: .destructive) {
                    Task {
                        do { try await account.deleteAccount() }
                        catch { actionError = "Silme tamamlanamadı: \(error.localizedDescription)" }
                    }
                }
            }
        }
    }
}

struct ShortcutsSetupView: View {
    @EnvironmentObject private var store: GoalStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Ödeme anında hedefini hatırla 💛").font(.title2.bold())
                Text("Bunun için iPhone'undaki Kestirmeler uygulamasında iki kişisel otomasyon kurabilirsin. Kart bilgilerin Hedef'e verilmez.")
                step("1", "Wallet açılınca", "Kestirmeler → Otomasyon → Uygulama → Wallet → Açıldığında. Eylem olarak Hedef'in ‘Hedefimi Hatırlat’ eylemini seç.")
                step("2", "Ödemeden sonra", "Kestirmeler → Otomasyon → İşlem → kullanacağın kart. Eylem olarak Hedef'in ‘Harcamayı Kaydet’ eylemini seç; işlem tutarı ve para birimini Kestirme girdisinden bağla.")
                step("3", "Bir kez dene", "Bildirim iznini aç. Desteklenen kartla gerçek bir temassız işlem yaptığında bildirimi ve Hareketler kaydını kontrol et.")
                PillButton(title: "Test bildirimi gönder", icon: "bell.badge") { store.sendTestNotification() }
                    .disabled(!store.state.notificationsEnabled)
                Button("Kestirmeler uygulamasını aç") {
                    if let url = URL(string: "shortcuts://") { UIApplication.shared.open(url) }
                }
                .font(.headline)
                CozyCard(color: Palette.yellow.opacity(0.55)) {
                    Text("iOS ve kart desteğine göre tetikleme değişebilir. Çalışmazsa alışverişi ‘Bunu alsam?’ ekranından kaydedebilirsin.")
                        .font(.subheadline)
                }
            }
            .padding(20)
        }
        .background(WarmBackground())
        .navigationTitle("Kestirmeler")
    }

    private func step(_ number: String, _ title: String, _ detail: String) -> some View {
        CozyCard {
            HStack(alignment: .top, spacing: 13) {
                Text(number).font(.headline).foregroundStyle(.white)
                    .frame(width: 32, height: 32).background(Palette.coral, in: Circle())
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.headline)
                    Text(detail).font(.subheadline).foregroundStyle(Palette.ink.opacity(0.75))
                }
            }
        }
    }
}
