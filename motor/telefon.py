"""
fotoaktar — iPHONE OKUYUCU

Kabloyla bağlı iPhone'un galerisini okuyup motorun anladığı `Oge` listesine
çevirir. Telefona HİÇBİR ŞEY YAZMAZ, HİÇBİR ŞEY SİLMEZ.

Nasıl çalışıyor:
  - AFC servisi telefonun /var/mobile/Media klasörünü dışarı açıyor
    ("Bu bilgisayara güven" yeterli, jailbreak gerekmiyor).
  - Oradan `PhotoData/Photos.sqlite` çekiliyor — Fotoğraflar uygulamasının
    beyni. Albümler, tarihler, favoriler, ekran görüntüsü işaretleri orada.
  - Dosyaların kendisi /DCIM altında duruyor.

İki teknik köprü kuruluyor:
  1. `pymobiledevice3` asenkron, motor senkron → arka planda bir olay
     döngüsü çalıştırıp senkron çağrıları ona iletiyoruz. Kütüphanenin kendi
     senkron sarmalayıcısı var ama özel (private) API, ona bel bağlamıyoruz.
  2. AFC'deki dosyayı motorun beklediği "okunabilir akış" hâline getiriyoruz,
     böylece 8 GB'lık video belleğe alınmadan parça parça akıyor.
"""

from __future__ import annotations

import asyncio
import os
import re
import sqlite3
import tempfile
import threading
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional

from motor import Oge

# Apple çekirdek zamanı 1 Ocak 2001'den itibaren saniye sayıyor
APPLE_EPOK = datetime(2001, 1, 1, tzinfo=timezone.utc)

# ZASSET.ZKINDSUBTYPE değerleri (ölçümle doğrulanacak — `alt_tur_dagilimi` bunun için)
ALT_TUR_EKRAN_GORUNTUSU = 10

# Bu adlarda albümler uygulamaların kendi açtığı klasörler; kullanıcının
# kürasyonu değiller ama "nereden geldi" ayrımı için değerliler.
UYGULAMA_ALBUMLERI = {
    "whatsapp", "instagram", "pinterest", "telegram", "twitter", "x",
    "facebook", "messenger", "tiktok", "snapchat", "discord", "reddit",
    "capcut", "lightroom", "faceapp", "polarr", "vsco", "picsart",
}


# ----------------------------------------------------------------- köprü

class Kopru:
    """Arka planda bir olay döngüsü çalıştırır; senkron kodun asenkron
    kütüphaneyi kullanmasını sağlar."""

    def __init__(self) -> None:
        self._dongu = asyncio.new_event_loop()
        self._is = threading.Thread(target=self._calis, daemon=True, name="fotoaktar-afc")
        self._is.start()

    def _calis(self) -> None:
        asyncio.set_event_loop(self._dongu)
        self._dongu.run_forever()

    def cagir(self, coro):
        """Bir coroutine'i çalıştırıp sonucunu bekler."""
        return asyncio.run_coroutine_threadsafe(coro, self._dongu).result()

    def kapat(self) -> None:
        self._dongu.call_soon_threadsafe(self._dongu.stop)
        self._is.join(timeout=5)
        self._dongu.close()


class AfcAkis:
    """AFC üzerindeki bir dosyayı normal dosya gibi okunur hâle getirir.

    Motor `ac().read(n)` çağırıyor; burası onu AFC'nin fopen/fread/fclose
    üçlüsüne çeviriyor. Dosya belleğe alınmıyor, parça parça akıyor.
    """

    def __init__(self, kopru: Kopru, afc, yol: str):
        self._kopru = kopru
        self._afc = afc
        self._tutamac = kopru.cagir(afc.fopen(yol, "r"))
        self._kapali = False

    def read(self, n: int = -1) -> bytes:
        if self._kapali:
            raise ValueError("akış kapalı")
        if n is None or n < 0:
            parcalar = []
            while True:
                p = self._kopru.cagir(self._afc.fread(self._tutamac, 4 * 1024 * 1024))
                if not p:
                    break
                parcalar.append(p)
            return b"".join(parcalar)
        return self._kopru.cagir(self._afc.fread(self._tutamac, n))

    def close(self) -> None:
        if not self._kapali:
            self._kapali = True
            try:
                self._kopru.cagir(self._afc.fclose(self._tutamac))
            except Exception:
                pass

    def __enter__(self):
        return self

    def __exit__(self, *a):
        self.close()


# ----------------------------------------------------------------- şema okuma

def _sutunlar(baglanti: sqlite3.Connection, tablo: str) -> set:
    try:
        return {r[1] for r in baglanti.execute(f"PRAGMA table_info({tablo})")}
    except sqlite3.Error:
        return set()


def _ilk_var(mevcut: set, *adaylar: str) -> Optional[str]:
    """iOS sürümleri arasında sütun adları değişiyor — ilk bulunanı kullan."""
    for a in adaylar:
        if a in mevcut:
            return a
    return None


def _apple_tarih(saniye) -> Optional[datetime]:
    if saniye is None:
        return None
    try:
        return APPLE_EPOK + timedelta(seconds=float(saniye))
    except (TypeError, ValueError):
        return None


def galeri_oku(
    db_yolu: str | Path,
    dcim_adlari: Optional[set] = None,
    akis_ac=None,
) -> dict:
    """Photos.sqlite'ı okuyup `Oge` listesi üretir.

    `dcim_adlari`  : telefonun /DCIM'inde gerçekten duran dosya adları.
                     Verilirse "aslı telefonda mı" kontrolü buna göre yapılır.
    `akis_ac`      : (dizin, ad) alıp okunabilir akış döndüren fonksiyon.
                     Verilmezse öğeler okunamaz olur (sadece rapor için).
    """
    baglanti = sqlite3.connect(f"file:{db_yolu}?mode=ro", uri=True)
    baglanti.row_factory = sqlite3.Row
    try:
        return _galeri_oku(baglanti, dcim_adlari, akis_ac)
    finally:
        baglanti.close()


def _galeri_oku(baglanti, dcim_adlari, akis_ac) -> dict:
    a = _sutunlar(baglanti, "ZASSET")
    if not a:
        raise RuntimeError("ZASSET tablosu yok — Photos.sqlite beklenenden farklı")

    s_pk = _ilk_var(a, "Z_PK")
    s_uuid = _ilk_var(a, "ZUUID")
    s_ad = _ilk_var(a, "ZFILENAME")
    s_dizin = _ilk_var(a, "ZDIRECTORY")
    s_tarih = _ilk_var(a, "ZDATECREATED")
    s_cop = _ilk_var(a, "ZTRASHEDSTATE")
    s_gizli = _ilk_var(a, "ZHIDDEN")
    s_tur = _ilk_var(a, "ZKIND")
    s_alttur = _ilk_var(a, "ZKINDSUBTYPE")

    if not (s_pk and s_ad):
        raise RuntimeError("ZASSET'te beklenen sütunlar yok")

    # --- albüm üyelikleri: fotoğraf nereden geldi ---
    albumler = _albumleri_oku(baglanti)

    # --- boyutlar: ZINTERNALRESOURCE'tan ---
    boyutlar, yerellik = _kaynaklari_oku(baglanti)

    secilecek = [f"A.{s_pk} AS pk", f"A.{s_ad} AS ad"]
    for sut, takma in ((s_uuid, "uuid"), (s_dizin, "dizin"), (s_tarih, "tarih"),
                       (s_cop, "cop"), (s_gizli, "gizli"), (s_tur, "tur"),
                       (s_alttur, "alttur")):
        secilecek.append(f"A.{sut} AS {takma}" if sut else f"NULL AS {takma}")

    sql = f"SELECT {', '.join(secilecek)} FROM ZASSET A"
    if s_cop:
        sql += f" WHERE A.{s_cop}=0"          # Son Silinenler'dekilere dokunma

    ogeler, atlanan_cop, alt_tur_dagilimi = [], 0, {}

    for r in baglanti.execute(sql):
        ad = r["ad"]
        if not ad:
            continue

        alt = r["alttur"]
        alt_tur_dagilimi[alt] = alt_tur_dagilimi.get(alt, 0) + 1

        dizin = (r["dizin"] or "DCIM/100APPLE").strip("/")
        if not dizin.upper().startswith("DCIM"):
            dizin = f"DCIM/{dizin}"

        yerel = True
        if dcim_adlari is not None:
            yerel = ad.upper() in dcim_adlari
        elif r["pk"] in yerellik:
            yerel = yerellik[r["pk"]]

        kaynak = albumler.get(r["pk"])
        ekran = (alt == ALT_TUR_EKRAN_GORUNTUSU)
        if ekran and not kaynak:
            kaynak = "Ekran Görüntüsü"

        govde = os.path.splitext(ad)[0]
        yol = f"/{dizin}/{ad}"

        ogeler.append(Oge(
            kimlik=str(r["uuid"] or r["pk"]),
            ad=ad,
            boyut=boyutlar.get(r["pk"], 0),
            ac=(lambda y=yol: akis_ac(y)) if akis_ac else (lambda: None),
            tarih=_apple_tarih(r["tarih"]),
            tur="video" if r["tur"] == 1 else "foto",
            kaynak=kaynak or "Kamera",
            ekran_goruntusu=ekran,
            grup=govde,                      # Live Photo çifti aynı gövdeyi paylaşır
            yerel=yerel,
        ))

    return {
        "ogeler": ogeler,
        "alt_tur_dagilimi": dict(sorted(alt_tur_dagilimi.items(),
                                        key=lambda k: -k[1])),
        "album_sayisi": len(set(albumler.values())),
    }


def _albumleri_oku(baglanti) -> dict:
    """Hangi fotoğraf hangi albümde → {asset_pk: albüm adı}.

    Yalnızca uygulama albümleriyle ilgileniyoruz ("nereden geldi" ayrımı).
    Bağlantı tablosunun adı iOS sürümüne göre değişiyor (Z_33ASSETS gibi),
    o yüzden desenle arıyoruz.
    """
    sonuc: dict = {}
    alb = _sutunlar(baglanti, "ZGENERICALBUM")
    if not alb:
        return sonuc

    s_baslik = _ilk_var(alb, "ZTITLE")
    if not s_baslik:
        return sonuc

    tablolar = [r[0] for r in baglanti.execute(
        "SELECT name FROM sqlite_master WHERE type='table'")]
    bag = [t for t in tablolar if re.fullmatch(r"Z_\d+ASSETS", t)]
    if not bag:
        return sonuc

    bs = _sutunlar(baglanti, bag[0])
    s_alb = next((c for c in bs if c.endswith("ALBUMS")), None)
    s_ast = next((c for c in bs if c.endswith("ASSETS")), None)
    if not (s_alb and s_ast):
        return sonuc

    try:
        satirlar = baglanti.execute(
            f"SELECT B.{s_ast} AS ast, G.{s_baslik} AS baslik "
            f"FROM {bag[0]} B JOIN ZGENERICALBUM G ON G.Z_PK = B.{s_alb} "
            f"WHERE G.{s_baslik} IS NOT NULL AND G.{s_baslik} != ''")
    except sqlite3.Error:
        return sonuc

    for r in satirlar:
        baslik = r["baslik"]
        if baslik.lower().strip() in UYGULAMA_ALBUMLERI:
            sonuc[r["ast"]] = baslik
    return sonuc


def _kaynaklari_oku(baglanti) -> tuple:
    """ZINTERNALRESOURCE'tan boyut ve yerellik bilgisi.

    Orijinal kaynak (ZRESOURCETYPE=0) esas alınıyor; küçük önizlemeler değil.
    """
    boyutlar: dict = {}
    yerellik: dict = {}
    ir = _sutunlar(baglanti, "ZINTERNALRESOURCE")
    if not ir:
        return boyutlar, yerellik

    s_asset = _ilk_var(ir, "ZASSET")
    s_boyut = _ilk_var(ir, "ZDATALENGTH", "ZFILESIZE", "ZDATASIZE")
    s_yerel = _ilk_var(ir, "ZLOCALAVAILABILITY")
    s_tip = _ilk_var(ir, "ZRESOURCETYPE")
    if not s_asset:
        return boyutlar, yerellik

    alanlar = [f"{s_asset} AS ast"]
    alanlar.append(f"{s_boyut} AS boyut" if s_boyut else "0 AS boyut")
    alanlar.append(f"{s_yerel} AS yerel" if s_yerel else "1 AS yerel")
    sql = f"SELECT {', '.join(alanlar)} FROM ZINTERNALRESOURCE"
    if s_tip:
        sql += f" WHERE {s_tip}=0"

    try:
        for r in baglanti.execute(sql):
            ast = r["ast"]
            if ast is None:
                continue
            boyutlar[ast] = max(boyutlar.get(ast, 0), int(r["boyut"] or 0))
            yerellik[ast] = (r["yerel"] == 1)
    except sqlite3.Error:
        pass
    return boyutlar, yerellik


# ----------------------------------------------------------------- telefon

class Telefon:
    """Bağlı iPhone. `with` ile kullanılır, çıkışta bağlantıyı kapatır."""

    def __init__(self):
        self._kopru = Kopru()
        self._afc = None
        self._lockdown = None
        self._gecici = None
        self.bilgi: dict = {}

    # -- bağlantı --------------------------------------------------

    def bagla(self) -> dict:
        from pymobiledevice3 import usbmux
        from pymobiledevice3.lockdown import create_using_usbmux
        from pymobiledevice3.services.afc import AfcService

        cihazlar = self._kopru.cagir(usbmux.list_devices())
        if not cihazlar:
            raise RuntimeError("Takılı iPhone bulunamadı. Kabloyu ve 'Güven' onayını kontrol et.")

        self._lockdown = self._kopru.cagir(create_using_usbmux(serial=cihazlar[0].serial))
        self._afc = AfcService(lockdown=self._lockdown)
        self._kopru.cagir(self._afc.__aenter__())

        d = self._lockdown.all_values
        self.bilgi = {
            "ad": d.get("DeviceName", "?"),
            "model": d.get("ProductType", "?"),
            "ios": d.get("ProductVersion", "?"),
        }
        try:
            disk = self._kopru.cagir(
                self._lockdown.get_value(domain="com.apple.disk_usage"))
            self.bilgi["toplam_bayt"] = disk.get("TotalDiskCapacity")
            self.bilgi["bos_bayt"] = disk.get("AmountDataAvailable")
        except Exception:
            pass
        return self.bilgi

    # -- galeri ----------------------------------------------------

    def galeri(self) -> dict:
        """Galeriyi okuyup `Oge` listesi döndürür."""
        if self._afc is None:
            raise RuntimeError("önce bagla() çağrılmalı")

        self._gecici = tempfile.TemporaryDirectory(prefix="fotoaktar-")
        db = Path(self._gecici.name) / "Photos.sqlite"
        for ek in ("", "-wal", "-shm"):
            try:
                veri = self._kopru.cagir(
                    self._afc.get_file_contents(f"/PhotoData/Photos.sqlite{ek}"))
                (db.parent / f"Photos.sqlite{ek}").write_bytes(veri)
            except Exception:
                if ek == "":
                    raise RuntimeError(
                        "Photos.sqlite okunamadı — telefonun kilidi açık ve "
                        "'Güven' onayı verilmiş olmalı.")

        return galeri_oku(db, dcim_adlari=self._dcim_adlari(), akis_ac=self._akis_ac)

    def _dcim_adlari(self) -> set:
        """/DCIM'de gerçekten duran dosya adları.

        Dosya dosya sorgulamak yerine klasörleri listeliyoruz — 3 çağrı yerine
        binlerce çağrı olurdu.
        """
        adlar = set()
        try:
            altlar = self._kopru.cagir(self._afc.listdir("/DCIM"))
        except Exception:
            return adlar
        for alt in altlar:
            if alt in (".", ".."):
                continue
            try:
                for ad in self._kopru.cagir(self._afc.listdir(f"/DCIM/{alt}")):
                    if ad not in (".", ".."):
                        adlar.add(ad.upper())
            except Exception:
                continue
        return adlar

    def _akis_ac(self, yol: str) -> AfcAkis:
        return AfcAkis(self._kopru, self._afc, yol)

    # -- kapanış ---------------------------------------------------

    def kapat(self) -> None:
        if self._afc is not None:
            try:
                self._kopru.cagir(self._afc.aclose())
            except Exception:
                pass
            self._afc = None
        if self._gecici is not None:
            self._gecici.cleanup()
            self._gecici = None
        self._kopru.kapat()

    def __enter__(self):
        self.bagla()
        return self

    def __exit__(self, *a):
        self.kapat()
