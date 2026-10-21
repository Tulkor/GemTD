# Modelle

Alle Modelle stehen unter CC0 (Public Domain), außer dem Boss-Modell (CC-BY 3.0, siehe unten).

- `crystals/crystal_*.glb`: "Crystal Pack" von iPoly3D, https://poly.pizza/bundle/Crystal-Pack-AywAG7aywi
- `crystals/quaternius_*.glb`: "Crystal" und "Big Crystal" von Quaternius (poly.pizza)
- `rocks/*.glb`: "Rock" und "Rock Large" von Quaternius (poly.pizza)

Die Kristalle werden im Spiel in der Farbe des Towers eingefärbt (Feld "color" in data/towers/*.json).

- `special/*.glb`: Quaternius (CC0), von Lukas hochgeladen: `crystal_tree_1..3` (Tree_Blob), `lava_tree` (Tree_Lava),
  `gold_ore` (Resource_Gold). Werden mit eigenen Farben verwendet ("model_tint": false in den Tower-Daten).
  `platonic.glb`: ebenfalls von Lukas (laut ihm auch Quaternius).

## CC0-Pakete für eeveTD und Shopping Maul (2026-10-19)

Von Lukas hochgeladen, Lizenztexte in `licenses/`. Nur die verwendeten Modelle liegen im Repo, umgewandelt
mit `tools/modelle/umwandeln.py` (Auswahl in `tools/modelle/auswahl.json`, Texturen eingebettet und auf 256 px verkleinert).

- `nature/` (eeveTD-Tower, Gärtnerei und Bestatter im Shopping Maul):
  - Bäume, Büsche, Pflanzen, Blumen, Pilze, Felsen (`common_tree_*`, `pine_*`, `bush_*`, `plant_*`, `fern_1`,
    `flower_*`, `mushroom_common`, `mushroom_laetiporus`, `rock_medium_*`): "Stylized Nature MegaKit" (Standard)
    von Quaternius, CC0, https://quaternius.com/packs/stylizednaturemegakit.html
  - Statuen, Obelisken, Feuerstellen, Steine, Topf, Seerose, Pilzgruppen (`statue_*`, `stone_tall_*`, `rock_tall_*`,
    `campfire_stones`, `campfire_bricks`, `pot_large`, `lily_large`, `mushroom_red_*`, `mushroom_tan_group`):
    "Nature Kit" 2.1 von Kenney, CC0, https://kenney.nl/assets/nature-kit
  - `campfire_pit`: "Survival Kit" 2.0 von Kenney, CC0, https://kenney.nl/assets/survival-kit
- `city/` (Shopping-Maul-Tower):
  - Häuser `1story*` bis `6story_stack`: "Ultimate Textured Building Pack" (Dec 2019) von Quaternius, CC0
    (laut quaternius.com; das Zip enthält keinen Lizenztext). Verwendet sind die Varianten mit Materialien
    ("_Mat"); das Material "Main" färbt das Spiel in der Filialfarbe ein.
  - `building_skyscraper_*`: "City Kit (Commercial)" 2.1 von Kenney, CC0, https://kenney.nl/assets/city-kit-commercial

Ebenfalls hochgeladen, aber noch nicht verwendet (bei Bedarf über `auswahl.json` holen): Kenney City Kit Suburban,
Kenney Modular Buildings (beide CC0).

## Gegner-Modelle (CC0, 2026-10-21)

- `enemies/skeleton.glb`, `slime.glb`, `dragon.glb`, `bat.glb`: "Animated Monster Pack" von Quaternius, CC0
  (Lizenztext in `licenses/quaternius_animated_monsters.txt`), von Lukas hochgeladen. Umgewandelt mit
  `tools/modelle/monster_umwandeln.py` (Blender): Animationen umbenannt in `walk`, `idle`, `hit`, `death`, Materialien
  deckend gemacht, Augen-Skelett starr an den Kopf gehängt. Im Spiel (`scripts/game/enemy.gd`, `MONSTERS`):
  Skelett = Bodengegner, Schleim = Massenwelle, Drache = Flieger, Fledermaus = Massenflieger; ein Material wird in
  Richtung der Gegnerfarbe eingefärbt.

## eeveTD-Umgebung: Friedhof, Kirche, handgemalte Pflanzen (CC0, 2026-10-21)

Von Lukas hochgeladen, Lizenztexte in `licenses/`. Verwendet in `scripts/map/eeve_scenery.gd`.

- `scenery/gravestone_*`, `cross_wood`, `grave`, `urn_round`, `crypt`, `iron_fence*`, `lightpost_single`:
  "Graveyard Kit" 5.0 von Kenney, CC0, https://kenney.nl/assets/graveyard-kit (über `tools/modelle/umwandeln.py`)
- `scenery/church.glb`: "Medieval Church" von Daniel74, CC0, Blend Swap 75990 (http://www.blendswap.com/blends/view/75990).
  Umgewandelt mit `tools/modelle/kirche_umwandeln.py`: Statue im Inneren entfernt, Texturen neu zugeordnet und auf 256 px verkleinert.
- `nature/hp_*.glb`: "HandPainted Plants 2" von Nobiax / Yughues, CC0 (Pflanzen-Karten mit Alpha, Textur über das Feld
  `textur` in `tools/modelle/auswahl.json`).

Nicht verwendet: "free_mine_assets" (hochgeladen 2026-10-21) enthält keinen Lizenztext und keine Quellenangabe.

## Boss-Modell (CC-BY 3.0, Nennung Pflicht)

- `enemies/little_man.glb`: Little Man by Don Carson [CC-BY] (https://creativecommons.org/licenses/by/3.0/) via Poly Pizza (https://poly.pizza/m/8KU4S7I0sL8)
  - Von Lukas hochgeladen (2026-10-20). Geändert: Skelett und Animationen `walk`, `idle`, `hit`, `death` ergänzt, Arme aus der T-Pose nach unten gelegt,
    Füße auf den Ursprung gesetzt (`tools/modelle/boss_rig.py`, Blender). Wird für alle Gegner mit `"boss": true`
    ohne eigenes Modell verwendet (`scripts/game/enemy.gd`, `BOSS_MODEL`).
