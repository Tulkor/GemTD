#!/usr/bin/env python3
"""Wandelt ganze CC0-Modellpakete in kompakte .glb um: assets/models/pakete/<id>/<name>.glb.

Die Pakete stehen in tools/modelle/pakete.json (Quellordner, bevorzugtes Format, Texturgröße).
--quelle ist der Ordner mit den entpackten Zips (ein Unterordner je Zip).

    python3 -I tools/modelle/pakete_umwandeln.py --quelle=/pfad/zu/entpackt [--nur=q_monster,kk_wald] [--ziel=/tmp/x]

glTF/GLB rechnet umwandeln.pack_gltf (Texturen eingebettet und verkleinert), FBX geht über Godot
(umwandeln.gd), OBJ über trimesh. Je Modellname wird nur ein Format genommen. Am Ende steht je Paket
eine Liste in <ziel>/assets/models/pakete/<id>/LISTE.txt.
"""
import fnmatch
import json
import os
import re
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from umwandeln import ROOT, pack_gltf  # noqa: E402

PAKETE = os.path.join(ROOT, "tools", "modelle", "pakete.json")
ENDUNGEN = ("glb", "gltf", "fbx", "obj")


def slug(s):
    s = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", s)
    return re.sub(r"[^a-z0-9]+", "_", s.lower()).strip("_")


def sammeln(quelle, e):
    """Gibt {zielname: quelldatei} zurück, je Modellname das erste Format aus e["format"]."""
    rang = {f: i for i, f in enumerate(e["format"])}
    kandidaten = {}
    for muster in e["quellen"]:
        for ordner in sorted(fnmatch.filter(os.listdir(quelle), muster)):
            top = os.path.join(quelle, ordner)
            for d, _, files in os.walk(top, followlinks=True):
                if "__MACOSX" in d or "/." in d:
                    continue
                for f in files:
                    base, _, ext = f.rpartition(".")
                    ext = ext.lower()
                    if ext not in rang:
                        continue
                    name = slug(base)
                    if e.get("praefix"):
                        name = slug(ordner.split("-")[0].split("_Standard")[0]) + "_" + name
                    kandidaten.setdefault(name, []).append((rang[ext], len(d), os.path.join(d, f)))
    out = {}
    for name, liste in kandidaten.items():
        liste.sort()
        out[name] = liste[0][2]
    return out


def obj_zu_glb(src, dst, tex, shared):
    import trimesh
    scene = trimesh.load(src, force="scene", process=False)
    with tempfile.NamedTemporaryFile(suffix=".glb", delete=False) as f:
        tmp = f.name
    scene.export(tmp)
    pack_gltf(tmp, dst, tex, shared)
    os.unlink(tmp)


def main():
    quelle, ziel_root, nur = "", ROOT, []
    for a in sys.argv[1:]:
        if a.startswith("--quelle="):
            quelle = a[9:]
        elif a.startswith("--ziel="):
            ziel_root = a[7:]
        elif a.startswith("--nur="):
            nur = a[6:].split(",")
    if not quelle:
        sys.exit(__doc__)
    cfg = json.load(open(PAKETE))
    fbx = []
    gesamt = fehler = 0
    for pid, e in cfg.items():
        if pid.startswith("_") or (nur and pid not in nur):
            continue
        modelle = sammeln(quelle, e)
        if not modelle:
            print("LEER", pid)
            continue
        ziel = os.path.join(ziel_root, "assets", "models", "pakete", pid)
        os.makedirs(ziel, exist_ok=True)
        tex = int(e.get("tex", 256))
        shared = os.path.join(ziel, "texturen")
        ok = 0
        for name, src in sorted(modelle.items()):
            dst = os.path.join(ziel, name + ".glb")
            ext = src.rsplit(".", 1)[-1].lower()
            try:
                if ext == "fbx":
                    fbx.append({"src": src, "dst": dst, "tex": tex})
                    continue
                if ext == "obj":
                    obj_zu_glb(src, dst, tex, shared)
                else:
                    pack_gltf(src, dst, tex, shared)
                ok += 1
            except Exception as ex:  # noqa: BLE001 - ein kaputtes Modell soll das Paket nicht abbrechen
                print("FEHLER", pid, os.path.basename(src), type(ex).__name__, ex)
                fehler += 1
        gesamt += ok
        print("PAKET", pid, len(modelle), "Modelle,", ok, "direkt")
    if fbx:
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
            json.dump(fbx, f)
        godot = os.path.expanduser("~/.local/bin/godot")
        r = subprocess.run([godot, "--headless", "--path", ROOT, "-s", "tools/modelle/umwandeln.gd", "--", f.name],
                           capture_output=True, text=True)
        os.unlink(f.name)
        for line in r.stdout.splitlines() + r.stderr.splitlines():
            if line.startswith("OK "):
                dst = line[3:]
                pack_gltf(dst, dst, 256, os.path.join(os.path.dirname(dst), "texturen"))
                gesamt += 1
            elif line.startswith("FEHLER"):
                print(line)
                fehler += 1
    for pid in cfg:
        d = os.path.join(ziel_root, "assets", "models", "pakete", pid)
        if os.path.isdir(d) and (not nur or pid in nur):
            namen = sorted(f[:-4] for f in os.listdir(d) if f.endswith(".glb"))
            open(os.path.join(d, "LISTE.txt"), "w").write("\n".join(namen) + "\n")
    print("%d Modelle geschrieben, %d Fehler" % (gesamt, fehler))


if __name__ == "__main__":
    main()
