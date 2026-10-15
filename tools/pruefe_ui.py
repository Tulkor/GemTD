#!/usr/bin/env python3
"""Prüft Oberflächen-Texte und Arcade-Stil.

Aufruf: python3 tools/pruefe_ui.py [--alle] [--stil] [--vorlage] [--eintragen=datei.json]
  - Texte: sichtbare deutsche Texte im Code (tr("…"), text = "…", tooltip_text = "…") ohne Eintrag
    in data/i18n/en.json, und Einträge mit leerer Übersetzung. Exit-Code 1, wenn etwas fehlt.
  - --alle: zusätzlich Einträge in en.json auflisten, die im Code nicht (mehr) vorkommen (nur Hinweis).
  - --stil: Farben und Schriften in scripts/ui/ und scripts/game/*panel*/hud, die nicht aus ui_theme.gd
    kommen (Color(…), Color.html, "#…"). Nur Hinweis, kein Fehler, weil 3D-Farben erlaubt sind.
  - --vorlage: fehlende Texte als JSON {"deutsch": ""} nach /tmp/gemtd-uebersetzen.json schreiben.
    Claude füllt nur die englischen Werte aus und trägt sie mit --eintragen ein, ohne en.json zu lesen.
  - --eintragen=datei.json: nicht leere Einträge der Datei ans Ende von en.json anhängen
    (vorhandene Schlüssel bleiben unverändert), danach normal prüfen.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
EN = ROOT / "data" / "i18n" / "en.json"
PATTERNS = [
    re.compile(r'\btr\(\s*"((?:[^"\\]|\\.)*)"'),
    re.compile(r'\b(?:text|tooltip_text|placeholder_text|title)\s*=\s*"((?:[^"\\]|\\.)*)"'),
    re.compile(r'\.(?:set_text|add_item|add_tab|set_tooltip_text)\(\s*"((?:[^"\\]|\\.)*)"'),
    re.compile(r'\b(?:UiUtil|UiTheme)\.\w+\([^"()]*"((?:[^"\\]|\\.)*)"'),
    re.compile(r'"(?:label|text|tooltip|title)"\s*:\s*"((?:[^"\\]|\\.)*)"'),
]
# Texte ohne Buchstaben oder reine Symbole/Zahlen brauchen keine Übersetzung.
NEEDS = re.compile(r"[A-Za-zÄÖÜäöüß]{2,}")
# Eigennamen und Theme-Schlüssel, die gleich bleiben.
IGNORE = {"DPS", "GemTD", "eeveTD", "Shopping Maul", "hover", "normal", "pressed", "disabled", "focus", "panel"}
COLOR = re.compile(r'Color\(\s*[0-9.]|Color\.html\(|Color\.from_hsv\(|"#[0-9a-fA-F]{6}')


def unescape(s):
    return s.encode("utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8")


VORLAGE = pathlib.Path("/tmp/gemtd-uebersetzen.json")


def eintragen(path):
    text = EN.read_text(encoding="utf-8")
    en = json.loads(text)
    neu = {k: v for k, v in json.loads(pathlib.Path(path).read_text(encoding="utf-8")).items()
           if str(v).strip() and k not in en}
    if neu:
        body = text.rstrip()
        assert body.endswith("}"), "en.json endet nicht mit }"
        lines = ",\n".join("\t%s: %s" % (json.dumps(k, ensure_ascii=False), json.dumps(v, ensure_ascii=False))
                           for k, v in neu.items())
        EN.write_text(body[:-1].rstrip() + ",\n" + lines + "\n}\n", encoding="utf-8")
    print("Eingetragen: %d neue Übersetzungen" % len(neu))


def main():
    for a in sys.argv[1:]:
        if a.startswith("--eintragen="):
            eintragen(a.split("=", 1)[1])
    pairs = json.loads(EN.read_text(encoding="utf-8"), object_pairs_hook=lambda p: p)
    en = dict(pairs)
    seen = set()
    double = [k for k, _ in pairs if k in seen or seen.add(k)]
    used = {}
    for f in sorted((ROOT / "scripts").rglob("*.gd")):
        for no, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
            if line.lstrip().startswith("#"):
                continue
            for pat in PATTERNS:
                for m in pat.finditer(line):
                    try:
                        s = unescape(m.group(1))
                    except UnicodeError:
                        s = m.group(1)
                    if NEEDS.search(s) and s not in IGNORE:
                        used.setdefault(s, "%s:%d" % (f.relative_to(ROOT), no))
    missing = {s: where for s, where in used.items() if s not in en}
    empty = [k for k, v in en.items() if str(v).strip() == ""]
    for s, where in sorted(missing.items(), key=lambda x: x[1]):
        print("FEHLT  %s  %r" % (where, s))
    for k in empty:
        print("LEER   en.json  %r" % k)
    for k in double:
        print("DOPPELT en.json  %r" % k)
    if "--alle" in sys.argv:
        code = "\n".join(f.read_text(encoding="utf-8") for f in (ROOT / "scripts").rglob("*.gd"))
        data = "\n".join(f.read_text(encoding="utf-8") for f in (ROOT / "data").rglob("*.json") if f != EN)
        for k in en:
            if json.dumps(k, ensure_ascii=False)[1:-1] not in code and k not in data:
                print("UNBENUTZT? %r" % k)
    if "--stil" in sys.argv:
        files = list((ROOT / "scripts" / "ui").glob("*.gd")) + [
            f for f in (ROOT / "scripts" / "game").glob("*.gd") if "panel" in f.name or f.name in ("hud.gd", "tower_list.gd", "dps_meter.gd")]
        for f in sorted(files):
            if f.name == "ui_theme.gd":
                continue
            for no, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
                if COLOR.search(line) and not line.lstrip().startswith("#"):
                    print("STIL   %s:%d  %s" % (f.relative_to(ROOT), no, line.strip()[:90]))
    if "--vorlage" in sys.argv and missing:
        VORLAGE.write_text(json.dumps({k: "" for k in missing}, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")
        print("Vorlage: %s (%d Texte, englische Werte eintragen, dann --eintragen=%s)" % (VORLAGE, len(missing), VORLAGE))
    print("Texte: %d geprüft, %d ohne Übersetzung, %d leer" % (len(used), len(missing), len(empty)))
    if double:
        print("%d Schlüssel doppelt in en.json (meist ein Merge-Rest, späteren Eintrag löschen)" % len(double))
    sys.exit(1 if missing or empty or double else 0)


if __name__ == "__main__":
    main()
