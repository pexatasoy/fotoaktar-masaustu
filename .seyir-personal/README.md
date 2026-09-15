# Seyir

Apple TV için cihaz üzerinde çalışan tarayıcı projesi. Seyir geçici kod adıdır.

## Kesin gereksinimler

- Kullanım sırasında VPS üzerinde tarayıcı, video kodlayıcı veya aktarma servisi çalışmaz.
- Sayfa işleme, JavaScript ve video Apple TV üzerinde çalışır.
- GitHub macOS çalıştırıcısı yalnızca derleme ve simülatör kontrolleri içindir.
- Kumanda tek başına yeterlidir. Büyük odak hedefleri, adres/arama, favoriler ve geçmiş.
- Mevcut Little Light imzalama malzemeleri güvenli konumlarında kalır; bu projeye kopyalanmaz.

## Durum

**Henüz çalışan veya TestFlight'a yüklenmiş bir Seyir sürümü yok.**

Motor uyumluluğu inceleniyor. Chromium'un upstream tvOS Blink portu gerçek cihazda YouTube oynatmayı göstermiştir, fakat deneysel ve tek süreçlidir. Bu portun derlenebilir olması, genel web gezintisi için güvenli ve kararlı olduğu veya App Store tarafından kabul edileceği anlamına gelmez.

Kaynaklar:

- [Chromium tvOS derleme belgesi](https://chromium.googlesource.com/chromium/src/+/main/docs/ios/build_instructions.md#blink-for-tvos-builds-and-running)
- [Portu geliştiren ekibin Mayıs 2026 raporu](https://blogs.igalia.com/gyuyoung/2026/05/15/blink-for-apple-tvos-2026-update/)
- [Apple inceleme kuralları](https://developer.apple.com/app-store/review/guidelines/)

## Teslim öncesi gerekli kanıtlar

1. Güncel tvOS için motorun cihaz ve simülatör derlemesi.
2. JavaScript, gezinme, kumandayla metin girişi, sesli video ve tam ekran testi.
3. Kullanıcının gerçek Apple TV'sinde bellek baskısı ve uzun video oturumu testi.
4. Uygulama kapanıp açılınca bozuk oturum döngüsüne girmeden kurtarma.
5. Uygulamaya özel tvOS kimliği/profili, imzalı arşiv ve uygun dağıtım yolu.

Motor portundaki yalıtım sınırlaması çözülmeden genel amaçlı güvenli tarayıcı iddiası yapılmaz. DRM'li yayın desteği ölçülmeden vaat edilmez.
