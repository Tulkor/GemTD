# Effekt-Quellen

| Ordner | Herkunft | Umwandlung |
|---|---|---|
| `hit/` | Unity-Paket „FX_Hit_Collection“ (Unity Asset Store), von Lukas bereitgestellt | `tools/fx/treffer_umwandeln.py` → `data/fx/hits.json` |
| `kenney/` | „Particle Pack“ 1.1 von Kenney (kenney.nl), CC0 (`kenney/License.txt`). 80 Partikel-Bilder mit transparentem Hintergrund, dazu 16 gedrehte Varianten in `kenney/Rotated/`. Die Varianten mit schwarzem Hintergrund und die Unity-Beispiele aus dem Paket sind nicht übernommen. | noch nicht eingebaut |
| `shot/` | Videos von FootageCrate (productioncrate.com): Magic Spell 12, Wizard Apparition Side 1, Flash Lightning Arc, Ruby Magic Shield Block Front 1 | `tools/fx/video_zu_sheet.py` → `data/fx/shots.json` |

`hit/` und `shot/` erlauben die Nutzung im Spiel, aber in der Regel nicht die Weitergabe der Rohdateien.
Solange das Repo öffentlich ist, bitte vor einer Veröffentlichung die Lizenzen prüfen.

Das Kenney-Paket ist CC0 und darf frei weitergegeben werden; eine Nennung ist erwünscht, aber nicht Pflicht.
