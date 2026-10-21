#!/usr/bin/env python3
"""Holt die verwendeten Modelle aus den entpackten CC0-Paketen nach assets/models/.

Die Auswahl steht in tools/modelle/auswahl.json: Zielpfad -> {"paket", "datei", "tex"}, bei FBX optional
"textur" (Bild im Paket, wird Grundfarbe aller Flächen mit Alpha-Ausschnitt, für Pflanzen-Karten).
Ein Paket ist ein entpackter Zip-Ordner; die Datei wird darin per Name gesucht.

Zum Ausprobieren: --auswahl=andere.json --ziel=/tmp/ordner (schreibt dorthin statt ins Repo).

    python3 -I tools/modelle/umwandeln.py --paket=kenney_nature=/pfad/Nature_Kit_2.1 --paket=...  [--nur=maul]

glTF/GLB rechnet das Skript selbst (Texturen einbetten, auf höchstens "tex" Pixel verkleinern,
Normal- und Zusatzkarten weglassen). FBX geht über Godot (tools/modelle/umwandeln.gd).
Fehlt ein Paket, werden seine Modelle übersprungen (bestehende Dateien bleiben).
"""
import io
import json
import os
import struct
import subprocess
import sys
import tempfile

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
AUSWAHL = os.path.join(ROOT, "tools", "modelle", "auswahl.json")


def find(root, name):
    hits = []
    for d, _, files in os.walk(root):
        if "__MACOSX" in d:
            continue
        if name in files:
            hits.append(os.path.join(d, name))
    # GLB-Ordner vor anderen Formaten
    hits.sort(key=lambda p: ("GLB" not in p and "glTF" not in p and "GLTF" not in p, len(p)))
    return hits[0] if hits else None


def read_gltf(path):
    """Gibt (json, binärpuffer) zurück; externe .bin werden zu einem Puffer zusammengefasst."""
    data = open(path, "rb").read()
    base = os.path.dirname(path)
    if data[:4] == b"glTF":
        n = struct.unpack("<I", data[12:16])[0]
        js = json.loads(data[20:20 + n])
        off = 20 + n
        bin_ = b""
        if off < len(data):
            m = struct.unpack("<I", data[off:off + 4])[0]
            bin_ = data[off + 8:off + 8 + m]
        return js, bin_, base
    js = json.loads(data)
    blob = b""
    for i, b in enumerate(js.get("buffers", [])):
        raw = open(os.path.join(base, b["uri"]), "rb").read()
        shift = len(blob)
        blob += raw + b"\0" * (-len(raw) % 4)
        for v in js.get("bufferViews", []):
            if v.get("buffer", 0) == i:
                v["buffer"] = 0
                v["byteOffset"] = v.get("byteOffset", 0) + shift
    js["buffers"] = [{"byteLength": len(blob)}]
    return js, blob, base


def compact(js, blob, keep_uv):
    """Tangenten (und UVs ohne Texturen) weglassen, nur noch benutzte Pufferteile behalten."""
    for m in js.get("meshes", []):
        for p in m["primitives"]:
            p["attributes"].pop("TANGENT", None)
            if not keep_uv:
                for k in [k for k in p["attributes"] if k.startswith("TEXCOORD")]:
                    p["attributes"].pop(k)
    used_acc = set()
    for m in js.get("meshes", []):
        for p in m["primitives"]:
            used_acc.update(p["attributes"].values())
            if "indices" in p:
                used_acc.add(p["indices"])
            for t in p.get("targets", []):
                used_acc.update(t.values())
    for sk in js.get("skins", []):
        if "inverseBindMatrices" in sk:
            used_acc.add(sk["inverseBindMatrices"])
    for an in js.get("animations", []):
        for sm in an.get("samplers", []):
            used_acc.update((sm["input"], sm["output"]))
    acc_map = {}
    accessors = []
    for i, a in enumerate(js.get("accessors", [])):
        if i in used_acc:
            acc_map[i] = len(accessors)
            accessors.append(a)
    used_views = {a["bufferView"] for a in accessors if "bufferView" in a}
    used_views |= {im["bufferView"] for im in js.get("images", []) if "bufferView" in im}
    view_map = {}
    views = []
    out = bytearray()
    for i, v in enumerate(js.get("bufferViews", [])):
        if i not in used_views:
            continue
        out += b"\0" * (-len(out) % 4)
        start = v.get("byteOffset", 0)
        chunk = blob[start:start + v["byteLength"]]
        v = dict(v, buffer=0, byteOffset=len(out))
        out += chunk
        view_map[i] = len(views)
        views.append(v)
    for a in accessors:
        if "bufferView" in a:
            a["bufferView"] = view_map[a["bufferView"]]
    for im in js.get("images", []):
        if "bufferView" in im:
            im["bufferView"] = view_map[im["bufferView"]]
    for m in js.get("meshes", []):
        for p in m["primitives"]:
            p["attributes"] = {k: acc_map[v] for k, v in p["attributes"].items()}
            if "indices" in p:
                p["indices"] = acc_map[p["indices"]]
            p["targets"] = [{k: acc_map[v] for k, v in t.items()} for t in p.get("targets", [])]
            if not p["targets"]:
                p.pop("targets")
    for sk in js.get("skins", []):
        if "inverseBindMatrices" in sk:
            sk["inverseBindMatrices"] = acc_map[sk["inverseBindMatrices"]]
    for an in js.get("animations", []):
        for sm in an.get("samplers", []):
            sm["input"], sm["output"] = acc_map[sm["input"]], acc_map[sm["output"]]
    js["accessors"] = accessors
    js["bufferViews"] = views
    out += b"\0" * (-len(out) % 4)
    return out


def pack_gltf(src, dst, tex_max):
    js, blob, base = read_gltf(src)
    blob = bytearray(blob)
    # Nur Grundfarbe behalten
    for m in js.get("materials", []):
        for k in ("normalTexture", "occlusionTexture", "emissiveTexture"):
            m.pop(k, None)
        m.get("pbrMetallicRoughness", {}).pop("metallicRoughnessTexture", None)
    used = set()
    for m in js.get("materials", []):
        t = m.get("pbrMetallicRoughness", {}).get("baseColorTexture")
        if t:
            used.add(js["textures"][t["index"]]["source"])
    images = js.get("images", [])
    remap = {}
    new_images = []
    for i, im in enumerate(images):
        if i not in used:
            continue
        if "uri" in im:
            raw = open(os.path.join(base, im["uri"]), "rb").read()
        else:
            v = js["bufferViews"][im["bufferView"]]
            raw = bytes(blob[v.get("byteOffset", 0):v.get("byteOffset", 0) + v["byteLength"]])
        pic = Image.open(io.BytesIO(raw))
        pic.load()
        if max(pic.size) > tex_max:
            f = tex_max / max(pic.size)
            pic = pic.resize((max(1, round(pic.width * f)), max(1, round(pic.height * f))), Image.LANCZOS)
        out = io.BytesIO()
        pic.save(out, "PNG", optimize=True)
        png = out.getvalue()
        blob += b"\0" * (-len(blob) % 4)
        js.setdefault("bufferViews", []).append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(png)})
        blob += png
        remap[i] = len(new_images)
        new_images.append({"bufferView": len(js["bufferViews"]) - 1, "mimeType": "image/png", "name": im.get("name", "")})
    textures = []
    tex_remap = {}
    for i, t in enumerate(js.get("textures", [])):
        if t.get("source") in remap:
            tex_remap[i] = len(textures)
            textures.append(dict(t, source=remap[t["source"]]))
    for m in js.get("materials", []):
        t = m.get("pbrMetallicRoughness", {}).get("baseColorTexture")
        if t:
            t["index"] = tex_remap[t["index"]]
    for k, v in (("images", new_images), ("textures", textures)):
        if v:
            js[k] = v
        else:
            js.pop(k, None)
    if not textures:
        js.pop("samplers", None)
    blob = compact(js, blob, keep_uv=bool(textures))
    js["buffers"] = [{"byteLength": len(blob)}]
    head = json.dumps(js, separators=(",", ":")).encode()
    head += b" " * (-len(head) % 4)
    total = 12 + 8 + len(head) + 8 + len(blob)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    with open(dst, "wb") as f:
        f.write(b"glTF" + struct.pack("<II", 2, total))
        f.write(struct.pack("<I", len(head)) + b"JSON" + head)
        f.write(struct.pack("<I", len(blob)) + b"BIN\0" + bytes(blob))


def main():
    pakete = {}
    nur = ""
    auswahl_datei, ziel_root = AUSWAHL, ROOT
    for a in sys.argv[1:]:
        if a.startswith("--paket="):
            k, v = a[8:].split("=", 1)
            pakete[k] = v
        elif a.startswith("--nur="):
            nur = a[6:]
        elif a.startswith("--auswahl="):
            auswahl_datei = a[10:]
        elif a.startswith("--ziel="):
            ziel_root = a[7:]
    auswahl = json.load(open(auswahl_datei))
    fbx = []
    done = skipped = 0
    for ziel, e in auswahl.items():
        if ziel.startswith("_") or (nur and nur not in ziel):
            continue
        if e["paket"] not in pakete:
            skipped += 1
            continue
        src = find(pakete[e["paket"]], e["datei"])
        if not src:
            print("FEHLT", e["paket"], e["datei"])
            continue
        dst = os.path.join(ziel_root, ziel)
        tex = int(e.get("tex", 256))
        if src.lower().endswith(".fbx"):
            item = {"src": src, "dst": dst, "tex": tex}
            if "textur" in e:  # FBX ohne gefundene Textur (z. B. Yughues): Grundfarbe mit Alpha-Ausschnitt setzen
                item["textur"] = find(pakete[e["paket"]], e["textur"])
            fbx.append(item)
        else:
            pack_gltf(src, dst, tex)
            print("OK", ziel, os.path.getsize(dst) // 1024, "KB")
            done += 1
    if fbx:
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
            json.dump(fbx, f)
        godot = os.path.expanduser("~/.local/bin/godot")
        r = subprocess.run([godot, "--headless", "--path", ROOT, "-s", "tools/modelle/umwandeln.gd", "--", f.name],
                           capture_output=True, text=True)
        os.unlink(f.name)
        for line in r.stdout.splitlines() + r.stderr.splitlines():
            if line.startswith(("OK", "FEHLER")):
                if line.startswith("OK"):
                    dst = line[3:]
                    pack_gltf(dst, dst, 256)  # Godot schreibt Tangenten mit, hier wieder verkleinern
                    line = "OK %s %d KB" % (os.path.relpath(dst, ziel_root), os.path.getsize(dst) // 1024)
                    done += 1
                print(line)
    print("%d Modelle geschrieben, %d übersprungen (Paket nicht angegeben)" % (done, skipped))


if __name__ == "__main__":
    main()
