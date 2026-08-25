"""
fotoaktar — KLASÖR OKUYUCU

Bilgisayardaki dağınık bir fotoğraf klasörünü motorun anladığı `Oge` listesine
çevirir. İki yerde kullanılıyor:
  1. PC uygulamasında ikinci kaynak (telefon yerine klasör seç)
  2. Sitedeki "dağınık klasörünü düzenle" özelliğinin karşılığı

Tarih nereden geliyor:
  Önce dosya adından (IMG_20240815_123456, 2024-08-15 gibi kalıplar), o yoksa
  dosyanın değiştirilme tarihinden. EXIF okumuyoruz — ek kütüphane gerektiriyor
  ve dosya adı kalıpları pratikte fazlasıyla iyi çalışıyor. Tarih bulunamazsa
  öğe kaybolmuyor, "Tarihi bilinmeyen" klasörüne gidiyor.
"""

from __future__ import annotations

import os
import re
from datetime import datetime
from pathlib import Path
from typing import Iterator, Optional

from motor import Oge

FOTO_UZANTI = {".jpg", ".jpeg", ".png", ".heic", ".heif", ".gif", ".webp",
               ".bmp", ".tif", ".tiff", ".dng", ".raw", ".cr2", ".nef", ".arw"}
VIDEO_UZANTI = {".mov", ".mp4", ".m4v", ".avi", ".mkv", ".3gp", ".webm", ".mts"}
YAN_UZANTI = {".aae", ".xmp", ".thm"}          # yan dosyalar — sayılmıyor

# Dosya adından tarih çıkarmak için kalıplar; en belirginden en gevşeğe.
TARIH_KALIPLARI = [
    re.compile(r"(20\d{2})(\d{2})(\d{2})[_\-\s]?(\d{2})(\d{2})(\d{2})"),
    re.compile(r"(20\d{2})[-_.](\d{2})[-_.](\d{2})[_\-\s]+(\d{2})[-_.](\d{2})[-_.](\d{2})"),
    re.compile(r"(20\d{2})[-_.](\d{2})[-_.](\d{2})"),
    re.compile(r"(20\d{2})(\d{2})(\d{2})"),
]

# Klasör adından "nereden geldi" tahmini
KAYNAK_IPUCLARI = {
    "whatsapp": "WhatsApp", "telegram": "Telegram", "instagram": "Instagram",
    "screenshot": "Ekran Görüntüsü", "screenshots": "Ekran Görüntüsü",
    "ekran": "Ekran Görüntüsü", "camera": "Kamera", "dcim": "Kamera",
    "download": "İndirilenler", "downloads": "İndirilenler",
}


def _tarih_addan(ad: str) -> Optional[datetime]:
    for kalip in TARIH_KALIPLARI:
        m = kalip.search(ad)
        if not m:
            continue
        p = [int(x) for x in m.groups()]
        try:
            if len(p) == 6:
                return datetime(p[0], p[1], p[2], p[3], p[4], p[5])
            return datetime(p[0], p[1], p[2])
        except ValueError:
            continue          # 2024-13-45 gibi saçma eşleşmeler
    return None


def _ekran_goruntusu_mu(yol: Path) -> bool:
    ad = yol.name.lower()
    if ad.startswith(("screenshot", "ekran", "scr_")):
        return True
    # iOS ekran görüntüleri PNG olur ve kamera dosya adı kalıbına uymaz
    if yol.suffix.lower() == ".png" and not re.match(r"^(img|dsc|vid)[_\-]?\d", ad):
        return True
    return any(p.name.lower() in ("screenshots", "ekran görüntüleri", "screenshot")
               for p in yol.parents)


def _kaynak_tahmin(yol: Path, kok: Path) -> Optional[str]:
    try:
        goreli = yol.relative_to(kok)
    except ValueError:
        return None
    for parca in goreli.parts[:-1]:
        d = parca.lower()
        for ipucu, ad in KAYNAK_IPUCLARI.items():
            if ipucu in d:
                return ad
    return None


def klasor_oku(kok: str | Path, alt_klasorler: bool = True) -> dict:
    """Klasörü tarayıp `Oge` listesi üretir."""
    kok = Path(kok).resolve()
    if not kok.is_dir():
        raise NotADirectoryError(f"klasör bulunamadı: {kok}")

    ogeler: list = []
    atlanan_yan = 0
    okunamayan = 0

    gezinti: Iterator = kok.rglob("*") if alt_klasorler else kok.glob("*")
    for yol in gezinti:
        # Kendi arşiv defterimizi kaynak sanmayalım
        if ".fotoaktar" in yol.parts:
            continue
        if not yol.is_file():
            continue

        uz = yol.suffix.lower()
        if uz in YAN_UZANTI:
            atlanan_yan += 1
            continue
        if uz not in FOTO_UZANTI and uz not in VIDEO_UZANTI:
            continue

        try:
            durum = yol.stat()
        except OSError:
            okunamayan += 1
            continue

        tarih = _tarih_addan(yol.name)
        if tarih is None:
            try:
                tarih = datetime.fromtimestamp(durum.st_mtime)
            except (OSError, OverflowError, ValueError):
                tarih = None

        ekran = _ekran_goruntusu_mu(yol)
        kaynak = _kaynak_tahmin(yol, kok) or ("Ekran Görüntüsü" if ekran else "Kamera")

        ogeler.append(Oge(
            # Kimlik göreli yol: aynı klasör tekrar okununca aynı kimlik çıksın,
            # böylece "kaldığı yerden devam" çalışsın.
            kimlik=str(yol.relative_to(kok)).replace("\\", "/"),
            ad=yol.name,
            boyut=durum.st_size,
            ac=(lambda y=yol: open(y, "rb")),
            tarih=tarih,
            tur="video" if uz in VIDEO_UZANTI else "foto",
            kaynak=kaynak,
            ekran_goruntusu=ekran,
            grup=yol.stem,                 # aynı gövdeli foto+video birlikte
            yerel=True,
        ))

    ogeler.sort(key=lambda o: (o.tarih or datetime.min, o.ad))
    return {"ogeler": ogeler, "atlanan_yan": atlanan_yan, "okunamayan": okunamayan,
            "kok": str(kok)}
