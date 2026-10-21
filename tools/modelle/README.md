# Modelle aus CC0-Paketen

- `python3 -I tools/modelle/umwandeln.py --paket=<name>=<entpackter Ordner> …` holt die in `auswahl.json`
  eingetragenen Modelle nach `assets/models/` (eine .glb je Modell, Texturen eingebettet und verkleinert,
  Tangenten und Normalmaps weggelassen). glTF/GLB rechnet Python selbst, FBX geht über Godot (`umwandeln.gd`).
  Paketnamen stehen in `auswahl.json` unter `_info`.
- Ausprobieren ohne das Repo zu ändern: `--auswahl=/tmp/kandidaten.json --ziel=/tmp/kandidaten`.
- `tools/modelle/vorschau.sh <bogen.png> <a.glb> …` rendert jedes Modell einzeln und setzt einen Kontaktbogen
  mit Namen zusammen (zum Auswählen).
- Lizenz jedes Pakets prüfen und in `assets/models/CREDITS.md` eintragen (Regel in CLAUDE.md).

Verwendung im Spiel: eeveTD über `LOOK` in `tools/wc3/eeve/eeve_daten.py` (Modell, `model_solid`, `flame`, `hit_fx`),
Shopping Maul über `data/maul/models.json`.

Boss-Modell: `tools/modelle/boss_rig.py` gibt dem starren "Little Man" (CC-BY) Skelett und Animationen
(`walk`, `idle`, `hit`, `death`). Braucht Blender als Python-Modul: `uv venv -p python3.13 env && uv pip install -p env/bin/python bpy`.
Animationen ansehen: `tools/modelle/vorschau.sh bogen.png --animationen assets/models/enemies/little_man.glb`.

Gegner-Modelle (Skelett, Schleim, Drache, Fledermaus, Quaternius CC0): `tools/modelle/monster_umwandeln.py` wandelt die FBX
aus dem "Animated Monster Pack" mit denselben Animationsnamen wie beim Boss um:
`<python mit bpy> -I tools/modelle/monster_umwandeln.py -- "<Paket>/FBX" assets/models/enemies`.
