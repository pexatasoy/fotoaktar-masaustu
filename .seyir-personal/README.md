# Seyir

Apple TV için cihaz üzerinde çalışan tarayıcı projesi. Seyir geçici kod adıdır.

## Kesin gereksinimler

- Kullanım sırasında VPS üzerinde tarayıcı, video kodlayıcı veya aktarma servisi çalışmaz.
- Sayfa işleme, JavaScript ve video Apple TV üzerinde çalışır.
- GitHub macOS çalıştırıcısı yalnızca derleme ve simülatör kontrolleri içindir.
- Kumanda tek başına yeterlidir. Büyük odak hedefleri, adres/arama, favoriler ve geçmiş.
- Mevcut Little Light imzalama malzemeleri güvenli konumlarında kalır; bu projeye kopyalanmaz.

## Durum

**Cihaz ve simülatör derlemeleri başarılı; imzalı kişisel IPA fiziksel Apple TV'ye kuruldu. İlk açılış ve fiziksel kullanım testi bekleniyor.** Google araması simülatörde açıldı. YouTube testi bot doğrulamasında kaldığı için YouTube oynatma doğrulanmış değil. Doğrudan video için yerel AVPlayer kullanılıyor.

Hedef cihaz: A2737, tvOS 26.6 (23L773).

İlk GitHub testi tvOS 26.5 simülatöründe sistem WebKit'inin yüklenebildiğini, yerel HTML açtığını ve JavaScript sonucunun 42 olduğunu doğruladı. Bu **gerçek cihaz testi değildir**. `native/` altında bu motoru kullanan açıkça kişisel kullanıma ayrılmış bir uygulama geliştiriliyor. Apple'ın desteklemediği tvOS WebKit erişimi nedeniyle App Store/TestFlight uyumluluğu iddia edilmez. Adaptör `SEYIR_PERSONAL_BUILD=1` olmadan derlenmez.

Alternatif olarak Chromium'un upstream tvOS Blink portu gerçek cihazda YouTube oynatmayı göstermiştir, fakat deneysel ve tek süreçlidir. Bu portun derlenebilir olması, genel web gezintisi için güvenli ve kararlı olduğu veya App Store tarafından kabul edileceği anlamına gelmez.

## Kaynak düzeni

- `native/`: Yerel kumanda arayüzü, kişisel WebKit adaptörü, adres/arama, favoriler ve geçmiş.
- `tests/`: Adres doğrulama, Türkçe arama kodlaması ve kayıt kurtarma testleri.
- `project.yml`: XcodeGen tvOS projesi.
- `ci/`: macOS üzerinde cihaz/simülatör derlemesi ve gerçek uygulamadan ekran görüntüleri. CI başarısı tek başına video oynatma başarısı anlamına gelmez; sayfa/video çıktıları ayrıca incelenir.

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
