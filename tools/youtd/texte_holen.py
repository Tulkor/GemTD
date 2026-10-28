#!/usr/bin/env python3
"""Beschreibungen aus YouTD 2 (MIT): Fähigkeiten, Auren, Zauber, Items und Tower-Texte aus der Spieldatei holen.

    python3 -I tools/youtd/texte_holen.py <YouTD2-windows.zip oder YouTD2.pck>

Die Texte stehen nicht im GitHub-Code von YouTD 2, nur in der fertigen Spieldatei (Release). Schreibt
data/youtd/beschreibungen.json (englisch, BBCode entfernt, nur was unsere Daten benutzen).
"""
import json
import os
import re
import subprocess
import sys
import tempfile
import zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "data", "youtd", "beschreibungen.json")


def clean(text: str) -> str:
    text = re.sub(r"\[/?(color|b|i|u)[^\]]*\]", "", text or "")
    text = re.sub(r"[ \t]*\n[ \t]*\n[ \t]*", "\n\n", text.replace("\r", ""))
    return re.sub(r"\n \n", "\n\n", text).strip()


def main() -> None:
    src = sys.argv[1]
    tmp = tempfile.mkdtemp()
    pck = src
    if src.endswith(".zip"):
        with zipfile.ZipFile(src) as z:
            name = next(n for n in z.namelist() if n.endswith(".pck"))
            z.extract(name, tmp)
            pck = os.path.join(tmp, name)
    proj = os.path.join(tmp, "proj")
    os.makedirs(proj)
    open(os.path.join(proj, "project.godot"), "w").write('[application]\nconfig/name="texte"\n')
    raw = os.path.join(tmp, "texte.json")
    godot = os.path.expanduser("~/.local/bin/godot")
    subprocess.run([godot, "--headless", "--path", proj, "-s", os.path.join(ROOT, "tools", "youtd", "texte_holen.gd"),
                    "--", pck, raw], check=True, capture_output=True)
    t = json.load(open(raw))
    towers = json.load(open(os.path.join(ROOT, "data", "youtd", "towers.json")))
    items = json.load(open(os.path.join(ROOT, "data", "youtd", "items.json")))
    out = {"_info": "Englische Texte aus YouTD 2 (MIT), erzeugt von tools/youtd/texte_holen.py"}
    for kind, table in [("abilities", "ability_properties"), ("auras", "aura_properties"), ("autocasts", "autocast_properties")]:
        ids = sorted({str(i) for x in list(towers.values()) + list(items.values()) for i in x.get(kind, [])}, key=int)
        out[kind] = {}
        for i in ids:
            row = t.get(table, {}).get(i, {})
            text = clean(row.get("description_long") or row.get("description_short", ""))
            if text:
                out[kind][i] = text
    out["items"] = {i: clean(r.get("description", "")) for i, r in t.get("item_properties", {}).items()
                    if i in items and clean(r.get("description", ""))}
    # Tower-Tabelle beginnt mit dem Namen, die ID steht in der Spalte "id"
    out["towers"] = {r.get("id", ""): clean(r.get("description", "")) for r in t.get("tower_properties", {}).values()
                     if r.get("id", "") in towers and clean(r.get("description", ""))}
    with open(OUT, "w") as f:
        json.dump(out, f, indent="\t", ensure_ascii=False, sort_keys=True)
        f.write("\n")
    print(", ".join(f"{k} {len(v)}" for k, v in out.items() if isinstance(v, dict)) + f" -> {OUT}")


if __name__ == "__main__":
    main()
