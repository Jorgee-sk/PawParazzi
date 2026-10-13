"""Prueba el servicio de revisión con fotos de ejemplo y muestra las puntuaciones.

Uso (con el servicio en marcha):
    python moderation/test_images.py                 # descarga una muestra de Wikimedia Commons
    python moderation/test_images.py carpeta/        # usa tus propias fotos (el nombre da igual)

Sirve para ajustar los umbrales (MODERATION_*_THRESHOLD) y las frases de prompts.py.
Solo usa la biblioteca estándar de Python.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

SERVICE = os.environ.get("MODERATION_URL", "http://localhost:8090")
THRESHOLDS = {
    "animal": float(os.environ.get("MODERATION_ANIMAL_THRESHOLD", "0.5")),
    "violence": float(os.environ.get("MODERATION_VIOLENCE_THRESHOLD", "0.85")),
    "sexual": float(os.environ.get("MODERATION_SEXUAL_THRESHOLD", "0.85")),
}
AGENT = {"User-Agent": "PawParazziModerationTest/1.0 (desarrollo local)"}

# (búsqueda en Commons, qué esperamos: "ok" = se acepta como publicación,
#  "no-animal" = se rechaza por no haber animal, "violence"/"sexual" = se rechaza por seguridad)
SAMPLE = [
    ("dog playing park", "ok"), ("cat sleeping sofa", "ok"), ("kitten", "ok"), ("pet parrot", "ok"),
    ("hamster", "ok"), ("pet rabbit", "ok"), ("goldfish aquarium", "ok"), ("woman with dog", "ok"),
    ("dog running blurry", "ok"), ("black cat dark", "ok"), ("tortoise pet", "ok"), ("horse", "ok"),
    ("portrait man face", "no-animal"), ("pizza", "no-animal"), ("mountain landscape", "no-animal"),
    ("city street", "no-animal"), ("car parked", "no-animal"), ("teddy bear toy", "no-animal"),
    ("cartoon dog drawing", "no-animal"), ("screenshot software", "no-animal"),
    ("living room interior", "no-animal"), ("people beach summer", "no-animal"),
    ("boxing match punch", "violence"), ("roadkill", "violence"), ("bleeding wound", "violence"),
    ("dog at veterinarian", "ok"), ("dogs play fighting", "ok"), ("dog bandage paw", "ok"),
    ("nude photography", "sexual"), ("nude statue", "sexual?"),
]


def commons_images(query: str, count: int = 2) -> list[tuple[str, bytes]]:
    params = urllib.parse.urlencode({
        "action": "query", "format": "json", "generator": "search", "gsrsearch": f"{query} filetype:bitmap",
        "gsrnamespace": 6, "gsrlimit": count, "prop": "imageinfo", "iiprop": "url", "iiurlwidth": 640,
    })
    request = urllib.request.Request(f"https://commons.wikimedia.org/w/api.php?{params}", headers=AGENT)
    pages = {}
    for attempt in range(4):  # Commons limita la frecuencia: pausas y reintentos
        time.sleep(1.5 * (attempt + 1))
        try:
            pages = json.load(urllib.request.urlopen(request, timeout=30)).get("query", {}).get("pages", {})
            break
        except urllib.error.HTTPError as error:
            if error.code != 429:
                raise
    found = []
    for page in pages.values():
        info = page.get("imageinfo", [{}])[0]
        url = info.get("thumburl")
        if not url or not urllib.parse.urlparse(url).path.lower().endswith((".jpg", ".jpeg", ".png")):
            continue
        try:
            time.sleep(1)
            data = urllib.request.urlopen(urllib.request.Request(url, headers=AGENT), timeout=30).read()
            found.append((page["title"].removeprefix("File:")[:38], data))
        except Exception as error:  # noqa: BLE001 - una descarga fallida no detiene la prueba
            print(f"  (no se pudo descargar {url}: {error})")
    return found


def classify(data: bytes) -> dict:
    request = urllib.request.Request(f"{SERVICE}/classify", data=data, headers={"Content-Type": "image/jpeg"})
    return json.load(urllib.request.urlopen(request, timeout=30))


def verdict(scores: dict) -> str:
    if scores["violence"] >= THRESHOLDS["violence"]:
        return "violence"
    if scores["sexual"] >= THRESHOLDS["sexual"]:
        return "sexual"
    return "ok" if scores["animal"] >= THRESHOLDS["animal"] else "no-animal"


def main() -> None:
    if len(sys.argv) > 1:
        folder = sys.argv[1]
        items = [(name, "?", open(os.path.join(folder, name), "rb").read()) for name in sorted(os.listdir(folder))
                 if name.lower().endswith((".jpg", ".jpeg", ".png"))]
    else:
        items = [(f"{query} | {title}", expected, data)
                 for query, expected in SAMPLE for title, data in commons_images(query)]
    print(f"{'imagen':<62} {'animal':>6} {'viol.':>6} {'sexual':>6} {'ms':>4}  veredicto (esperado)")
    right = wrong = 0
    for name, expected, data in items:
        scores = classify(data)
        got = verdict(scores)
        mark = ""
        if expected not in ("?", "sexual?"):
            if got == expected:
                right += 1
            else:
                wrong += 1
                mark = "  <-- DISTINTO"
        print(f"{name[:62]:<62} {scores['animal']:6.2f} {scores['violence']:6.2f} {scores['sexual']:6.2f} "
              f"{scores['millis']:4d}  {got} ({expected}){mark}")
    if right + wrong:
        print(f"\nCoinciden con lo esperado: {right} de {right + wrong}")


if __name__ == "__main__":
    main()
