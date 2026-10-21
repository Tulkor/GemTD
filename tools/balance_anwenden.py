#!/usr/bin/env python3
"""Übernimmt eine Änderungsdatei aus dem Balance-Editor (balance_aenderungen.json) ins Repo.

Aufruf aus dem Projektordner:
  python3 tools/balance_anwenden.py balance_aenderungen.json            übernehmen
  python3 tools/balance_anwenden.py balance_aenderungen.json --probe    nur anzeigen
  python3 tools/balance_anwenden.py ... --trotzdem                       auch Werte, die im Repo inzwischen anders sind
Jede Änderung hat datei, pfad (Liste), alt und neu. Steht im Repo nicht mehr "alt", wird sie ausgelassen
und gemeldet (Konflikt), außer mit --trotzdem. Das Format der Dateien bleibt (Tabs, Kommazahlen wie 1.0);
bei Tower-Daten wird die Tower-Tabelle erneuert und nach /mnt/project-files/balance/ kopiert.
"""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from daten import compact  # noqa: E402
from werte_setzen import detect_format  # noqa: E402


def like(old, new):
    """Kommazahlen bleiben Kommazahlen (1.0 statt 1), auch in Zahlenlisten wie Schaden [min, max]."""
    if isinstance(old, float) and isinstance(new, int) and not isinstance(new, bool):
        return float(new)
    if isinstance(old, list) and isinstance(new, list) and len(old) == len(new):
        return [like(o, n) for o, n in zip(old, new)]
    if isinstance(old, dict) and isinstance(new, dict):
        return {k: like(old.get(k), v) for k, v in new.items()}
    if isinstance(old, list) and isinstance(new, list):
        # Listen anderer Länge (z. B. Fähigkeiten): Einträge mit gleichem Typ als Vorbild
        return [like(next((o for o in old if isinstance(o, dict) and isinstance(n, dict) and o.get("type") == n.get("type")), None), n)
                for n in new]
    return new


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = {a for a in sys.argv[1:] if a.startswith("--")}
    if len(args) != 1:
        print(__doc__)
        return 1
    changes = json.loads(Path(args[0]).read_text(encoding="utf-8"))["aenderungen"]
    by_file = {}
    for c in changes:
        by_file.setdefault(c["datei"], []).append(c)
    done, skipped, towers = 0, 0, False
    for rel, cs in by_file.items():
        f = ROOT / rel
        if not f.is_file() or not rel.startswith("data/"):
            print(f"{rel}: Datei fehlt, {len(cs)} Änderungen ausgelassen")
            skipped += len(cs)
            continue
        text = f.read_text(encoding="utf-8")
        data = json.loads(text)
        fmt = detect_format(text, data)
        n = 0
        for c in cs:
            path = c["pfad"]
            try:
                parent = data
                for k in path[:-1]:
                    parent = parent[k]
                old = parent[path[-1]] if path else data
            except (KeyError, IndexError, TypeError):
                print(f"{rel} {'.'.join(map(str, path))}: Pfad gibt es nicht mehr, ausgelassen")
                skipped += 1
                continue
            label = f"{c.get('objekt') or rel} ({'.'.join(map(str, path)) or 'ganz'})"
            if old != c["alt"] and "--trotzdem" not in flags:
                print(f"KONFLIKT {label}: im Repo {compact(old)}, im Editor war es {compact(c['alt'])} -> ausgelassen")
                skipped += 1
                continue
            new = like(old, c["neu"])
            print(f"{label}: {compact(old)} -> {compact(new)}")
            if path:
                parent[path[-1]] = new
            else:
                data = new
            n += 1
        if n and "--probe" not in flags:
            indent, ea, nl = fmt or ("\t", False, True)
            f.write_text(json.dumps(data, indent=indent, ensure_ascii=ea) + ("\n" if nl else ""), encoding="utf-8")
            towers = towers or rel.startswith("data/towers/")
        done += n
    print(f"{done} übernommen, {skipped} ausgelassen" + (" (nur Probe, nichts geschrieben)" if "--probe" in flags else ""))
    if towers:
        r = subprocess.run([sys.executable, str(ROOT / "tools/tower_tabelle.py"), "--kopieren"], capture_output=True, text=True, cwd=ROOT)
        print("Tower-Tabelle: " + ("erneuert" if r.returncode == 0 else "FEHLER " + r.stderr.strip()[-300:]))
    return 1 if skipped and "--trotzdem" not in flags else 0


if __name__ == "__main__":
    sys.exit(main())
