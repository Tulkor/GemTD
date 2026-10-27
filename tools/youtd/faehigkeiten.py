"""Portiert die Fähigkeiten aus YouTD 2 (MIT-Lizenz, siehe data/youtd/QUELLEN.md) ins Spiel:

    python3 -I tools/youtd/faehigkeiten.py [youtd2-ordner oder youtd2-main.zip]

- src/towers/tower_behaviors/*.gd   -> scripts/youtd/towers/<name>.gd    (Tower-Skripte, Feld "script" in towers.json)
- src/creeps/special_buffs/*.gd     -> scripts/youtd/specials/<name>.gd  (Wellen-Eigenschaften, "script" in specials.json)

Was gemacht wird: Klassen bekommen das Präfix Yt (umbenennen.py), Texte der Übersetzungstabelle (tr("AB12"), nicht im
Quelltext von YouTD 2) kommen aus data/youtd/texte.json über YtUtils.text(), dazu kleine Änderungen je Datei in
PATCHES (Stellen, die Szenen, Pfade oder die Gegnerliste von YouTD 2 benutzen). Laufzeit: scripts/youtd/rt/.
Quelle (Standard): /mnt/project-files/youtd/youtd2-main.zip.
"""
import re
import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from umbenennen import rename  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SRC = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("/mnt/project-files/youtd/youtd2-main.zip")
HEADER = "## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.\n"

# Gegner, die Eigenschaften erzeugen (Brut, Nekromant, Trächtig): statt Szene, Weg und set_properties aus YouTD 2
# erzeugt youtd_game.gd sie (spawn_yt_creep) gleich auf dem Feld; die Stelle setzt das Skript danach wie gewohnt.
SPAWN_RULES = [
    (r"^\s*var \w+: String = \w+\.get_scene_file_path\(\)\n", ""),
    (r"^\s*var \w+(: Path2D)? = \w+\.get_move_path\(\)\n", ""),
    (r"^\s*var \w+: int = \w+\._current_path_index\n", ""),
    (r"^\s*var \w+: PackedScene = load\(\w+\)\n", ""),
    (r"^\s*\w+\._current_path_index = \w+\n", ""),
    (r"^\s*YtUtils\.add_object_to_world\(\w+\)\n", ""),
    (r"var (\w+): YtCreep = \w+\.instantiate\(\)\n(\s*)\1\.set_properties\(\w+, \w+, (\w+), (\w+), (\w+), (\w+), (\w+), (\w+)\)",
     r"var \1: YtCreep = YtWorld.game.spawn_yt_creep(\3, \4, \5, \6, \7, \8)\n\2if \1 == null:\n\2\treturn"),
]

# Kleine Änderungen je Datei: [alt, neu]
PATCHES = {
    "ruined_wind_tower": [("var itm: YtItem", "var itm")],
    "creep_meaty": [("YtItemProperties.CONSUMABLE_CHICKEN_ID", "2003")],
}
# Klassen aus YouTD 2, die es hier anders gibt
REPLACE = [("YtTowerDetails.int_format(", "YtUtils.int_format("),
           # Weg als Punktliste (PackedVector2Array) statt Path2D
           (": Path2D = ", " = ")]


def reader():
    if SRC.suffix == ".zip":
        z = zipfile.ZipFile(SRC)
        names = z.namelist()
        root = names[0].split("/")[0]

        def files(folder):
            pre = f"{root}/{folder}/"
            return [(n[len(pre):], z.read(n).decode("utf-8")) for n in names
                    if n.startswith(pre) and n.endswith(".gd") and "/" not in n[len(pre):]]
        return files

    def files(folder):
        return [(p.name, p.read_text(encoding="utf-8")) for p in sorted((SRC / folder).glob("*.gd"))]
    return files


def convert(name: str, text: str, classes: dict) -> str:
    s = rename(text)
    for old, new in REPLACE:
        s = s.replace(old, new)
    # Klassen anderer Skripte (class_name entfällt): über preload, im eigenen Skript ohne Klassennamen
    own = re.search(r"^class_name (\w+)", text, flags=re.M)
    for cls, path in classes.items():
        ref = rename(cls)
        if own and own.group(1) == cls:
            s = re.sub(rf"\b{ref}\.", "", s)
        else:
            s = re.sub(rf"\b{ref}\.", f'preload("{path}").', s)
    s = s.replace("YtUtils.tr(", "YtUtils.tr_text(")
    s = re.sub(r'(?<![\w.])tr\(("[A-Z0-9_]+")\)', r"YtUtils.text(\1)", s)
    s = re.sub(r"^class_name \w+ extends ", "extends ", s, flags=re.M)
    s = re.sub(r"^class_name \w+\n", "", s, flags=re.M)
    if "get_scene_file_path" in s:
        for pat, rep in SPAWN_RULES:
            s = re.sub(pat, rep, s, flags=re.M)
    for old, new in PATCHES.get(name, []):
        if old not in s:
            raise SystemExit(f"{name}: Stelle fehlt: {old[:60]!r}")
        s = s.replace(old, new)
    lines = s.split("\n")
    i = next(k for k, l in enumerate(lines) if l.startswith("extends "))
    lines.insert(i + 1, HEADER.rstrip("\n"))
    return "\n".join(lines)


def file_name(name: str) -> str:
    return name.removesuffix(".gd").replace("+", "_plus").replace("-", "_")


def main():
    files = reader()
    out_n = 0
    folders = (("src/towers/tower_behaviors", "scripts/youtd/towers"), ("src/creeps/special_buffs", "scripts/youtd/specials"))
    classes = {}
    for folder, target in folders:
        for name, text in files(folder):
            m = re.search(r"^class_name (\w+)", text, flags=re.M)
            if m:
                classes[m.group(1)] = f"res://{target}/{file_name(name)}.gd"
    for folder, target in folders:
        dest = ROOT / target
        dest.mkdir(parents=True, exist_ok=True)
        for old in dest.glob("*.gd"):
            old.unlink()
        for name, text in files(folder):
            n = file_name(name)
            (dest / f"{n}.gd").write_text(convert(n, text, classes), encoding="utf-8")
            out_n += 1
        print(f"{target}: {len(list(dest.glob('*.gd')))} Skripte")
    return out_n


if __name__ == "__main__":
    main()
