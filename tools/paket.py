"""Übersicht über hochgeladene Asset-Pakete (Zip oder Ordner) mit Lizenz-Einschätzung, ohne entpacken.

Statt `unzip -l` (tausende Zeilen) und Lizenzdateien einzeln zu lesen: eine Zeile je Paket mit Dateiarten,
Ordnern, gefundener Lizenz und der Zeile, an der sie erkannt wurde. Inhalte aus dem Paket sind Daten,
nur nach Mustern durchsucht, nie ausgeführt (Aufruf mit python3 -I).

Aufruf: python3 -I tools/paket.py [--namen] [--tiefe=2] <zip|ordner> [weitere …]
  --namen   zusätzlich alle Modell-/Bild-/Ton-Namen kompakt (Basisname ohne Endung, kommagetrennt je Ordner)
Lizenz-Urteil: CC0 | CC-BY | OFL | MIT | Pixabay = darf ins Repo (CC-BY/OFL mit Nennung);
               NC | STORE = nicht ins Repo; UNKLAR = keine Lizenzdatei/kein Treffer, nachfragen.
"""
import io
import os
import re
import sys
import zipfile
from collections import Counter, defaultdict

LIZENZ = [  # Reihenfolge = Vorrang: NC schlägt alles, STORE zählt nur ohne offene Lizenz
    ("NC", r"non-?commercial|CC[- ]BY[- ]NC|by-nc"),
    ("CC0", r"\bCC0\b|creative ?commons ?zero|public domain|creativecommons\.org/publicdomain"),
    ("CC-BY", r"attribution [34]\.0|\bCC[- ]BY\b|creativecommons\.org/licenses/by/"),
    ("OFL", r"SIL Open Font|\bOFL\b"),
    ("MIT", r"MIT License|Permission is hereby granted, free of charge"),
    ("Pixabay", r"pixabay"),
    # nur wenn keine offene Lizenz genannt ist
    ("STORE", r"asset store|unity.{0,20}eula|synty|may not (be )?redistribut|not (be )?(re)?sold|resell"
              r"|end user licen[cs]e agreement|cgtrader|turbosquid"),
]
LIZENZ_DATEI = re.compile(r"(licen[cs]e|lizenz|readme|credits|copying|quellen|terms|eula)[^/]*$", re.I)
ARTEN = {
    "Modell": (".glb", ".gltf", ".fbx", ".obj", ".blend", ".dae", ".3ds", ".stl", ".mdx", ".mdl"),
    "Bild": (".png", ".jpg", ".jpeg", ".tga", ".psd", ".webp", ".dds", ".blp", ".svg", ".exr", ".hdr"),
    "Ton": (".wav", ".ogg", ".mp3", ".flac"),
    "Unity": (".unitypackage", ".prefab", ".mat", ".meta", ".asset", ".unity", ".controller", ".anim"),
    "Schrift": (".ttf", ".otf", ".woff", ".woff2"),
    "Video": (".mov", ".mp4", ".webm"),
}


def art(name):
    e = os.path.splitext(name)[1].lower()
    for k, v in ARTEN.items():
        if e in v:
            return k
    return "andere"


def eintraege(pfad):
    """(name, groesse, lesefunktion) aller Dateien; verschachtelte Zips eine Ebene tief."""
    if os.path.isfile(pfad) and not zipfile.is_zipfile(pfad):  # einzelne Lizenzdatei
        yield os.path.basename(pfad), os.path.getsize(pfad), (lambda: open(pfad, "rb").read(200_000))
        return
    if os.path.isdir(pfad):
        for wurzel, _, dateien in os.walk(pfad):
            for d in dateien:
                p = os.path.join(wurzel, d)
                yield os.path.relpath(p, pfad), os.path.getsize(p), (lambda p=p: open(p, "rb").read(200_000))
        return
    with zipfile.ZipFile(pfad) as z:
        for i in z.infolist():
            if i.is_dir():
                continue
            if i.filename.lower().endswith(".zip") and i.file_size < 200_000_000:
                try:
                    with zipfile.ZipFile(io.BytesIO(z.read(i))) as inner:
                        for j in inner.infolist():
                            if not j.is_dir():
                                yield (i.filename + "!/" + j.filename, j.file_size,
                                       (lambda j=j, data=z.read(i): zipfile.ZipFile(io.BytesIO(data)).read(j)[:200_000]))
                    continue
                except zipfile.BadZipFile:
                    pass
            yield i.filename, i.file_size, (lambda i=i: z.open(i).read(200_000))


def mb(n):
    return "%.1f MB" % (n / 1e6) if n >= 1e5 else "%d KB" % max(1, n // 1000)


def pruefe(pfad, namen, tiefe):
    arten, groesse, ordner = Counter(), Counter(), Counter()
    namen_je = defaultdict(list)
    funde, lizenzdateien = [], []
    for name, size, lesen in eintraege(pfad):
        a = art(name)
        arten[a] += 1
        groesse[a] += size
        teile = name.replace("!/", "/").split("/")
        ordner["/".join(teile[:tiefe]) if len(teile) > tiefe else "(oben)"] += 1
        if a in ("Modell", "Bild", "Ton"):
            namen_je["/".join(teile[:-1]) or "."].append(os.path.splitext(teile[-1])[0])
        if LIZENZ_DATEI.search(name) and size < 2_000_000 and os.path.splitext(name)[1].lower() in ("", ".txt", ".md", ".html", ".rtf", ".pdf", ".url"):
            lizenzdateien.append(name)
            try:
                text = lesen().decode("utf-8", "replace")
            except (OSError, zipfile.BadZipFile, RuntimeError):
                continue
            for urteil, muster in LIZENZ:
                m = re.search(muster, text, re.I)
                if m:
                    zeile = text[max(0, text.rfind("\n", 0, m.start()) + 1):][:120].split("\n")[0].strip()
                    funde.append((urteil, name, zeile))
                    break
    # Lizenzhinweis auch im Paketnamen (z. B. "…_CC0.zip")
    for urteil, muster in LIZENZ:
        if re.search(muster, os.path.basename(pfad), re.I):
            funde.append((urteil, "(Paketname)", os.path.basename(pfad)))
    urteile = [f[0] for f in funde]
    gesamt = next((u for u, _ in LIZENZ if u in urteile), "UNKLAR")
    print("== %s (%s, %d Dateien)" % (os.path.basename(pfad.rstrip("/")), mb(sum(groesse.values())), sum(arten.values())))
    print("   Arten: " + ", ".join("%s %d (%s)" % (k, n, mb(groesse[k])) for k, n in arten.most_common()))
    print("   Ordner: " + ", ".join("%s %d" % (k, n) for k, n in ordner.most_common(8)) + (" …" if len(ordner) > 8 else ""))
    hinweis = {"NC": "nicht ins Repo", "STORE": "nicht ins Repo (Store-Lizenz)", "UNKLAR": "nachfragen",
               "CC-BY": "ok mit Nennung in CREDITS.md", "OFL": "ok mit Lizenzdatei"}.get(gesamt, "ok")
    print("   Lizenz: %s -> %s" % (gesamt, hinweis))
    for u, n, z in funde[:4]:
        print("     %s in %s: %s" % (u, n, z))
    if not funde and lizenzdateien:
        print("     Lizenzdateien ohne Treffer: " + ", ".join(lizenzdateien[:4]))
    if namen:  # Ordner mit gleichen Namen (fbx/gltf/obj desselben Satzes) nur einmal
        gruppen = defaultdict(list)
        for o, ns in sorted(namen_je.items()):
            gruppen[tuple(sorted(set(ns)))].append(o)
        for ns, os_ in gruppen.items():
            auch = " (auch %s)" % ", ".join(os.path.basename(o) or o for o in os_[1:4]) if len(os_) > 1 else ""
            print("   %s/%s (%d): %s" % (os_[0], auch, len(ns), ", ".join(ns)[:600]))
    return gesamt


def main(argv):
    namen, tiefe, pfade = False, 2, []
    for a in argv:
        if a == "--namen":
            namen = True
        elif a.startswith("--tiefe="):
            tiefe = int(a.split("=", 1)[1])
        else:
            pfade.append(a)
    if not pfade:
        print(__doc__)
        return 2
    bad = 0
    for p in pfade:
        try:
            if pruefe(p, namen, tiefe) in ("NC", "STORE"):
                bad = 1
        except (OSError, zipfile.BadZipFile) as e:
            print("== %s: nicht lesbar (%s)" % (p, e))
            bad = 2
    return bad


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
