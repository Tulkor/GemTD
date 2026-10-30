#!/usr/bin/env python3
"""Erzeugt die Shopping-Maul-Daten (data/maul/) aus der ausgelesenen Kartendatei 5.44f.

Aufruf (Kartendatei vorher mit auslesen.sh entpacken):
    python3 -I tools/wc3/maul_daten.py <entpackt> <recherche-stand> <repo>

  <entpackt>         Ordner mit war3map.wpm und scripts__war3map.j (mpq.py)
  <recherche-stand>  /mnt/project-files/konzepte/recherche-stand (maul544f/, maulwork/)
  <repo>             Wurzel des Godot-Projekts

Schreibt:
  data/maul/map.json    Karte 236 × 236 Felder (1 Feld = 64 WC3-Einheiten), Zonen der 11 Spieler,
                        Spawns, Routen mit Teleports, Hardblocker
  data/maul/shops.json  20 Filialen mit ihren Towern (Werte aus den Objektdaten)
  data/maul/waves.json  50 Level: Gegner, Art, HP-Budget, Rüstung, Tempo, Kopfgeld, Speziallevel
Die Regeln (Schwierigkeit, Einkommen, …) stehen von Hand in data/maul/rules.json.
"""
import json
import math
import os
import re
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import maul_namen  # noqa: E402

CELL = 64          # WC3-Einheiten pro Feld
TOWER = 128        # WC3-Einheiten pro Towerbreite (Einheit im Spiel)
X0, X1 = -7552, 7552
Y0, Y1 = -7424, 7680
W = (X1 - X0) // CELL
H = (Y1 - Y0) // CELL

# Baugebiete P1 … P11 (Rects im Skript)
ZONES = ["IO", "bO", "BO", "cO", "CO", "dO", "DO", "fO", "FO", "AO", "NO"]
# Spawns: Rect-Namen und Route
SPAWNS = [
    ("gO", "oben_links"), ("HO", "oben_links"),
    ("jO", "oben_rechts"), ("JO", "oben_rechts"),
    ("hO", "links"), ("KO", "links"),
    ("GO", "rechts"), ("kO", "rechts"),
    ("mO", "unten_links"), ("MO", "unten_links"),
    ("PO", "unten_rechts"), ("qO", "unten_rechts"),
]
CENTER_L = ["yO", "eO", "VO", "ZX"]
CENTER_R = ["YO", "eO", "VO", "ZX"]
# Route = Abschnitte (Wegpunkt-Ketten); zwischen zwei Abschnitten wird teleportiert.
# "choices": nach dem ersten Abschnitt geht es abwechselnd (oder ins bebaute Gebiet) weiter.
ROUTES = {
    "oben_links": {"legs": [["oO", "sO", "nR"], CENTER_L]},
    "oben_rechts": {"legs": [["aO", "uO", "aR"], CENTER_R]},
    "unten_links": {"legs": [["rO", "tO", "VR"], CENTER_L]},
    "unten_rechts": {"legs": [["nO", "wO", "iR"], CENTER_R]},
    "links": {"legs": [["xO"]], "choices": [
        {"zone": 1, "legs": [["eR", "oO", "sO", "nR"], CENTER_L]},
        {"zone": 3, "legs": [["xR", "rO", "tO", "VR"], CENTER_L]}]},
    "rechts": {"legs": [["iO"]], "choices": [
        {"zone": 4, "legs": [["vR", "aO", "uO", "aR"], CENTER_R]},
        {"zone": 2, "legs": [["ZO", "nO", "wO", "iR"], CENTER_R]}]},
}

# Speziallevel (Skript Ip, nicht auf "Sehr Einfach")
SPECIALS = {
    "invisible": [17, 18, 25, 30, 36, 42, 48],
    "fast": [8, 14, 21, 33, 39, 42, 49],
    "spell_resist": [9, 19, 29, 35, 40, 46, 50],
    "frost": [3, 12, 24, 31, 36, 44, 48],
    "ghost": [11, 21, 28, 31, 39, 44, 46],
}
ARMOR_BY_BASE = {"orai": "medium", "ehip": "small", "Obla": "hero"}
# Angriffsart, wenn in den Objektdaten nichts steht (Standard des WC3-Grundturms)
ATTACK_BY_BASE = {"owtw": "pierce", "hwtw": "normal", "hatw": "magic", "hgtw": "pierce", "uaco": "normal"}
SHOP_COLORS = {
    "Media Markt": "#ff4f4f", "H&M": "#ff4fd8", "Obi Baumarkt": "#ff9a3c", "Mc Donalds": "#ffd166",
    "Aldi": "#4fa3ff", "Tante Emma Laden": "#8be36b", "Porsche Autohaus": "#c0c8d8", "Deutsche Bank": "#3c6cff",
    "Aral Tankstelle": "#2ef2e0", "Beate Uhse Sexshop": "#ff6fa8", "CinemaxX": "#b38cff", "Post": "#ffe14f",
    "Copyshop": "#9fa8b8", "TUI Reisebüro": "#5fd0ff", "AOK": "#5fe08a", "IKEA": "#ffd84f",
    "Gärtnerei": "#6bdc5a", "Fitness-Studio": "#ff7a3c", "Bestattungsinstitut": "#8a8aa0", "Waffenladen": "#d05a5a",
}
SHOP_IDS = {
    "Media Markt": "media_markt", "H&M": "hm", "Obi Baumarkt": "obi", "Mc Donalds": "mcdonalds", "Aldi": "aldi",
    "Tante Emma Laden": "tante_emma", "Porsche Autohaus": "porsche", "Deutsche Bank": "bank",
    "Aral Tankstelle": "aral", "Beate Uhse Sexshop": "sexshop", "CinemaxX": "cinemaxx", "Post": "post",
    "Copyshop": "copyshop", "TUI Reisebüro": "tui", "AOK": "aok", "IKEA": "ikea", "Gärtnerei": "gaertnerei",
    "Fitness-Studio": "fitness", "Bestattungsinstitut": "bestatter", "Waffenladen": "waffenladen",
}


def cell(x, y):
    return [int((x - X0) // CELL), int((Y1 - y) // CELL)]


def rect_center(r):
    return cell((r[0] + r[2]) / 2, (r[1] + r[3]) / 2)


def rect_cells(r):
    a = cell(r[0], r[3])
    b = cell(r[2], r[1])
    return [a[0], a[1], b[0] - a[0], b[1] - a[1]]


def build_map(src, out):
    d = open(os.path.join(src, "war3map.wpm"), "rb").read()
    _, w, h = struct.unpack_from("<iii", d, 4)
    g = d[16:16 + w * h]
    script = open(os.path.join(src, "scripts__war3map.j"), encoding="latin-1").read()
    rects = {m.group(1): tuple(float(v) for v in m.groups()[1:])
             for m in re.finditer(r"set (\w+)=Rect\(([-\d.]+),([-\d.]+),([-\d.]+),([-\d.]+)\)", script)}

    def flags(x, y):
        cx = int((x + 8192) / 32)
        cy = int((y + 8192) / 32)
        return g[cy * w + cx] if 0 <= cx < w and 0 <= cy < h else 2

    zones = [rect_cells(rects[z]) for z in ZONES]

    def in_zone(c):
        for z in zones:
            if z[0] <= c[0] < z[0] + z[2] and z[1] <= c[1] < z[1] + z[3]:
                return True
        return False

    rows = []
    for cy in range(H):
        row = ""
        for cx in range(W):
            x = X0 + cx * CELL
            y = Y1 - (cy + 1) * CELL
            fs = [flags(x + 16 + dx * 32, y + 16 + dy * 32) for dx in (0, 1) for dy in (0, 1)]
            if any(f & 2 for f in fs):
                row += "#"
            elif not any(f & 8 for f in fs) and in_zone([cx, cy]):
                row += "."
            else:
                row += "_"
        rows.append(row)
    # Hardblocker (o02U): feste Wegsperren, je eine Towerbreite
    blockers = []
    for m in re.finditer(r"CreateUnit\(\w+,'o02U',([-\d.]+),([-\d.]+),", script):
        x, y = float(m.group(1)), float(m.group(2))
        a = cell(x - 64, y + 64)
        blockers.append(a)
        for dy in (0, 1):
            r = list(rows[a[1] + dy])
            for dx in (0, 1):
                r[a[0] + dx] = "#"
            rows[a[1] + dy] = "".join(r)

    def wp(name):
        return rect_center(rects[name])

    routes = {}
    for name, r in ROUTES.items():
        routes[name] = {"legs": [[wp(n) for n in leg] for leg in r["legs"]]}
        if "choices" in r:
            routes[name]["choices"] = [{"zone": c["zone"], "legs": [[wp(n) for n in leg] for leg in c["legs"]]}
                                       for c in r["choices"]]
    spawns = [{"cell": wp(s), "route": r} for s, r in SPAWNS]
    starts = [[0, -1536], [-3136, 512], [3136, -2560], [-3136, -2560], [3136, 448], [-4224, -5696],
              [4224, 3648], [-4224, 3648], [4224, -5696], [-5824, -1024], [5824, -1024]]
    leak = rect_cells(rects["vO"])
    m = {
        "format": 2,
        "id": "shopping_maul",
        "name": "Shopping Maul",
        "width": W,
        "height": H,
        "tiles": rows,
        "spawn": spawns[0]["cell"],
        "goal": wp("ZX"),
        "checkpoints": [],
        "zones": [{"rect": z, "player": i} for i, z in enumerate(zones)],
        "marker_radius": 2,
        "lives": 150,
        "start_gold": 0,
        "maul": {
            "source": "Shopping Maul 5.44f (war3map.wpm, Rects und CreateUnit aus dem Skript)",
            "cell_units": CELL,
            "spawns": spawns,
            "routes": routes,
            "leak": leak,
            "mall": wp("zO"),
            "starts": [cell(x, y) for x, y in starts],
            "blockers": blockers,
        },
    }
    with open(out, "w", encoding="utf-8") as f:
        json.dump(m, f, ensure_ascii=False, indent="\t")
    walk = sum(r.count(".") + r.count("_") for r in rows)
    build = sum(r.count(".") for r in rows)
    print("Karte %d×%d: %d begehbar, %d bebaubar, %d Hardblocker" % (W, H, walk, build, len(blockers)))
    for i, z in enumerate(zones):
        n = sum(1 for y in range(z[1], z[1] + z[3]) for x in range(z[0], z[0] + z[2]) if rows[y][x] == ".")
        print("  P%d %s: %d bebaubare Felder" % (i + 1, z, n))


# --- Tower ---------------------------------------------------------------------

def ability_json(aid, A, tower):
    """Fähigkeit aus den Objektdaten in unser Format (abilities.gd). None = (noch) nicht umgesetzt."""
    a = A.get(aid)
    if a is None:
        return None
    base = a["base"]
    m = a["mods"]
    f = lambda k, d=0.0: float(m.get(k + "@1", d))
    if base == "ACbh" and m.get("anam") == "Life":
        # im Skript: Kill durch Fries Carver/Hellboy/Hilfsdrohne, Zufallszahl 1..10 == 7
        return [{"type": "life", "chance": 0.1}]
    if base == "ACwb":
        # Flash (Digitalkamera), Neid (Karrera GT): betäubt alle Gegner im Radius, Helden kürzer
        return [{"type": "stun_spell", "name": m.get("anam", aid), "radius": round(f("aare", 500) / TOWER, 2),
                 "duration": f("adur"), "boss_duration": f("ahdu"), "cooldown": f("acdn")}]
    if base == "Amls":
        # Flirten: hält einen Gegner fest, Helden kürzer
        return [{"type": "flirt_spell", "duration": f("adur", 20.0), "boss_duration": f("ahdu", 5.0),
                 "cooldown": f("acdn", 120.0)}]
    if base == "ACbh":
        chance = f("Hbh1") / 100.0
        mult = f("Hbh2")
        out = []
        if mult > 1.0:
            out.append({"type": "crit", "chance": chance, "multiplier": mult})
        if f("adur") > 0.0:
            out.append({"type": "stun", "chance": chance, "duration": f("adur")})
        return out or None
    if base == "Afra":
        return [{"type": "slow", "factor": 0.3, "duration": max(f("adur", 1.0), 1.0)}]
    if base == "Aasl":
        return [{"type": "slow_aura", "radius": round(f("aare", 900) / TOWER, 2), "factor": round(-f("Slo1"), 2)}]
    if base == "SCae":
        return [{"type": "slow_aura", "radius": round(f("aare", 900) / TOWER, 2), "factor": round(-f("Oae1"), 2)}]
    if base == "AIcf":
        # Dauerschaden um den Tower; die Tooltips des Autors nennen das Vierfache des Datenwerts als dps
        return [{"type": "burn_aura", "radius": round(f("aare", 500) / TOWER, 2), "dps": 4.0 * f("Icfd"),
                 "targets": "ground" if "air" not in m.get("atar@1", "air") else "both"}]
    if base == "ANpi":
        return [{"type": "burn_aura", "radius": round(f("aare", 100) / TOWER, 2), "dps": f("Eim1")}]
    if base == "Aspo":
        return [{"type": "poison", "dps": f("Spo1"), "duration": f("adur", 3.0) or 3.0},
                {"type": "slow", "factor": f("Spo2"), "duration": f("adur", 3.0) or 3.0}]
    if base == "AHtc":
        return [{"type": "nova_spell", "damage": f("Htc1"), "radius": round(f("aare", 300) / TOWER, 2),
                 "cooldown": f("acdn", 2.0), "slow": f("Htc3"), "slow_duration": 3.0}]
    if base == "AOcl":
        return [{"type": "chain_spell", "damage": f("Ocl1"), "targets": int(f("Ocl2", 3)),
                 "falloff": round(1.0 - f("Ocl3", 0.15), 2), "cooldown": f("acdn", 3.0),
                 "range": round(f("aran", 800) / TOWER, 2)}]
    if base == "ACsh":
        return [{"type": "wave_spell", "damage": f("Osh1"), "cooldown": f("acdn", 3.0),
                 "range": round(f("aran", 800) / TOWER, 2), "width": round(f("aare", 200) / TOWER, 2)}]
    if base in ("Amgl",):
        return [{"type": "multishot", "targets": 3}]
    if base == "Aroc":
        return [{"type": "multishot", "targets": 10}]
    if base in ("Agyv",):
        return [{"type": "detect", "radius": round(f("aran", 900) / TOWER, 2)}]
    return None


def num(s):
    if s is None:
        return None
    s = str(s).replace(".", "").replace(",", ".")
    try:
        return float(s)
    except ValueError:
        return None


def tooltip_cooldown(t):
    m = re.search(r"\(([\d,]+)s", t.get("tooltip_dps") or "")
    return num(m.group(1)) if m else None


# XPert (n000): XP- und Ultimate-Tower, die jede Filiale zusätzlich bauen kann
XPERT = {"id_de": "n000", "id_en": "n000", "name_de": "XPert", "name_en": "XPert", "kind": "XPert",
         "bonus_ability": "", "tooltip_de": "XP-Tower (je Spieler einer) und Ultimate-Tower (einer, ab Level 21).",
         "rules": "XP-Tower brauchen das Token n00B, Ultimate-Tower n00H: je einer gleichzeitig.",
         "manager_builds": ["h00S", "h01L", "h01M", "h01U", "h022", "h02P", "h02U", "h03D", "h03V", "o02M", "o01J"]}


# Fähigkeiten, die pro.json und die Spiellogik von Hand abbilden (nicht als "todo" melden)
PRO_HANDLED = {
    "AEar": "aok.auras (Medicin: Schadensaura)",
    "Afak": "garden.plants (Rache des Gärtners)",
    "Arpm": "garden.irrigation (Wässern)",
    "ANcl": "undertaker.summons (Friedhof)",
    "Arai": "undertaker.darkness (Fleisch)",
    "Ambt": "undertaker.cults (Bond Of Death)",
    "AHab": "drones (Recharge)",
}


def build_towers(rs, out):
    overrides = json.load(open(os.path.join(os.path.dirname(out), "pro.json"), encoding="utf-8"))["overrides"]
    d = json.load(open(os.path.join(rs, "maulwork", "maul_towers.json"), encoding="utf-8"))
    o = json.load(open(os.path.join(rs, "maul544f", "objects.json"), encoding="utf-8"))
    A = {x["id"]: x for x in o["w3a"]}
    U = {x["id"]: x for x in o["w3u"]}
    towers = {t["id"]: t for t in d["towers"]}
    shops = []
    xpert = None
    for s in d["shops"] + [XPERT]:
        ids = []
        todo = []
        queue = list(s["manager_builds"])
        while queue:
            i = queue.pop(0)
            if i in ids or i not in towers:
                continue
            ids.append(i)
            queue.extend(towers[i]["upgrades_to"])
        list_ = []
        for i in ids:
            t = towers[i]
            rng = t["range"] or num(t.get("tooltip_range")) or 800
            cd = t["cooldown"] or tooltip_cooldown(t) or 1.0
            lo = (t["dmg_base"] or 0) + (t["dmg_dice"] or 1)
            hi = (t["dmg_base"] or 0) + (t["dmg_dice"] or 1) * (t["dmg_sides"] or 1)
            special = (t.get("tooltip_special") or "")
            abilities = []
            for aid in t["abilities"]:
                ab = ability_json(aid, A, t)
                if ab is None:
                    a = A.get(aid)
                    if a and a["base"] not in PRO_HANDLED and t["id"] not in overrides and a["base"] not in ("AInv", "Aihn", "Ahar", "Aall", "Aloc", "Avul", "Apit", "Apiv",
                                                   "Argd", "Aeth", "Aslo", "Aivs"):
                        todo.append("%s: %s (%s)" % (t["name"], a["mods"].get("anam", aid), a["base"]))
                    continue
                abilities.extend(ab)
            only_aura = "all units in range" in special.lower() and "dual" not in special.lower()
            targets = t["targets"] or ""
            tgt = "both"
            if "air" in targets and "ground" not in targets:
                tgt = "air"
            elif "ground" in targets and "air" not in targets:
                tgt = "ground"
            if not t["targets"] or t["dmg_base"] is None:
                lo = hi = 0
            um = U.get(t["id"], {}).get("mods", {})
            # Späherturm (hwtw) ohne aktivierten Angriff: Schaden nur über Zauber
            if only_aura or (t["base"] == "hwtw" and um.get("uaen") != 1):
                lo = hi = 0
            # Flächenschaden der Waffe: voller Schaden im inneren Radius, außen weniger (nur mit echtem Angriff)
            if um.get("ua1w") in ("msplash", "artillery", "aline") and um.get("ua1q") and hi:
                abilities.insert(0, {"type": "splash", "radius": round(float(um["ua1q"]) / TOWER, 2), "factor": 0.5})
            hk = re.search(r"\((\w)\)", t.get("hotkey_name") or "")
            extra = {"requires": t["requires"]} if t.get("requires") else {}
            list_.append({
                "id": t["id"],
                "name": t["name"],
                "cost": t["gold"] or 0,
                "value": t["point_value"] or t["gold"] or 0,
                "upgrade_from": t["upgrade_from"],
                "upgrades_to": t["upgrades_to"],
                "damage": [lo, max(lo, hi)],
                "cooldown": cd,
                "range": round(rng / TOWER, 2),
                "targets": tgt,
                "damage_type": t["attack_type"] or ATTACK_BY_BASE.get(t["base"], "normal"),
                "abilities": abilities,
                "hotkey": hk.group(1) if hk else "",
                "tooltip": t.get("tooltip") or "",
                "build_time": t.get("build_time") or 0,
                **extra,
            })
        # Wert eines Upgrades = Wert des Ausgangsturms + Aufpreis (zählt beim Verkaufen)
        by_id = {x["id"]: x for x in list_}
        for x in list_:
            chain = x
            total = x["cost"]
            while chain["upgrade_from"] in by_id:
                chain = by_id[chain["upgrade_from"]]
                total += chain["cost"]
            x["value"] = total
        list_.sort(key=lambda x: (x["upgrade_from"] is not None, x["cost"]))
        entry = {
            "id": SHOP_IDS.get(s["name_de"], s["id_de"]),
            "name": s["name_de"],
            "name_en": s["name_en"],
            "kind": "standard" if s["kind"] == "Standard" else "pro",
            "bonus": "rebate" if s["bonus_ability"] == "Rabatt" else "damage",
            "color": SHOP_COLORS.get(s["name_de"], "#ffffff"),
            "text": s.get("tooltip_de") or "",
            "rules": s.get("rules") or "",
            "towers": list_,
            "todo": todo,
        }
        if s is XPERT:
            entry["id"] = "xpert"
            entry["kind"] = "xpert"
            entry["bonus"] = ""
            entry["color"] = "#ffe14f"
            xpert = entry
        else:
            shops.append(entry)
    # echte Marken nur leicht abgewandelt zeigen (maul_namen.py)
    shops, xpert = maul_namen.anwenden(shops), maul_namen.anwenden(xpert)
    with open(out, "w", encoding="utf-8") as f:
        json.dump({"source": "Shopping Maul 5.44f, maulwork/maul_towers.json + objects.json", "shops": shops,
                   "xpert": xpert}, f, ensure_ascii=False, indent="\t")
    print("Filialen: %d, Tower: %d" % (len(shops), sum(len(s["towers"]) for s in shops)))
    for s in shops:
        if s["todo"]:
            print("  %s offen: %s" % (s["name"], "; ".join(s["todo"])))


def build_waves(rs, out):
    rules = open(os.path.join(rs, "maulwork", "maul_rules.md"), encoding="utf-8").read()
    o = json.load(open(os.path.join(rs, "maul544f", "objects.json"), encoding="utf-8"))
    U = {x["id"]: x for x in o["w3u"]}
    levels = []
    for m in re.finditer(r"^\| (\d+)(?: \(Bonus\))? \| ([^|(]+)\((\w+)\) \| (\w+) \| [^|]* \| (\d+) \|", rules, re.M):
        lv = int(m.group(1))
        uid = m.group(3)
        u = U.get(uid, {})
        mods = u.get("mods", {})
        kind = {"Boden": "ground", "Luft": "air", "Boss": "boss"}[m.group(4)]
        levels.append({
            "level": lv,
            "unit": uid,
            "name": m.group(2).strip(),
            "kind": kind,
            "jv": int(m.group(5)),
            "armor": mods.get("udef", 0),
            "armor_type": mods.get("udty") or ARMOR_BY_BASE.get(u.get("base"), "medium"),
            "speed": mods.get("umvs", 350),
            "bounty": mods.get("ubba", 0),
            "specials": [k for k, v in SPECIALS.items() if lv in v],
        })
    assert len(levels) == 50, len(levels)
    with open(out, "w", encoding="utf-8") as f:
        json.dump({"source": "Shopping Maul 5.44f: Jv[1..50], Einheiten o[1..20], Speziallevel Ip",
                   "levels": levels}, f, ensure_ascii=False, indent="\t")
    print("Level: %d" % len(levels))


if __name__ == "__main__":
    src, rs, repo = sys.argv[1:4]
    os.makedirs(os.path.join(repo, "data", "maul"), exist_ok=True)
    build_map(src, os.path.join(repo, "data", "maul", "map.json"))
    build_towers(rs, os.path.join(repo, "data", "maul", "shops.json"))
    build_waves(rs, os.path.join(repo, "data", "maul", "waves.json"))
