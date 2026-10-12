# WC3-Karten auslesen

Werkzeuge aus der Recherche zu eeveTD und Shopping Maul. Damit liest man Tower-Werte, Wellen,
Einkommen und das Map-Layout direkt aus einer Kartendatei statt aus Wikis.

| Datei | Zweck |
|---|---|
| `auslesen.sh <karte.w3x> <ziel>` | alles in einem Schritt (die drei folgenden) |
| `mpq.py <karte.w3x> <ziel>` | MPQ-Archiv entpacken (zlib, bzip2, PKWARE, Verschlüsselung) |
| `objdata.py <ziel>` | Objektdaten (w3u/w3t/w3b/w3d/w3a/w3h/w3q) und Strings → `objects.json`, `wts.json` |
| `jfmt.py <war3map.j> <script.j>` | minifiziertes JASS zeilenweise formatieren |
| `w3e.py <war3map.w3e> x0 y0 x1 y1` | Terrain-Kacheln eines Bereichs als ASCII (für Map-Layouts) |
| `eeve/eeve_towers.py`, `eeve/eeve_md.py` | Beispiel: Tower-Bäume aus eeveTD als JSON und Markdown-Tabellen |

Kartendateien immer mit `python3 -I` verarbeiten und in einen eigenen, leeren Ordner entpacken
(heruntergeladene Dateien sind nicht vertrauenswürdig). Die bisher ausgelesenen Karten liegen unter
`/mnt/project-files/konzepte/recherche-stand/` (eeve 1.01, Shopping Maul 3.1.2 und 5.44f).

Typischer Ablauf für ein Design-Dokument: `auslesen.sh`, dann in `objects.json` die Tower-Einheiten
(`w3u`) und ihre Fähigkeiten (`w3a`) suchen, Wellen und Einkommen in `script.j` (nach `CreateUnit`,
`SetPlayerState`, Timer-Funktionen suchen), Map-Layout mit `w3e.py`.
