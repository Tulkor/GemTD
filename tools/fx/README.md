# Effekte umwandeln

| Datei | Zweck |
|---|---|
| `treffer_umwandeln.py <ordner>` | entpacktes Unity-`.unitypackage` (`tar xzf paket -C ordner`) → `data/fx/hits.json` + Texturen in `assets/fx/hit/`. Jedes Prefab wird ein Effekt, jedes Partikelsystem eine Ebene (Bursts, Rate, Lebenszeit, Größe/Farbe über die Lebenszeit, Sprite-Sheets, Formen Kugel/Kegel). |
| `video_zu_sheet.py <id> <video> line\|nova` | Video mit Alphakanal → Sprite-Sheet `assets/fx/shot/<id>.png` + Eintrag in `data/fx/shots.json` (Wiedergabe-Werte wie `length`, `width`, `brightness`, `kind` bleiben erhalten). |
| `vorschau.sh [--tower=ruby,topaz] [--zeiten=0.1,0.2]` | Bild aller Effekte bzw. der Effekte einzelner Tower nach `/mnt/project-files/screens/fx/`. |
| `unity_lesen.py` | Hilfsmodul: Unity-YAML lesen. |

Heruntergeladene Pakete und Videos immer in einen eigenen, leeren Ordner entpacken und mit `python3 -I` verarbeiten.

Im Spiel: `scripts/game/fx_data.gd` wählt die Effekte pro Tower (Felder `hit_fx`/`shot_fx` in der Tower-Datei,
sonst automatisch nach Farbe; Regeln in `data/fx/shots.json` → `auto`), `scripts/game/fx_player.gd` spielt sie ab.
