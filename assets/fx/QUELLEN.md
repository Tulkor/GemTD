# Effekt-Quellen

| Ordner | Herkunft | Umwandlung |
|---|---|---|
| `kenney/` | „Particle Pack“ 1.1 von Kenney (kenney.nl), CC0 (`kenney/License.txt`). 80 Partikel-Bilder mit transparentem Hintergrund, dazu 16 gedrehte Varianten in `kenney/Rotated/`. Die Varianten mit schwarzem Hintergrund und die Unity-Beispiele aus dem Paket sind nicht übernommen. | `tools/fx/kenney_effekte.py` → `data/fx/hits.json` (Treffer nutzen die Bilder direkt) |
| `shot/` | Aus den Kenney-Bildern gerechnete Sprite-Sheets (Strahl, Blitz, Feuerball, Nova), damit ebenfalls CC0. | `tools/fx/kenney_effekte.py` → `data/fx/shots.json` |

Das Kenney-Paket ist CC0 und darf frei weitergegeben werden; eine Nennung ist erwünscht, aber nicht Pflicht.

Früher lagen hier Treffer aus dem Unity-Paket „FX_Hit_Collection“ (Asset Store) und Schüsse aus FootageCrate-Videos.
Beide erlauben keine Weitergabe der Rohdateien in einem öffentlichen Repo und wurden deshalb entfernt.
