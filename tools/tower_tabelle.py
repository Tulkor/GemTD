#!/usr/bin/env python3
"""Erzeugt docs/tower-werte.md aus data/towers/*.json und data/balance.json.

Aufruf aus dem Projektordner: python3 tools/tower_tabelle.py [--pruefen] [--kopieren]
Nach jeder Änderung an Tower-Werten neu ausführen, damit die Tabelle aktuell bleibt.
  --pruefen   nichts schreiben, nur Exit-Code 1, wenn docs/tower-werte.md veraltet ist (für Tests und Git-Hook)
  --kopieren  zusätzlich nach /mnt/project-files/balance/tower-werte.md kopieren (falls der Ordner da ist)
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "tower-werte.md"
PROJECT_COPY = pathlib.Path("/mnt/project-files/balance/tower-werte.md")

GEM_ORDER = ["amethyst", "aquamarine", "diamond", "emerald", "opal", "ruby", "sapphire", "topaz"]
GEM_TIERS = ["Splitter", "Fehlerhaft", "Normal", "Makellos", "Perfekt", "Groß"]
DAMAGE_TYPES = {"pierce": "Durchbohrend", "magic": "Magie", "normal": "Normal", "siege": "Belagerung",
                "hero": "Held", "spells": "Zauber", "chaos": "Chaos"}
ARMOR_TYPES = {"unarmored": "Ungepanzert", "small": "Leicht", "medium": "Mittel", "large": "Schwer",
               "fortified": "Befestigt", "normal": "Normal", "hero": "Held", "divine": "Göttlich"}
TARGETS = {"air": "nur Luft", "ground": "nur Boden", "both": "Boden + Luft"}


def num(x):
    x = float(x)
    return str(int(x)) if x == int(x) else ("%.2f" % x).rstrip("0").rstrip(".").replace(".", ",")


def pct(x):
    return num(float(x) * 100) + " %"


def chance(ab):
    return "%s Chance: " % pct(ab["chance"]) if "chance" in ab and float(ab["chance"]) < 1 else ""


def describe(ab):
    t = ab.get("type", "?")
    c = chance(ab)
    if t == "splash":
        return "Fläche %s im Radius %s" % (pct(ab["factor"]), num(ab["radius"]))
    if t == "slow":
        return c + "verlangsamt %s für %s s" % (pct(ab["factor"]), num(ab["duration"]))
    if t == "poison":
        return c + "Gift %s/s für %s s" % (num(ab["dps"]), num(ab["duration"]))
    if t == "crit":
        return "%s Crit, %s× Schaden" % (pct(ab["chance"]), num(ab["multiplier"]))
    if t == "multishot":
        return "%s Ziele gleichzeitig" % num(ab["targets"])
    if t == "bounce":
        return "springt auf %s Ziele (je %s)" % (num(ab["targets"]), pct(ab.get("falloff", 0.8)))
    if t in ("pierce", "fork", "chain"):
        f = float(ab.get("factor", 1.0))
        extra = ", danach je %s" % pct(f) if f != 1.0 else ""
        if t == "pierce":
            return "durchbohrt %s Gegner%s" % (num(ab["count"]), extra)
        if t == "fork":
            return "gabelt sich %s× (±%s°)%s" % (num(ab["count"]), num(ab.get("angle", 30)), extra)
        return "springt %s× weiter (Radius %s)%s" % (num(ab["count"]), num(ab.get("radius", 2.5)), extra)
    if t == "armor_reduce":
        return c + "Rüstung −%s für %s s" % (num(ab["amount"]), num(ab["duration"]))
    if t == "stun":
        return c + "betäubt %s s" % num(ab["duration"])
    if t == "air_bonus":
        return "%s× gegen Luft" % num(ab["multiplier"])
    if t == "gold_on_hit":
        extra = " + %s pro Welle" % num(ab["gold_per_wave"]) if "gold_per_wave" in ab else ""
        return c + "%s Gold%s" % (num(ab.get("gold", 0)), extra)
    if t == "stacking_damage":
        return "+%s Schaden pro Treffer am selben Ziel (%s s)" % (num(ab["per_hit"]), num(ab["duration"]))
    if t == "nova":
        slow = ", verlangsamt %s" % pct(ab["slow"]) if "slow" in ab else ""
        return c + "Nova %s Zauberschaden im Radius %s%s" % (num(ab["damage"]), num(ab.get("radius", 2)), slow)
    if t == "wave_damage":
        return "+%s Schaden pro Welle" % num(ab["per_wave"])
    if t == "speed_aura":
        return "Aura: Tower +%s Tempo (Radius %s)" % (pct(ab["bonus"]), num(ab["radius"]))
    if t == "damage_aura":
        return "Aura: Tower +%s Schaden (Radius %s)" % (pct(ab["bonus"]), num(ab["radius"]))
    if t == "burn_aura":
        return "Brand-Aura %s/s ohne Rüstung (Radius %s)" % (num(ab["dps"]), num(ab["radius"]))
    if t == "slow_aura":
        return "Aura: Gegner −%s Tempo (Radius %s)" % (pct(ab["factor"]), num(ab["radius"]))
    if t == "armor_aura":
        return "Aura: Gegner-Rüstung −%s (Radius %s)" % (num(ab["amount"]), num(ab["radius"]))
    return t


def dps(tier):
    """Schaden pro Sekunde gegen ein Ziel ohne Rüstung: Mittelwert mal Crit-Durchschnitt durch Abklingzeit."""
    cd = float(tier.get("cooldown", 0))
    dmg = tier.get("damage", [0, 0])
    avg = (float(dmg[0]) + float(dmg[1])) / 2
    if cd <= 0 or avg <= 0:
        return "–"
    for ab in tier.get("abilities", []):
        if ab.get("type") == "crit":
            avg *= 1 + float(ab["chance"]) * (float(ab["multiplier"]) - 1)
    return num(round(avg / cd))


def dmg_text(tier):
    d = tier.get("damage", [0, 0])
    if float(tier.get("cooldown", 0)) <= 0 or float(d[1]) <= 0:
        return "–"
    return num(d[0]) if d[0] == d[1] else "%s–%s" % (num(d[0]), num(d[1]))


def abilities_text(tier, tower):
    parts = [describe(ab) for ab in tier.get("abilities", [])]
    mode = tier.get("targets", tower.get("targets", "both"))
    if mode != "both":
        parts.insert(0, TARGETS[mode])
    if "range_air" in tier:
        parts.append("Reichweite Luft %s" % num(tier["range_air"]))
    return "; ".join(parts) or "–"


def ingredient(ing, towers):
    if "any_of" in ing:
        return " oder ".join(ingredient(a, towers) for a in ing["any_of"])
    t = towers.get(ing["tower"], {})
    name = t.get("name", ing["tower"])
    if t.get("category", "gem") == "gem":
        return "%s %s" % (name, GEM_TIERS[int(ing.get("tier", 0))])
    return name


def main():
    towers = {}
    for f in sorted((ROOT / "data" / "towers").glob("*.json")):
        d = json.loads(f.read_text(encoding="utf-8"))
        towers[d["id"]] = d
    balance = json.loads((ROOT / "data" / "balance.json").read_text(encoding="utf-8"))
    lines = [
        "# Tower-Werte",
        "",
        "Automatisch erzeugt aus `data/towers/*.json` mit `python3 tools/tower_tabelle.py`. Nicht von Hand bearbeiten.",
        "",
        "Reichweite in Towerbreiten. **DPS** ist der Schaden pro Sekunde gegen ein einzelnes Ziel ohne Rüstung,"
        " mit Crit-Durchschnitt. Mehrfachschuss, Fläche, Gift und Auren sind darin nicht enthalten.",
        "",
        "## Grund-Gems",
        "",
        "| Gem | Stufe | Schadensart | Schaden | Abklingzeit | DPS | Reichweite | Besonderheiten |",
        "|---|---|---|---:|---:|---:|---:|---|",
    ]
    for gid in GEM_ORDER:
        t = towers[gid]
        for i, tier in enumerate(t["tiers"]):
            lines.append("| %s | %s | %s | %s | %s | %s | %s | %s |" % (
                t["name"] if i == 0 else "", GEM_TIERS[i],
                DAMAGE_TYPES.get(tier.get("damage_type", t.get("damage_type", "")), "–") if i == 0 else "",
                dmg_text(tier), num(tier.get("cooldown", 0)), dps(tier), num(tier.get("range", 0)),
                abilities_text(tier, t)))
    for title, kind in (("Kombi-Tower", "tower"), ("Fallen (Platten)", "trap")):
        lines += ["", "## " + title, "",
                  "| Tower | Stufe | Schadensart | Schaden | Abklingzeit | DPS | Reichweite | Besonderheiten | Rezept / Upgrade |",
                  "|---|---|---|---:|---:|---:|---:|---|---|"]
        ids = [i for i, t in towers.items() if t.get("category") == "special" and t.get("kind", "tower") == kind]
        for tid in sorted(ids, key=lambda i: towers[i]["name"]):
            t = towers[tid]
            ups = t.get("upgrades", [])
            for i, tier in enumerate(t["tiers"]):
                if i == 0:
                    rec = " + ".join(ingredient(r, towers) for r in t.get("recipe", [])) or "aus Überlauf"
                    if t.get("recipe_same_round"):
                        rec += " (gleiche Runde)"
                else:
                    up = ups[i - 1] if i - 1 < len(ups) else {}
                    rec = "Upgrade %s Gold" % num(up.get("cost", 0))
                    if up.get("recipe"):
                        rec += " + " + " + ".join(ingredient(r, towers) for r in up["recipe"])
                lines.append("| %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (
                    t["name"] if i == 0 else "", tier.get("name", str(i + 1)) if len(t["tiers"]) > 1 else "",
                    DAMAGE_TYPES.get(tier.get("damage_type", t.get("damage_type", "")), "–") if i == 0 else "",
                    dmg_text(tier), num(tier.get("cooldown", 0)) if dmg_text(tier) != "–" else "–", dps(tier),
                    num(tier.get("range", 0)) if float(tier.get("range", 0)) > 0 else "–",
                    abilities_text(tier, t), rec))
    table = balance.get("damage_table", {})
    armors = list(ARMOR_TYPES)
    lines += ["", "## Schadensart gegen Rüstungsart", "",
              "Faktor auf den Schaden, aus `data/balance.json`. Dazu kommt die Rüstung selbst:"
              " jeder Punkt senkt den Schaden um etwa 6 %, abnehmend (Rüstung 12 ≈ −42 %, Rüstung 35 ≈ −68 %).",
              "",
              "| Schadensart | " + " | ".join(ARMOR_TYPES[a] for a in armors) + " |",
              "|---|" + "---:|" * len(armors)]
    for dt, name in DAMAGE_TYPES.items():
        row = table.get(dt, {})
        lines.append("| %s | %s |" % (name, " | ".join(num(row.get(a, 1)) for a in armors)))
    text = "\n".join(lines) + "\n"
    if "--pruefen" in sys.argv:
        current = OUT.read_text(encoding="utf-8") if OUT.exists() else ""
        if current != text:
            print("docs/tower-werte.md ist veraltet: python3 tools/tower_tabelle.py --kopieren")
            sys.exit(1)
        print("Tower-Tabelle aktuell")
        return
    OUT.write_text(text, encoding="utf-8")
    print("geschrieben:", OUT.relative_to(ROOT))
    if "--kopieren" in sys.argv and PROJECT_COPY.parent.is_dir():
        PROJECT_COPY.write_text(text, encoding="utf-8")
        print("kopiert:", PROJECT_COPY)


if __name__ == "__main__":
    main()
