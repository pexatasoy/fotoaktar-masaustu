"""
fotoaktar — PC UYGULAMASI

Yerel bir sunucu açar, arayüzü tarayıcıda "uygulama kipinde" gösterir.
Kullanıcı normal bir program gibi görür: adres çubuğu yok, sekme yok.

Neden bu yol:
  Arayüz web teknolojisiyle yazıldığı için AYNI tasarım hem bu uygulamada
  hem ileride sitede çalışıyor. Bir kez yapılıyor, iki yerde kullanılıyor.
  Ayrıca ek kurulum gerektirmiyor — Windows'ta Edge, macOS'ta Safari/Chrome
  zaten var.

Güvenlik:
  Sunucu YALNIZCA 127.0.0.1'e bağlanıyor, dışarıdan erişilemiyor. Ayrıca
  her açılışta rastgele bir jeton üretiliyor; API çağrıları onsuz reddediliyor.
  Bu, bilgisayarda açık olan herhangi bir web sayfasının bu sunucuya istek
  atmasını engelliyor.
"""

from __future__ import annotations

import json
import os
import secrets
import socket
import subprocess
import sys
import threading
import traceback
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse, parse_qs

# PyInstaller ile paketlendiğinde dosyalar .exe'nin içinden geçici bir klasöre
# açılıyor ve __file__ artık kaynak dosyayı göstermiyor. İki durumu ayırıyoruz.
DONMUS = getattr(sys, "frozen", False)

if DONMUS:
    KOK = Path(sys._MEIPASS)                     # paketin içindeki veri
    KENDI = [sys.executable]                     # kendini yeniden çağırmak için
    GUNLUK_KLASOR = Path(sys.executable).parent  # günlük .exe'nin yanına
else:
    KOK = Path(__file__).resolve().parent
    KENDI = [sys.executable, str(Path(__file__).resolve())]
    GUNLUK_KLASOR = KOK
    sys.path.insert(0, str(KOK.parent / "motor"))

import motor                     # noqa: E402
from motor import Ayar, Oge      # noqa: E402

JETON = secrets.token_urlsafe(24)


# ===================================================================== durum

class Durum:
    """Uygulamanın o anki hâli. Tek örnek, kilitle korunuyor."""

    def __init__(self) -> None:
        self.kilit = threading.Lock()
        self.kaynak_tipi: str | None = None      # "telefon" | "klasor"
        self.kaynak_ad: str = ""
        self.ogeler: list[Oge] = []
        self.telefon = None
        self.hedef: str | None = None
        self.ayar = Ayar()
        self.calisiyor = False
        self.bitti = False
        self.ilerleme = {"yazilan": 0, "dogrulanan": 0, "atlanan": 0,
                         "basarisiz": 0, "toplam": 0, "bayt": 0, "son_ad": ""}
        self.sonuc: dict | None = None
        self.hata: str | None = None

    def ozet(self) -> dict:
        r = motor.yer_raporu(self.ogeler) if self.ogeler else None
        return {
            "kaynak_tipi": self.kaynak_tipi,
            "kaynak_ad": self.kaynak_ad,
            "hedef": self.hedef,
            "calisiyor": self.calisiyor,
            "bitti": self.bitti,
            "hata": self.hata,
            "ayar": {"duzen": self.ayar.duzen,
                     "ekran_goruntusu_ayri": self.ayar.ekran_goruntusu_ayri},
            "ilerleme": self.ilerleme,
            "sonuc": self.sonuc,
            "rapor": _rapor_json(r) if r else None,
        }


def _rapor_json(r: dict) -> dict:
    """Rapor içindeki `Oge` nesnelerini arayüzün anlayacağı sözlüğe çevirir."""
    def kisa(o: Oge) -> dict:
        return {"ad": o.ad, "boyut": o.boyut, "tur": o.tur,
                "tarih": o.tarih.isoformat() if o.tarih else None}
    return {
        "adet": r["adet"], "bayt": r["bayt"], "bulutta": r["bulutta"],
        "video": r["video"], "ekran_goruntusu": r["ekran_goruntusu"],
        "kaynaklar": r["kaynaklar"],
        "yillar": {str(k): v for k, v in r["yillar"].items()},
        "en_buyuk_videolar": [kisa(o) for o in r["en_buyuk_videolar"][:10]],
        "en_buyuk_ogeler": [kisa(o) for o in r["en_buyuk_ogeler"][:10]],
    }


DURUM = Durum()


# ===================================================================== klasör seçici

def klasor_sec(baslik: str = "Klasör seç") -> str | None:
    """Yerel klasör seçme penceresi açar.

    AYRI BİR SÜREÇTE çalıştırılıyor: tkinter pencereleri ana iş parçacığında
    olmak zorunda (özellikle macOS'ta), ama biz bunu bir HTTP isteği içinden
    çağırıyoruz. Ayrı süreç bu çakışmayı tamamen ortadan kaldırıyor.
    """
    try:
        s = subprocess.run(
            KENDI + ["--klasor-sec", baslik],
            capture_output=True, text=True, timeout=300,
            # Paketlenmiş sürümde konsol gizli; alt sürecin penceresi açılmasın.
            creationflags=(subprocess.CREATE_NO_WINDOW
                           if sys.platform == "win32" and hasattr(subprocess, "CREATE_NO_WINDOW")
                           else 0))
        yol = (s.stdout or "").strip()
        return yol or None
    except Exception:
        return None


def _klasor_secici_calistir(baslik: str) -> None:
    try:
        import tkinter as tk
        from tkinter import filedialog
        k = tk.Tk()
        k.withdraw()
        k.attributes("-topmost", True)
        yol = filedialog.askdirectory(title=baslik)
        k.destroy()
        print(yol or "")
    except Exception:
        print("")


# ===================================================================== işler

def kaynak_telefon() -> dict:
    from telefon import Telefon
    t = Telefon()
    t.bagla()
    g = t.galeri()
    with DURUM.kilit:
        if DURUM.telefon is not None:
            try:
                DURUM.telefon.kapat()
            except Exception:
                pass
        DURUM.telefon = t
        DURUM.kaynak_tipi = "telefon"
        DURUM.kaynak_ad = t.bilgi.get("ad", "iPhone")
        DURUM.ogeler = g["ogeler"]
        DURUM.bitti = False
        DURUM.sonuc = None
        DURUM.hata = None
    return {"cihaz": t.bilgi, "adet": len(g["ogeler"]),
            "alt_tur_dagilimi": g.get("alt_tur_dagilimi", {})}


def kaynak_klasor(yol: str) -> dict:
    import klasor
    g = klasor.klasor_oku(yol)
    with DURUM.kilit:
        DURUM.kaynak_tipi = "klasor"
        DURUM.kaynak_ad = Path(yol).name or yol
        DURUM.ogeler = g["ogeler"]
        DURUM.bitti = False
        DURUM.sonuc = None
        DURUM.hata = None
    return {"kok": g["kok"], "adet": len(g["ogeler"]),
            "atlanan_yan": g["atlanan_yan"]}


def aktarimi_baslat() -> None:
    with DURUM.kilit:
        if DURUM.calisiyor:
            raise RuntimeError("aktarım zaten sürüyor")
        if not DURUM.ogeler:
            raise RuntimeError("önce bir kaynak seç")
        if not DURUM.hedef:
            raise RuntimeError("önce hedef klasörü seç")
        DURUM.calisiyor = True
        DURUM.bitti = False
        DURUM.hata = None
        DURUM.sonuc = None
        DURUM.ilerleme = {"yazilan": 0, "dogrulanan": 0, "atlanan": 0,
                          "basarisiz": 0, "toplam": len(DURUM.ogeler),
                          "bayt": 0, "son_ad": ""}
        ogeler, hedef, ayar = list(DURUM.ogeler), DURUM.hedef, DURUM.ayar

    def bildir(olay: dict) -> None:
        s = olay["sonuc"]
        DURUM.ilerleme.update({
            "yazilan": s.yazilan, "dogrulanan": s.dogrulanan,
            "atlanan": s.atlanan_zaten_var + s.atlanan_cift + s.atlanan_bulutta,
            "basarisiz": s.basarisiz, "bayt": s.toplam_bayt,
            "son_ad": olay["ad"], "son_durum": olay["durum"],
        })

    def calis() -> None:
        try:
            s = motor.aktar(ogeler, hedef, ayar=ayar, ilerleme=bildir)
            with DURUM.kilit:
                DURUM.sonuc = {
                    "yazilan": s.yazilan, "dogrulanan": s.dogrulanan,
                    "cift": s.atlanan_cift, "zaten_var": s.atlanan_zaten_var,
                    "bulutta": s.atlanan_bulutta, "basarisiz": s.basarisiz,
                    "silinebilir": s.silinebilir, "bayt": s.toplam_bayt,
                    "hatalar": [{"ad": a, "sebep": b} for a, b in s.hatalar[:50]],
                }
                DURUM.bitti = True
        except Exception as e:
            with DURUM.kilit:
                DURUM.hata = f"{type(e).__name__}: {e}"
            traceback.print_exc()
        finally:
            with DURUM.kilit:
                DURUM.calisiyor = False

    threading.Thread(target=calis, daemon=True, name="fotoaktar-aktarim").start()


# ===================================================================== sunucu

class Islem(BaseHTTPRequestHandler):
    server_version = "fotoaktar"

    def log_message(self, *a) -> None:
        pass                                   # konsolu kirletme

    # -- yardımcılar ------------------------------------------------

    def _json(self, veri, kod: int = 200) -> None:
        govde = json.dumps(veri, ensure_ascii=False).encode("utf-8")
        self.send_response(kod)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(govde)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(govde)

    def _jeton_gecerli(self) -> bool:
        # Jeton ya başlıkta ya sorgu dizesinde olmalı.
        if self.headers.get("X-Jeton") == JETON:
            return True
        q = parse_qs(urlparse(self.path).query)
        return q.get("j", [None])[0] == JETON

    def _govde(self) -> dict:
        try:
            n = int(self.headers.get("Content-Length") or 0)
            return json.loads(self.rfile.read(n) or b"{}")
        except Exception:
            return {}

    # -- yönlendirme ------------------------------------------------

    def do_GET(self) -> None:
        yol = urlparse(self.path).path

        if yol in ("/", "/index.html"):
            return self._dosya("index.html", "text/html; charset=utf-8")
        if yol == "/api/durum":
            if not self._jeton_gecerli():
                return self._json({"hata": "jeton"}, 403)
            with DURUM.kilit:
                return self._json(DURUM.ozet())
        if yol == "/api/ilerleme":
            if not self._jeton_gecerli():
                return self._json({"hata": "jeton"}, 403)
            return self._json({"calisiyor": DURUM.calisiyor, "bitti": DURUM.bitti,
                               "ilerleme": DURUM.ilerleme, "sonuc": DURUM.sonuc,
                               "hata": DURUM.hata})
        self.send_error(404)

    def do_POST(self) -> None:
        if not self._jeton_gecerli():
            return self._json({"hata": "jeton"}, 403)
        yol = urlparse(self.path).path
        g = self._govde()
        try:
            if yol == "/api/kaynak/telefon":
                return self._json({"tamam": True, **kaynak_telefon()})

            if yol == "/api/kaynak/klasor":
                secilen = klasor_sec("Fotoğrafların bulunduğu klasörü seç")
                if not secilen:
                    return self._json({"tamam": False, "iptal": True})
                return self._json({"tamam": True, **kaynak_klasor(secilen)})

            if yol == "/api/hedef":
                secilen = klasor_sec("Fotoğrafların yazılacağı diski/klasörü seç")
                if not secilen:
                    return self._json({"tamam": False, "iptal": True})
                with DURUM.kilit:
                    DURUM.hedef = secilen
                return self._json({"tamam": True, "hedef": secilen})

            if yol == "/api/ayar":
                with DURUM.kilit:
                    if "duzen" in g and g["duzen"] in ("tarih", "kaynak", "duz"):
                        DURUM.ayar.duzen = g["duzen"]
                    if "ekran_goruntusu_ayri" in g:
                        DURUM.ayar.ekran_goruntusu_ayri = bool(g["ekran_goruntusu_ayri"])
                return self._json({"tamam": True})

            if yol == "/api/aktar":
                aktarimi_baslat()
                return self._json({"tamam": True})

            if yol == "/api/kapat":
                threading.Timer(0.4, lambda: os._exit(0)).start()
                return self._json({"tamam": True})

        except Exception as e:
            traceback.print_exc()
            return self._json({"tamam": False, "hata": f"{type(e).__name__}: {e}"}, 500)

        self.send_error(404)

    # -- statik dosya -----------------------------------------------

    def _dosya(self, ad: str, tip: str) -> None:
        yol = KOK / "arayuz" / ad
        if not yol.is_file():
            return self.send_error(404)
        veri = yol.read_bytes()
        # Jetonu sayfaya gömüyoruz; arayüz her istekte onu geri gönderiyor.
        if ad.endswith(".html"):
            veri = veri.replace(b"__JETON__", JETON.encode())
        self.send_response(200)
        self.send_header("Content-Type", tip)
        self.send_header("Content-Length", str(len(veri)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(veri)


# ===================================================================== açılış

def bos_kapi() -> int:
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def tarayici_ac(adres: str) -> None:
    """Tarayıcıyı uygulama kipinde açmayı dener.

    --app kipinde adres çubuğu ve sekmeler görünmez; normal bir program gibi
    durur. Uygun tarayıcı bulunamazsa normal sekmede açıyoruz — çalışmama
    durumu olmasın.
    """
    adaylar = []
    if sys.platform == "win32":
        yerel = os.environ.get("LOCALAPPDATA", "")
        pf = os.environ.get("PROGRAMFILES", r"C:\Program Files")
        pf86 = os.environ.get("PROGRAMFILES(X86)", r"C:\Program Files (x86)")
        adaylar = [
            rf"{pf86}\Microsoft\Edge\Application\msedge.exe",
            rf"{pf}\Microsoft\Edge\Application\msedge.exe",
            rf"{pf}\Google\Chrome\Application\chrome.exe",
            rf"{pf86}\Google\Chrome\Application\chrome.exe",
            rf"{yerel}\Google\Chrome\Application\chrome.exe",
        ]
    elif sys.platform == "darwin":
        adaylar = [
            "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
            "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
        ]
    else:
        adaylar = ["/usr/bin/google-chrome", "/usr/bin/chromium",
                   "/usr/bin/chromium-browser", "/usr/bin/microsoft-edge"]

    for a in adaylar:
        if a and Path(a).exists():
            try:
                subprocess.Popen([a, f"--app={adres}", "--window-size=1180,860"],
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                return
            except Exception:
                continue
    webbrowser.open(adres)


def main() -> None:
    if len(sys.argv) > 1 and sys.argv[1] == "--klasor-sec":
        _klasor_secici_calistir(sys.argv[2] if len(sys.argv) > 2 else "Klasör seç")
        return

    kapi = bos_kapi()
    adres = f"http://127.0.0.1:{kapi}/?j={JETON}"
    sunucu = ThreadingHTTPServer(("127.0.0.1", kapi), Islem)

    print("=" * 56)
    print("  fotoaktar — PC uygulaması")
    print("=" * 56)
    print(f"  Adres: {adres}")
    print("  Pencere kapanınca bu pencereyi de kapatabilirsin.")
    print()

    if "--acma" not in sys.argv:
        threading.Timer(0.6, lambda: tarayici_ac(adres)).start()

    try:
        sunucu.serve_forever()
    except KeyboardInterrupt:
        print("\nkapatılıyor...")
    finally:
        if DURUM.telefon is not None:
            try:
                DURUM.telefon.kapat()
            except Exception:
                pass


def _cokme_bildir(metin: str) -> None:
    """Konsol gizliyken hata kaybolmasın: yanına günlük yaz, pencereyle bildir."""
    try:
        (GUNLUK_KLASOR / "fotoaktar-hata.txt").write_text(metin, encoding="utf-8")
    except Exception:
        pass
    try:
        import tkinter as tk
        from tkinter import messagebox
        k = tk.Tk(); k.withdraw()
        messagebox.showerror(
            "fotoaktar",
            "Uygulama beklenmedik şekilde durdu.\n\n"
            "Ayrıntılar 'fotoaktar-hata.txt' dosyasına yazıldı.\n\n"
            + metin.strip().splitlines()[-1][:300])
        k.destroy()
    except Exception:
        pass


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        _cokme_bildir(traceback.format_exc())
        raise
