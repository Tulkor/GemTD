#!/usr/bin/env python3
"""Werte in den JSON-Daten ändern, ohne die Datei zu lesen oder von Hand zu bearbeiten.

Gibt jede Änderung als alt -> neu aus, behält das Format der Datei (Tabs/Einrückung) bei,
erneuert bei Tower-Daten die Tower-Tabelle (auch in /mnt/project-files/balance/) und misst mit
--bericht die geänderten Tower gegen den letzten Commit (tools/balance_bericht.py --vergleich=HEAD).

Aufruf:
  python3 tools/werte_setzen.py tower:ruby tiers.5.damage=[200,220] tiers.5.cooldown=0.4
  python3 tools/werte_setzen.py tower:ruby 'tiers.*.range*=1.1'        alle Stufen, mal 1,1 (gerundet auf 2 Stellen)
  python3 tools/werte_setzen.py gegner:bat hp+=10 armor=8
  python3 tools/werte_setzen.py data/balance.json gold.start=60
  python3 tools/werte_setzen.py tower:ruby tiers.5.damage*=1.2 --bericht   danach Vorher/Nachher-Bericht
  python3 tools/werte_setzen.py ... --probe                                 nur anzeigen, nichts schreiben
Pfade wie in tools/daten.py: Punkte, Listenindex als Zahl, Listeneinträge auch über ihre id, * für alle.
Werte sind JSON (Zahl, [Liste], {Objekt}, true, null); alles andere wird als Text gespeichert.
+=, -= und *= gehen auf Zahlen und Zahlenlisten (z. B. Schaden [min, max]).
"""
import json
import re
import signal
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from daten import resolve, compact  # noqa: E402

ASSIGN = re.compile(r"^(.+?)\s*([+*\-]?=)\s*(.*)$")


def detect_format(text, data):
    for indent in ("\t", 2, 4):
        for ea in (False, True):
            out = json.dumps(data, indent=indent, ensure_ascii=ea)
            if text in (out, out + "\n"):
                return indent, ea, text.endswith("\n")
    return None


def targets(node, parts, done=""):
    """Alle (Eltern, Schlüssel, voller Pfad) für den Pfad; * geht über alle Einträge."""
    if not parts:
        return []
    head, rest = parts[0], parts[1:]
    keys = []
    if head == "*":
        keys = list(range(len(node))) if isinstance(node, list) else list(node)
    elif isinstance(node, list) and head.lstrip("-").isdigit():
        keys = [int(head)]
    elif isinstance(node, list):
        keys = [i for i, x in enumerate(node) if isinstance(x, dict) and x.get("id") == head]
        if not keys:
            raise KeyError(f"keine id '{head}' in der Liste")
    else:
        keys = [head]
    if not rest:
        return [(node, k, f"{done}{k}") for k in keys]
    out = []
    for k in keys:
        if isinstance(node, dict) and k not in node:
            raise KeyError(f"'{k}' fehlt, vorhanden: {', '.join(list(node)[:30])}")
        out += targets(node[k], rest, f"{done}{k}.")
    return out


def parse_value(s):
    try:
        return json.loads(s)
    except json.JSONDecodeError:
        return s


def apply(old, op, val):
    if op == "=":
        return val
    def one(x):
        if not isinstance(x, (int, float)) or isinstance(x, bool):
            raise ValueError(f"{op} geht nur auf Zahlen, nicht auf {compact(x)}")
        r = x + val if op == "+=" else x - val if op == "-=" else x * val
        return int(round(r)) if isinstance(x, int) and op == "*=" else round(r, 2) if isinstance(r, float) else r
    return [one(x) for x in old] if isinstance(old, list) else one(old)


def main():
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = {a for a in sys.argv[1:] if a.startswith("--")}
    if len(args) < 2:
        print(__doc__)
        return 2
    f = resolve(args[0]).resolve()
    text = f.read_text(encoding="utf-8")
    data = json.loads(text)
    fmt = detect_format(text, data)
    if fmt is None and "--umformatieren" not in flags:
        print(f"{f.relative_to(ROOT)} hat ein eigenes Format, das beim Schreiben verloren ginge. "
              "Von Hand ändern oder --umformatieren (schreibt mit Tabs) angeben.")
        return 1
    changed = 0
    for a in args[1:]:
        m = ASSIGN.match(a)
        if not m:
            print(f"Nicht verstanden: {a} (erwartet pfad=wert, pfad+=zahl, pfad*=faktor)")
            return 1
        path, op, raw = m.group(1).strip(), m.group(2), m.group(3)
        val = parse_value(raw)
        try:
            spots = targets(data, path.split("."))
        except (KeyError, IndexError) as e:
            print(f"{path}: Pfad nicht gefunden ({e})")
            return 1
        for parent, key, label in spots:
            exists = (isinstance(parent, dict) and key in parent) or isinstance(parent, list)
            old = parent[key] if exists else None
            if op != "=" and not exists:
                print(f"{path}: {key} fehlt, {op} geht nicht")
                return 1
            new = apply(old, op, val)
            print(f"{label}: {compact(old) if exists else '(neu)'} -> {compact(new)}")
            if new != old:
                parent[key] = new
                changed += 1
    if "--probe" in flags or not changed:
        print("Nichts geschrieben." if changed else "Keine Änderung.")
        return 0
    indent, ea, nl = fmt or ("\t", False, True)
    f.write_text(json.dumps(data, indent=indent, ensure_ascii=ea) + ("\n" if nl else ""), encoding="utf-8")
    print(f"Geschrieben: {f.relative_to(ROOT)} ({changed} Werte)")
    if f.parent.name == "towers":
        r = subprocess.run([sys.executable, str(ROOT / "tools/tower_tabelle.py"), "--kopieren"],
                           capture_output=True, text=True, cwd=ROOT)
        print("Tower-Tabelle: " + ((r.stdout.strip().splitlines() or ["erneuert"])[-1] if r.returncode == 0 else "FEHLER " + r.stderr.strip()[-300:]))
        if "--bericht" in flags:
            tiers = sorted({int(p.split(".")[1]) for p in (m.group(1) for m in map(ASSIGN.match, args[1:]))
                            if p.startswith("tiers.") and p.split(".")[1].isdigit()}) or [len(data.get("tiers", [])) - 1]
            sel = ",".join(f"{f.stem}:{t}" for t in tiers)
            print(f"Balance-Bericht für {sel} gegen HEAD läuft ...", flush=True)
            r = subprocess.run([sys.executable, str(ROOT / "tools/balance_bericht.py"), f"--tower={sel}",
                                "--vergleich=HEAD", f"--name=aenderung_{f.stem}"], cwd=ROOT, capture_output=True, text=True)
            out = r.stdout.strip().splitlines()
            md = next((w for line in out if line.startswith("BERICHT") for w in line.split() if w.endswith(".md")), None)
            if r.returncode or not md:
                print("Bericht fehlgeschlagen:", (r.stdout + r.stderr)[-800:])
                return 1
            # Nur die Tabelle ausgeben, damit die Datei nicht extra gelesen werden muss.
            print("\n".join(line for line in Path(md).read_text(encoding="utf-8").splitlines() if line.startswith("|")))
            print(out[-1])
    return 0


if __name__ == "__main__":
    sys.exit(main())
