"""Tabellen für docs/randgruppentd.md aus den erzeugten Daten (Rassen mit Towern, Level).

    python3 -I tools/wc3/randgruppen/rg_md.py > /tmp/rg_tabellen.md
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
rules = json.load(open(ROOT / "data/randgruppen.json"))
T = {p.stem: json.load(open(p)) for p in (ROOT / "data/towers").glob("rg_*.json")}
E = {p.stem: json.load(open(p)) for p in (ROOT / "data/enemies").glob("rg_*.json")}
DT = {"normal": "Normal", "pierce": "Durchbohrend", "siege": "Belagerung", "magic": "Magie", "chaos": "Chaos",
      "spells": "Zauber", "hero": "Held"}


def num(v):
    return ("%.2f" % v).rstrip("0").rstrip(".")


def abil(a):
    if a["type"] == "splash":
        return "Fläche %s" % num(a["radius"])
    if a["type"] == "slow":
        return "verlangsamt %d %%" % round(a["factor"] * 100)
    if a["type"] == "poison":
        return "Gift %s/s" % num(a["dps"])
    return a["type"]


for race in rules["races"]:
    print("#### %s\n\n%s\n" % (race["name"], race["hint"]))
    print("| # | Tower | Gold | Schaden | Abkl. s | DPS | Reichw. | Art | Besonderes |")
    print("|---|---|---|---|---|---|---|---|---|")
    for i, tid in enumerate(race["towers"]):
        t = T[tid]
        tr = t["tiers"][0]
        lo, hi = tr["damage"]
        dps = (lo + hi) / 2 / tr["cooldown"]
        extra = ", ".join(abil(a) for a in tr["abilities"])
        if t["rg"]["ultimate"]:
            extra = ("1 Holz, braucht die anderen 6" + (", " + extra if extra else ""))
        print("| %d | %s | %d | %d–%d | %s | %d | %s | %s | %s |" % (
            i + 1, t["name"], t["rg"]["cost"], lo, hi, num(tr["cooldown"]), dps, num(tr["range"]),
            DT.get(t["damage_type"], t["damage_type"]), extra))
    print()

print("| Level | Gegner | Leben | Rüstung | Art | Tempo | Kopfgeld | Je Spawn (oben / Mitte / unten) | Gesamt (alle 9 Zonen) |")
print("|---|---|---|---|---|---|---|---|---|")
for lv in rules["levels"]:
    e = E[lv["enemy"]]
    c = lv["counts"]
    total = 8 * c["main"] + 2 * c["two"] + 2 * c["three"] + 2 * c["four"]
    kind = e["armor_type"][3:] + (", Luft" if e["flying"] else "")
    print("| %d | %s | %d | %d | %s | %s | %d | %d / %d / %d | %d |" % (
        lv["level"], e["name"], e["hp"], e["armor"], kind, num(e["speed"]), e["bounty"],
        c["main"], c["two"], c["four"], total))
