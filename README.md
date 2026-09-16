# Hedef — iPhone uygulaması

Hedef, hedef odaklı birikim ve harcama kararı uygulamasıdır. Ürün kapsamı [kapsam planında](../ios-hedef-uygulamasi-kapsam-plani.md) sabittir.

## Kaynakta tamamlanan modüller

- Apple ile Giriş Yap, hesaba göre ayrı yerel kayıt, özel CloudKit alanında eşitleme ve hesap/veri silme.
- Birden fazla küçük/orta/büyük hedef; günlük/haftalık/aylık katkı, tutar, para birimi, tarih, öncelik, düzenleme, duraklatma ve tamamlama.
- Gerçek birikim ve harcama kayıtları; günlük bütçe/hedef birikimi kaynağı seçimi, hareket düzenleme, silme ve JSON dışa aktarma.
- Hedef yüzdesi, gereken günlük katkı, tahmini bitiş ve alışverişin koşullu gün etkisi.
- Gelir, zorunlu giderler, güvenlik payı, öneri aralığı ve birden çok hedefe bütçe dağılımı.
- “Bunu alsam?” karar akışı, ihtiyaç/istek seçimi ve 24/48 saatlik bekletme hatırlatıcısı.
- Wallet açılışı ve temassız işlem sonrası için App Intents, kurulum ekranı ve bildirim tercihleri.
- Sıcak renk paleti, açık/koyu görünüm, uygulama simgesi, ilerleme ve kutlama animasyonları.

## Derleme ve test

macOS üzerinde Xcode ve XcodeGen ile:

```sh
xcodegen generate
xcodebuild -project Hedef.xcodeproj -scheme Hedef -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

`.github/workflows/build.yml` macOS derleme kontrolünü tanımlar. [GitHub Actions koşusu](https://github.com/pexatasoy/fotoaktar-masaustu/actions/runs/35103674352) iOS simülatör derlemesini ve **11 birim testini sıfır hatayla** tamamladı. Kaynak `ci/hedef-ios-20260916` dalındadır. Bu, fiziksel iPhone ve gerçek Wallet işlemi doğrulamasının yerini tutmaz.

Kaynak kontrolü: 17 Swift dosyası, 1024 × 1024 uygulama simgesi, geçerli entitlements XML ve asset kataloğu JSON'u doğrulandı. Bu kontrol Swift derlemesinin yerini tutmaz.

Paket kimliği `project.yml` ve `Hedef/Hedef.entitlements` içindeki geçici `com.hedefapp.hedef` değeridir. Gerçek Apple Developer takımında Sign in with Apple ve iCloud/CloudKit yetkileri bu kimlik için açılmalıdır.

## Yayın öncesi zorunlu doğrulama

1. Gerçek iPhone'da hesap, çevrimdışı kayıt, iki cihaz arasında eşitleme, veri dışa aktarma ve hesap silme.
2. Desteklenen kartla gerçek Wallet temassız işlemi; Kestirmeler girdi eşleme, yinelenen işlem ve bildirim denemesi.
3. Erişilebilirlik, açık/koyu görünüm ve animasyonların gerçek ekran incelemesi.
4. [Gizlilik metni](docs/PRIVACY.md) ve [App Store taslağındaki](docs/STORE.md) yayın bilgileri, TestFlight ve App Store incelemesi.

Gerçek cihazda doğrulanmayan Wallet tetikleme biçimleri ürün açıklamasında vaat edilmez.
