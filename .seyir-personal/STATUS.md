# Seyir — doğrulama durumu

15 Eylül 2026. Kaynak commit: `5bc392dcbf80eb0c94b99b0778b04d2128d7c99c`.

[GitHub kontrolü](https://github.com/pexatasoy/fotoaktar-masaustu/actions/runs/34954905260) başarılı.

## Doğrulandı

- Xcode 26.6 ile tvOS cihaz Release ve simülatör Debug derlemesi.
- Türkçe metin girişi, sayfa imleciyle HTML düğmesine tıklama.
- Gizli sekmenin geçmiş ve yeniden açılacak sekmeler listesine yazılmaması.
- Sekme kayıtlarının yeni tarayıcı nesnesinde geri yüklenmesi.
- En fazla iki canlı motor; bellek uyarısından sonra yalnızca aktif motor.
- Son sekme kapatılınca kullanılabilir yeni sekme oluşturulması.
- Google arama sonuçlarının açılması.
- Doğrudan örnek MP4: 5.011 saniyelik klip sonuna kadar, AVPlayer hata vermeden oynadı.
- Tenis: şeffaf ve yeşil kort görünümü videonun üstüne yerleşti; ikisinde de tvOS odak kontrolü oyunu seçti.
- Üst araç çubuğundaki kesilme önceki simülatör görüntüsünde düzeltildi.

## Henüz doğrulanmadı / tamamlanmadı

- Fiziksel A2737 / tvOS 26.6 üzerinde ilk açılış, Siri Remote tuş/dokunma hissi, ses, uzun video ve gerçek bellek ölçümü.
- YouTube videosu: sayfa açılıyor, ancak testte video süresi 0 ve hazır durumu 0. Başarılı oynatma sayılmaz.
- DRM veya giriş gerektiren yayınlar.
- İmzalı kişisel IPA oluşturuldu ve 15 Eylül 2026 13:09 İstanbul saatinde Apple TV'ye Wi-Fi üzerinden başarıyla kuruldu. İlk açılış kullanıcı tarafından kontrol edilecek.
- App Store/TestFlight dağıtımı: mevcut sistem WebKit adaptörü kişisel kullanım içindir; mağaza uyumluluğu iddia edilmez.

Boşta veya duraklatılmış tenis için animasyon zamanlayıcısı durdurulur. Oyun ve tarayıcı kullanımında VPS üzerinde çalışan servis yoktur.

İmzalı derleme: https://github.com/pexatasoy/fotoaktar-masaustu/actions/runs/34956360448
