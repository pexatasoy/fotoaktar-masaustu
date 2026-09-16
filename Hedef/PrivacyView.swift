import SwiftUI

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Verilerin sana ait 🔒").font(.title.bold())
                section("Hesabın", "Apple ile Giriş Yap yalnızca hesabını tanımamız için kullanılır. E-posta adresini istemiyoruz.")
                section("Hedeflerin ve hareketlerin", "Hedeflerini, birikimlerini, bütçeni ve harcamalarını cihazında saklarız. iCloud kullanılabiliyorsa bunlar Apple'ın özel CloudKit alanında eşitlenir.")
                section("Wallet ve Kestirmeler", "Yalnızca sen otomasyon kurarsan seçilen işlem tutarı, para birimi ve isteğe bağlı iş yeri adı uygulamaya gelir. Tüm ödeme geçmişini kendiliğinden okuyamayız.")
                section("Bildirimler", "Hatırlatmaları kapatabilir, Wallet hatırlatma sıklığını seçebilir ve kilit ekranında tutar gösterimini yönetebilirsin.")
                section("Kontrol sende", "Ayarlar'dan verilerini dışa aktarabilir veya hesabınla birlikte silebilirsin. Reklam ağı ya da üçüncü taraf analitik kullanmıyoruz.")
                Text("Hedef gerçek para tutmaz ve banka hesabından transfer yapmaz.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .background(WarmBackground())
        .navigationTitle("Gizlilik")
    }

    private func section(_ title: String, _ body: String) -> some View {
        CozyCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline)
                Text(body).font(.subheadline).foregroundStyle(Palette.ink.opacity(0.75))
            }
        }
    }
}
