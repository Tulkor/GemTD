"""Erzeugt die YouTD-Daten für das Spiel aus dem Quelltext von YouTD 2 (MIT-Lizenz, siehe data/youtd/QUELLEN.md).

    python3 -I tools/youtd/youtd_daten.py [youtd2-ordner oder youtd2-main.zip]

Quelle (Standard): /mnt/project-files/youtd/youtd2-main.zip (github.com/Praytic/youtd2, Stand 4. Juli 2026).
Gelesen werden nur die CSV-Tabellen unter data/, keine Assets (die sind CC-BY-NC und kommen nicht ins Repo).
Schreibt nach data/youtd/:
  towers.json    690 Tower: Werte in WC3-Einheiten wie im Original (Umrechnung macht das Spiel, 128 = 1 Towerbreite)
  items.json     315 Items (normal, Öl, Verbrauch) mit ihren Werte-Modifikatoren
  specials.json  41 Wellen-Eigenschaften mit HP-Faktor, Mindestwelle, Häufigkeit und Gruppen
  xp.json        Erfahrungstabellen für Tower (Level 0–30) und Spieler (Level 0–300)
  builders.json  Baumeister mit Stufe und nötigem Spielerlevel
  abilities.json Fähigkeiten (Name, Reichweite), Auren und Autocasts der Tower
Regeln und Formeln (Wellen, Würfeln, Weisheits-Boni) stehen von Hand in data/youtd/rules.json.
"""
import csv
import io
import json
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("/mnt/project-files/youtd/youtd2-main.zip")
OUT = ROOT / "data" / "youtd"


def reader():
    """Liefert eine Funktion name -> Zeilen (dicts) für data/<name>.csv aus Ordner oder Zip."""
    if SRC.suffix == ".zip":
        z = zipfile.ZipFile(SRC)
        names = {n.split("/", 1)[1]: n for n in z.namelist() if "/" in n}

        def read(name):
            text = z.read(names["data/" + name]).decode("utf-8")
            return list(csv.DictReader(io.StringIO(text)))
        return read

    def read(name):
        with open(SRC / "data" / name, encoding="utf-8") as f:
            return list(csv.DictReader(f))
    return read


read = reader()


def num(s, default=0.0):
    try:
        return float(s)
    except (TypeError, ValueError):
        return default


def tidy(v):
    """Ganze Zahlen ohne .0, damit die JSON-Dateien lesbar bleiben."""
    return int(v) if float(v).is_integer() else round(v, 6)


def mods(text):
    """"MOD_X,0.1,0.002|MOD_Y,1,0" -> [["MOD_X", 0.1, 0.002], ...] (Wert, Zuwachs je Tower-Level)."""
    out = []
    for part in (text or "").split("|"):
        bits = part.split(",")
        if len(bits) >= 2 and bits[0]:
            out.append([bits[0], tidy(num(bits[1])), tidy(num(bits[2]) if len(bits) > 2 else 0.0)])
    return out


def script_name(path):
    name = Path(path or "").stem
    return "" if name.startswith("empty_") else name


def towers():
    out = {}
    for r in read("tower_properties.csv"):
        targets = "both"
        tt = r["attack_target_type"]
        if "SIZE_AIR" in tt and "SIZE_MASS" not in tt:
            targets = "air"
        elif "SIZE_MASS" in tt and "SIZE_AIR" not in tt:
            targets = "ground"
        splash = []
        bits = [num(b) for b in r["splash attack"].split(",") if b != ""]
        for i in range(0, len(bits) - 1, 2):
            splash.append([tidy(bits[i]), tidy(bits[i + 1])])
        bounce = [tidy(num(b)) for b in r["bounce attack"].split(",") if b != ""]
        t = {
            "name": r["name english"],
            "family": int(r["family id"]),
            "tier": int(r["tier"]),
            "rarity": r["rarity"],
            "element": r["element"],
            "attack": r["attack enabled"].upper() == "TRUE",
            "attack_type": r["attack type"],
            "range": tidy(num(r["attack range"])),
            "cooldown": tidy(num(r["attack cd"])),
            "damage": [tidy(num(r["dmg min"])), tidy(num(r["dmg max"]))],
            "mana": tidy(num(r["mana"])),
            "mana_regen": tidy(num(r["mana regen"])),
            "cost": int(num(r["cost"])),
            "missile_speed": tidy(num(r["missile speed"])),
            "arc": tidy(num(r["missile arc"])),
            "lightning": r["missile uses lightning visual"].upper() == "TRUE",
            "targets": targets,
            "author": r["author"],
        }
        if tt and tt != "CREEPS":
            t["target_type"] = tt
        if r["multishot"]:
            t["multishot"] = int(num(r["multishot"]))
        if splash:
            t["splash"] = splash
        if bounce:
            t["bounce"] = bounce
        m = mods(r["specials"])
        if m:
            t["mods"] = m
        s = script_name(r["script path"])
        if s:
            t["script"] = s
        for col, key in (("ability list", "abilities"), ("aura list", "auras"), ("autocast list", "autocasts")):
            ids = [int(x) for x in r[col].split(",") if x.strip()]
            if ids:
                t[key] = ids
        out[r["id"]] = t
    return out


def abilities():
    """Fähigkeiten der Tower (Namen, Reichweiten), Auren und Autocasts aus YouTD 2. Texte fehlen im Original-Repo."""
    out = {"abilities": {}, "auras": {}, "autocasts": {}}
    for r in read("ability_properties.csv"):
        a = {"name": r["name_english"], "range": tidy(num(r["range"]))}
        if r["target_type"]:
            a["target_type"] = r["target_type"]
        out["abilities"][r["id"]] = a
    for r in read("aura_properties.csv"):
        out["auras"][r["id"]] = {
            "name": r["name_english"], "buff": r["aura_bt"], "target_self": r["target_self"].upper() == "TRUE",
            "range": tidy(num(r["range"])), "target_type": r["target_type"], "hidden": r["is_hidden"].upper() == "TRUE",
            "level": int(num(r["level"])), "level_add": int(num(r["level_add"])),
        }
    for r in read("autocast_properties.csv"):
        a = {
            "name": r["name_english"], "handler": r["handler_function"], "type": r["autocast_type"],
            "cooldown": tidy(num(r["cooldown"])), "mana": int(num(r["mana_cost"])), "cast_range": tidy(num(r["cast_range"])),
            "auto_range": tidy(num(r["auto_range"])), "target_self": r["target_self"].upper() == "TRUE",
        }
        for col, key in (("buff_type", "buff"), ("buff_target_type", "buff_target_type"), ("caster_art", "caster_art"), ("target_art", "target_art")):
            if r[col]:
                a[key] = r[col]
        out["autocasts"][r["id"]] = a
    return out


def items():
    out = {}
    for r in read("item_properties.csv"):
        it = {
            "name": r["name english"],
            "type": r["type"],
            "rarity": r["rarity"],
            "cost": int(num(r["cost"])),
            "level": int(num(r["required wave level"])),
            "author": r["author"],
        }
        m = mods(r["specials"])
        if m:
            it["mods"] = m
        s = script_name(r["script path"])
        if s:
            it["script"] = s
        out[r["id"]] = it
    return out


def specials():
    out = {}
    for r in read("wave_special_properties.csv"):
        out[r["id"]] = {
            "name": r["name english"],
            "hp": tidy(num(r["hp modifier"])),
            "level": int(num(r["required wave level"])),
            "frequency": int(num(r["frequency"])),
            "sizes": [s.strip() for s in r["creep sizes"].split(",") if s.strip()],
            "champions_bosses_only": r["applies only to champions or bosses"].upper() == "TRUE",
            "groups": [g.strip() for g in r["group list"].split(",") if g.strip()],
            "mana": r["uses mana"].upper() == "TRUE",
            "color": r["color"],
            "enabled": r["enabled"].upper() == "TRUE",
            "script": special_script(r["script path"]),
        }
    return out


def special_script(path):
    """Dateiname des Eigenschafts-Skripts unter scripts/youtd/specials/ (faehigkeiten.py), ohne + und -."""
    return path.rsplit("/", 1)[-1].removesuffix(".gd").replace("+", "_plus").replace("-", "_")


def xp():
    tower = {int(r["level"]): int(r["exp"]) for r in read("exp_for_level.csv")}
    player = {int(r["level"]): int(r["exp"]) for r in read("player_exp_for_level.csv")}
    return {"tower": [tower[i] for i in sorted(tower)], "player": [player[i] for i in sorted(player)]}


def builders():
    out = []
    for r in read("builder_properties.csv"):
        if r["id"] == "0":
            continue
        out.append({"id": r["short name"], "name": r["name english"], "tier": r["tier"], "level": int(num(r["req level"]))})
    return out


def write(name, data):
    """Eine Zeile je Eintrag: lesbare Diffs, wenn sich ein Wert ändert."""
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    dump = lambda v: json.dumps(v, ensure_ascii=False, separators=(",", ":"))
    if isinstance(data, dict) and all(isinstance(v, dict) and all(isinstance(x, dict) for x in v.values()) for v in data.values()):
        # zwei Ebenen (abilities.json): eine Zeile je innerem Eintrag
        parts = []
        for k, v in data.items():
            inner = ",\n".join("\t\t%s: %s" % (dump(a), dump(b)) for a, b in v.items())
            parts.append("\t%s: {\n%s\n\t}" % (dump(k), inner))
        text = "{\n" + ",\n".join(parts) + "\n}\n"
    elif isinstance(data, dict):
        body = ",\n".join("\t%s: %s" % (dump(k), dump(v)) for k, v in data.items())
        text = "{\n" + body + "\n}\n"
    else:
        text = "[\n" + ",\n".join("\t" + dump(v) for v in data) + "\n]\n"
    path.write_text(text, encoding="utf-8")
    print(f"{path.relative_to(ROOT)}: {len(data)} Einträge")


write("towers.json", towers())
write("items.json", items())
write("specials.json", specials())
write("xp.json", xp())
write("builders.json", builders())
write("abilities.json", abilities())
