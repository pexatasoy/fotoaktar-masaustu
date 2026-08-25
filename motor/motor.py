"""
fotoaktar — AKTARMA MOTORU

Ürünün kalbi. Kaynaktan (telefon ya da klasör) gelen öğeleri hedef diske
düzenli şekilde yazar, her dosyayı yazdıktan sonra DOĞRULAR ve yalnızca
doğrulananları "silinebilir" olarak işaretler.

Tasarım kararları:

  DEFTER — hedef diske yazılan küçük bir veritabanı (.fotoaktar/defter.db).
  Diskin kendisinde durur, böylece SSD başka bilgisayara takılınca arşiv
  kendini tanıtır. Üç işi birden görür:
      1. "Bu dosya gerçekten yazıldı ve doğrulandı mı?"  → güvenli silme
      2. "Bu dosya zaten var mı?"                        → kaldığı yerden devam
      3. "Bu içerik zaten yazıldı mı?"                   → çift ayıklama
  Üçü de aynı kayda dayandığı için kaldığı yerden devam ve çift ayıklama
  bize fazladan neredeyse hiçbir maliyet çıkarmıyor.

  DOĞRULAMA — dosya yazıldıktan sonra hedeften GERİ OKUNUR ve parmak izi
  karşılaştırılır. Yazma sırasında hesaplanan özet yeterli değil; diske
  gerçekten doğru indiğini görmek istiyoruz. Maliyeti iki kat okuma, ama
  ürünün bütün vaadi bu.

  MOTOR HİÇBİR ŞEY SİLMEZ. Sadece "silinebilir" işareti koyar. Silme kararı
  ve işlemi üst katmanda, kullanıcı onayıyla.
"""

from __future__ import annotations

import hashlib
import os
import re
import shutil
import sqlite3
import unicodedata
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Callable, Iterable, Iterator, Optional

PARCA = 1024 * 1024          # 1 MB'lık parçalar hâlinde oku
DEFTER_KLASOR = ".fotoaktar"
DEFTER_AD = "defter.db"

AYLAR = ["", "01 Ocak", "02 Şubat", "03 Mart", "04 Nisan", "05 Mayıs", "06 Haziran",
         "07 Temmuz", "08 Ağustos", "09 Eylül", "10 Ekim", "11 Kasım", "12 Aralık"]


# ----------------------------------------------------------------- veri tipleri

@dataclass
class Oge:
    """Kaynaktaki tek bir fotoğraf/video.

    `ac` bir fonksiyon: çağrıldığında okunabilir bir akış döndürür. Böylece
    motor kaynağın ne olduğunu bilmek zorunda kalmıyor — telefon da olur,
    klasör de, ileride Android de.
    """
    kimlik: str
    ad: str
    boyut: int
    ac: Callable[[], object]
    tarih: Optional[datetime] = None
    tur: str = "foto"                     # "foto" | "video"
    kaynak: Optional[str] = None          # "Kamera", "WhatsApp", "Instagram"...
    ekran_goruntusu: bool = False
    grup: Optional[str] = None            # Live Photo çiftleri aynı grubu paylaşır
    yerel: bool = True                    # False ise aslı bulutta

    @property
    def uzanti(self) -> str:
        return os.path.splitext(self.ad)[1].lower()


@dataclass
class Ayar:
    duzen: str = "tarih"                  # "tarih" | "kaynak" | "duz"
    ekran_goruntusu_ayri: bool = True
    kok_klasor: str = "Fotoğraflarım"
    cift_atla: bool = True


@dataclass
class Sonuc:
    yazilan: int = 0
    dogrulanan: int = 0
    atlanan_zaten_var: int = 0
    atlanan_cift: int = 0
    atlanan_bulutta: int = 0
    basarisiz: int = 0
    toplam_bayt: int = 0
    hatalar: list = field(default_factory=list)

    @property
    def silinebilir(self) -> int:
        """Telefondan güvenle silinebilecek öğe sayısı.

        Çiftler de sayılır: içeriği zaten diskte olduğu için silinmeleri
        güvenli. Bulutta olanlar ve başarısızlar ASLA sayılmaz.
        """
        return self.dogrulanan + self.atlanan_zaten_var + self.atlanan_cift


# ----------------------------------------------------------------- yardımcılar

_GECERSIZ = re.compile(r'[<>:"/\\|?*\x00-\x1f]')

def guvenli_ad(ad: str) -> str:
    """Dosya/klasör adını her işletim sisteminde geçerli hâle getirir.

    Windows'ta yasak karakterler var, ayrıca sonda nokta/boşluk kabul
    edilmiyor. exFAT diskler Windows kurallarına tabi olduğu için hedef
    Linux bile olsa bu temizliği yapıyoruz.
    """
    ad = unicodedata.normalize("NFC", ad)
    ad = _GECERSIZ.sub("_", ad)
    ad = ad.rstrip(". ")
    return ad or "adsiz"


def klasor_yolu(oge: Oge, ayar: Ayar) -> Path:
    """Bu öğe hedef diskte hangi klasöre gitmeli."""
    if ayar.ekran_goruntusu_ayri and oge.ekran_goruntusu:
        return Path(ayar.kok_klasor) / "Ekran görüntüleri"

    if ayar.duzen == "duz":
        return Path(ayar.kok_klasor)

    if ayar.duzen == "kaynak":
        return Path(ayar.kok_klasor) / guvenli_ad(oge.kaynak or "Kamera")

    # varsayılan: tarih
    if oge.tarih is None:
        return Path(ayar.kok_klasor) / "Tarihi bilinmeyen"
    return Path(ayar.kok_klasor) / str(oge.tarih.year) / AYLAR[oge.tarih.month]


def _ozet_dosyadan(yol: Path) -> str:
    """Diskteki dosyanın SHA-256 parmak izi."""
    h = hashlib.sha256()
    with open(yol, "rb") as f:
        while True:
            p = f.read(PARCA)
            if not p:
                break
            h.update(p)
    return h.hexdigest()


# ----------------------------------------------------------------- defter

class Defter:
    """Hedef diskteki kayıt. Arşivin ne içerdiğini o disk kendi biliyor."""

    def __init__(self, hedef_kok: Path):
        self.klasor = Path(hedef_kok) / DEFTER_KLASOR
        self.klasor.mkdir(parents=True, exist_ok=True)
        self.yol = self.klasor / DEFTER_AD
        self.baglanti = sqlite3.connect(self.yol)
        self.baglanti.execute("PRAGMA journal_mode=WAL")
        self._kur()

    def _kur(self) -> None:
        self.baglanti.executescript("""
            CREATE TABLE IF NOT EXISTS ogeler (
                kimlik      TEXT PRIMARY KEY,   -- kaynaktaki benzersiz kimlik
                ad          TEXT NOT NULL,
                ozet        TEXT NOT NULL,      -- SHA-256
                hedef       TEXT NOT NULL,      -- diske göre göreli yol
                boyut       INTEGER NOT NULL,
                dogrulandi  INTEGER NOT NULL DEFAULT 0,
                cift_mi     INTEGER NOT NULL DEFAULT 0,
                zaman       TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS ix_ozet ON ogeler(ozet);
        """)
        self.baglanti.commit()

    def kayitli(self, kimlik: str) -> Optional[sqlite3.Row]:
        i = self.baglanti.execute(
            "SELECT ad, ozet, hedef, dogrulandi FROM ogeler WHERE kimlik=?", (kimlik,))
        return i.fetchone()

    def ozet_var_mi(self, ozet: str) -> Optional[str]:
        """Bu içerik daha önce yazıldı mı? Yazıldıysa hedef yolunu döndürür."""
        i = self.baglanti.execute(
            "SELECT hedef FROM ogeler WHERE ozet=? AND dogrulandi=1 LIMIT 1", (ozet,))
        s = i.fetchone()
        return s[0] if s else None

    def yaz(self, oge: Oge, ozet: str, hedef: str, dogrulandi: bool, cift: bool) -> None:
        self.baglanti.execute(
            "INSERT OR REPLACE INTO ogeler "
            "(kimlik, ad, ozet, hedef, boyut, dogrulandi, cift_mi, zaman) "
            "VALUES (?,?,?,?,?,?,?,?)",
            (oge.kimlik, oge.ad, ozet, hedef, oge.boyut,
             1 if dogrulandi else 0, 1 if cift else 0,
             datetime.now().isoformat(timespec="seconds")))
        self.baglanti.commit()

    def sil_kaydi(self, kimlik: str) -> None:
        self.baglanti.execute("DELETE FROM ogeler WHERE kimlik=?", (kimlik,))
        self.baglanti.commit()

    def silinebilir_kimlikler(self) -> list:
        i = self.baglanti.execute(
            "SELECT kimlik FROM ogeler WHERE dogrulandi=1 OR cift_mi=1")
        return [s[0] for s in i.fetchall()]

    def ozet_bilgi(self) -> dict:
        i = self.baglanti.execute(
            "SELECT COUNT(*), COALESCE(SUM(boyut),0) FROM ogeler WHERE dogrulandi=1")
        adet, bayt = i.fetchone()
        return {"adet": adet, "bayt": bayt}

    def kapat(self) -> None:
        self.baglanti.close()


# ----------------------------------------------------------------- aktarma

# Windows'ta bir yolun tamamı 260 karakteri aşamıyor. Hedef klasörün kendisi
# derindeyse (masaüstündeki bir klasörün içindeki klasör gibi) uzun dosya adları
# bu sınırı zorlayabiliyor. Sınıra yaklaşınca dosya ADINI kısaltıyoruz —
# uzantı ve benzersizlik korunuyor, klasör yapısı bozulmuyor.
WINDOWS_YOL_SINIRI = 255


def _ada_sigdir(klasor: Path, ad: str) -> str:
    tam = len(str(klasor)) + 1 + len(ad)
    if tam <= WINDOWS_YOL_SINIRI:
        return ad
    govde, uz = os.path.splitext(ad)
    kalan = WINDOWS_YOL_SINIRI - len(str(klasor)) - 1 - len(uz)
    if kalan < 8:
        # Klasörün kendisi zaten sınıra dayanmış; elimizden gelen bu.
        kalan = 8
    return govde[:kalan] + uz


def _bos_ad_bul(klasor: Path, ad: str) -> Path:
    """Aynı adda dosya varsa üzerine yazma — sonuna sayı ekle.

    Farklı klasörlerden aynı ada sahip dosyalar gelebiliyor (IMG_0001.JPG
    her iPhone'da var). İçerik farklıysa ikisini de saklamak zorundayız.
    """
    hedef = klasor / ad
    if not hedef.exists():
        return hedef
    govde, uz = os.path.splitext(ad)
    n = 2
    while True:
        aday = klasor / f"{govde} ({n}){uz}"
        if not aday.exists():
            return aday
        n += 1


def aktar(
    ogeler: Iterable[Oge],
    hedef_kok: str | Path,
    ayar: Optional[Ayar] = None,
    ilerleme: Optional[Callable[[dict], None]] = None,
    defter: Optional[Defter] = None,
) -> Sonuc:
    """Öğeleri hedefe yazar, doğrular ve sonucu döndürür.

    `ilerleme` her öğeden sonra çağrılır — arayüz bunu dinler.
    """
    ayar = ayar or Ayar()
    hedef_kok = Path(hedef_kok)
    hedef_kok.mkdir(parents=True, exist_ok=True)
    kendi_defteri = defter is None
    defter = defter or Defter(hedef_kok)
    sonuc = Sonuc()

    def bildir(durum: str, oge: Oge, ek: str = "") -> None:
        if ilerleme:
            ilerleme({"durum": durum, "ad": oge.ad, "kimlik": oge.kimlik,
                      "ek": ek, "sonuc": sonuc})

    try:
        for oge in ogeler:
            # 1) Aslı telefonda değilse dokunma. Bu en tehlikeli durum:
            #    olmayan dosyayı "aktardım" sayıp silersek fotoğraf gider.
            if not oge.yerel:
                sonuc.atlanan_bulutta += 1
                bildir("bulutta", oge)
                continue

            # 2) Defterde doğrulanmış kaydı varsa ve dosya yerinde duruyorsa atla.
            #    Kaldığı yerden devam buradan geliyor.
            kayit = defter.kayitli(oge.kimlik)
            if kayit and kayit[3] == 1 and (hedef_kok / kayit[2]).exists():
                sonuc.atlanan_zaten_var += 1
                bildir("zaten_var", oge, kayit[2])
                continue

            klasor = hedef_kok / klasor_yolu(oge, ayar)
            klasor.mkdir(parents=True, exist_ok=True)
            hedef = _bos_ad_bul(klasor, _ada_sigdir(klasor, guvenli_ad(oge.ad)))

            # 3) Kopyala — parçalar hâlinde, bellekte tutmadan.
            #    Yazarken parmak izini de hesaplıyoruz, ikinci okuma olmasın.
            h = hashlib.sha256()
            yazilan_bayt = 0
            try:
                kaynak = oge.ac()
                try:
                    with open(hedef, "wb") as cikti:
                        while True:
                            parca = kaynak.read(PARCA)
                            if not parca:
                                break
                            cikti.write(parca)
                            h.update(parca)
                            yazilan_bayt += len(parca)
                finally:
                    kapat = getattr(kaynak, "close", None)
                    if kapat:
                        kapat()
            except Exception as e:
                sonuc.basarisiz += 1
                sonuc.hatalar.append((oge.ad, f"{type(e).__name__}: {e}"))
                if hedef.exists():
                    hedef.unlink(missing_ok=True)
                bildir("hata", oge, str(e))
                continue

            ozet = h.hexdigest()

            # 4) Çift mi? Aynı içerik zaten diskteyse ikinci kopyayı tutma.
            #    Parmak izini nasılsa hesapladık, bu kontrol bedava geliyor.
            if ayar.cift_atla:
                onceki = defter.ozet_var_mi(ozet)
                if onceki and onceki != str(hedef.relative_to(hedef_kok)):
                    hedef.unlink(missing_ok=True)
                    defter.yaz(oge, ozet, onceki, dogrulandi=False, cift=True)
                    sonuc.atlanan_cift += 1
                    bildir("cift", oge, onceki)
                    continue

            sonuc.yazilan += 1
            sonuc.toplam_bayt += yazilan_bayt

            # 5) DOĞRULAMA — diskten geri oku, parmak izini karşılaştır.
            #    Ürünün bütün vaadi bu adım.
            try:
                diskteki = _ozet_dosyadan(hedef)
            except Exception as e:
                diskteki = None
                sonuc.hatalar.append((oge.ad, f"okunamadı: {e}"))

            if diskteki == ozet:
                defter.yaz(oge, ozet, str(hedef.relative_to(hedef_kok)),
                           dogrulandi=True, cift=False)
                sonuc.dogrulanan += 1
                bildir("dogrulandi", oge, str(hedef.relative_to(hedef_kok)))
            else:
                # Yazıldı ama tutmadı. Bozuk kopyayı bırakma, deftere de
                # doğrulanmış diye yazma — bu dosya SİLİNEBİLİR SAYILMAZ.
                hedef.unlink(missing_ok=True)
                defter.sil_kaydi(oge.kimlik)
                sonuc.yazilan -= 1
                sonuc.toplam_bayt -= yazilan_bayt
                sonuc.basarisiz += 1
                sonuc.hatalar.append((oge.ad, "doğrulama tutmadı"))
                bildir("dogrulanamadi", oge)
    finally:
        if kendi_defteri:
            defter.kapat()

    return sonuc


# ----------------------------------------------------------------- rapor

def yer_raporu(ogeler: Iterable[Oge], en_buyuk: int = 20) -> dict:
    """"Telefonunu ne yiyor" sekmesinin verisi.

    Tek geçişte hepsini çıkarıyoruz — liste iki kez dolaşılmasın.
    """
    ogeler = list(ogeler)
    toplam = sum(o.boyut for o in ogeler)
    videolar = [o for o in ogeler if o.tur == "video"]
    ekranlar = [o for o in ogeler if o.ekran_goruntusu]

    kaynaklar: dict = {}
    for o in ogeler:
        k = o.kaynak or "Kamera"
        d = kaynaklar.setdefault(k, {"adet": 0, "bayt": 0})
        d["adet"] += 1
        d["bayt"] += o.boyut

    yillar: dict = {}
    for o in ogeler:
        if o.tarih:
            d = yillar.setdefault(o.tarih.year, {"adet": 0, "bayt": 0})
            d["adet"] += 1
            d["bayt"] += o.boyut

    return {
        "adet": len(ogeler),
        "bayt": toplam,
        "bulutta": sum(1 for o in ogeler if not o.yerel),
        "video": {"adet": len(videolar), "bayt": sum(o.boyut for o in videolar)},
        "ekran_goruntusu": {"adet": len(ekranlar), "bayt": sum(o.boyut for o in ekranlar)},
        "en_buyuk_videolar": sorted(videolar, key=lambda o: -o.boyut)[:en_buyuk],
        "en_buyuk_ogeler": sorted(ogeler, key=lambda o: -o.boyut)[:en_buyuk],
        "kaynaklar": dict(sorted(kaynaklar.items(), key=lambda k: -k[1]["bayt"])),
        "yillar": dict(sorted(yillar.items())),
    }


def bicim(bayt: float) -> str:
    for birim in ("B", "KB", "MB", "GB", "TB"):
        if bayt < 1024:
            return f"{bayt:.1f} {birim}"
        bayt /= 1024
    return f"{bayt:.1f} PB"
