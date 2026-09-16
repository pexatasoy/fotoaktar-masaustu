# Hedef — Gizlilik bildirimi taslağı

**Yayın öncesi geliştirici adı, iletişim adresi, yürürlük tarihi ve herkese açık URL eklenmelidir.** Bu metin uygulamanın mevcut kaynak davranışını açıklar.

## Hangi bilgiler kullanılır?

- Apple ile Giriş Yap, uygulamaya benzersiz bir Apple kullanıcı kimliği verir. Uygulama bu kimliği cihazın Keychain alanında, yerel kayıtları doğru hesapla eşleştirmek için saklar. E-posta adresi istemez.
- Kullanıcının girdiği hedefler, birikimler, gelir/gider planı ve harcamalar cihazda saklanır. iCloud hesabı uygunsa veriler kullanıcının özel CloudKit alanında eşitlenir.
- Kullanıcı iOS Kestirmeler otomasyonunu kurarsa Wallet işlem tutarı, para birimi ve isteğe bağlı iş yeri adı uygulamaya gönderilebilir. Uygulama yalnızca gönderilen işlemleri kaydeder; tüm kartlara veya ödeme geçmişine kendiliğinden erişmez.
- Bildirim izni verilirse hedef hatırlatmaları ve işlem geri bildirimleri cihazda yerel bildirim olarak gösterilir. Kilit ekranında tutar gösterimi kullanıcı tarafından açılır.

## Kullanım ve paylaşım

Bu bilgiler hedef ilerlemesini, harcama karşılaştırmasını, bütçe önerisini ve cihazlar arası eşitlemeyi sağlamak için kullanılır. Kaynak kodda reklam ağı, üçüncü taraf analitik SDK'sı, veri satışı veya banka bağlantısı yoktur. iCloud eşitlemesi Apple CloudKit üzerinden yapılır; [CloudKit özel veritabanı](https://developer.apple.com/documentation/cloudkit/ckcontainer) kullanıcı hesabına bağlıdır.

## Kontrol

Kullanıcı uygulama içinden verilerini JSON olarak dışa aktarabilir, kayıtları düzeltebilir veya silebilir, bildirimleri kapatabilir, hesabını ve kayıtlarını silebilir. Hesap silme iCloud erişimi gerektirir; eşitleme tamamlanamazsa uygulama silme işlemini tamamlandı diye göstermez. Apple ile Giriş Yap erişimini ayrıca iPhone Ayarlar bölümünden kaldırma adımı gösterilir; [Apple'ın yönergesi](https://support.apple.com/en-au/102571) izlenir.

## Saklama

Kayıtlar kullanıcı silene kadar cihazda ve etkinse özel iCloud alanında tutulur. Dışa aktarılmış dosyaların ve kullanıcının kendi cihaz yedeklerinin yönetimi kullanıcıya aittir.

## İletişim

**Yayın öncesi geliştirici iletişim adresi eklenecek.**

