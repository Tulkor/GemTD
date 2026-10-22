# Map- und Tower-Editor (HTML)

Map- und Tower-Editor außerhalb des Spiels: eine einzige HTML-Datei, läuft ohne Installation im Browser
(Doppelklick, Edge, Chrome oder Firefox). Ergebnis ist eine eigene JSON-Datei im Format von `data/maps`
bzw. `data/towers`, die man weiterschicken kann.

## Bedienung
- **Map**: Werkzeuge Blockiert / Nur Weg / Boden / Spawn / Ziel / Checkpoint (Tasten 1–6), Pinsel 1×1, 2×2
  (eine Towerbreite) oder 4×4. Linksklick malt, Rechtsklick radiert (auf einem Checkpoint: entfernt ihn),
  mittlere Maustaste oder Leertaste + Ziehen verschiebt, Mausrad zoomt, Strg+Z / Strg+Y.
  Der Weg (Spawn → Checkpoints → Ziel) wird wie im Spiel berechnet (diagonal nur ohne Ecken schneiden).
  Checkpoints lassen sich links umsortieren. Maul-Maps mit mehreren Bahnen: Bahn wählen, Spawn und
  Checkpoints gelten dann für diese Bahn; Baugebiete werden nur angezeigt und bleiben unverändert.
- **Tower**: mitgelieferte Tower als Vorlage wählen oder **+ Gem** / **+ Spezial**; Stufen mit Schaden,
  Reichweite, Abklingzeit und Fähigkeiten (aus `scripts/game/abilities.gd`), Rezept und Upgrades wie im
  Tower-Editor des Spiels. **Erweitert (JSON)** zeigt und ändert alle Felder.
- **Datei öffnen** (oder Datei ins Fenster ziehen) lädt eine Map oder einen Tower, **Als Datei speichern**
  (Strg+S) lädt `<id>.json` herunter.

## Im Spiel verwenden
Map-Editor bzw. Tower-Editor im Spiel → **Datei importieren** → Datei wählen → **Speichern**.
Die Datei landet dann im Benutzerordner (`%APPDATA%\godot\app_userdata\GemTD Nachbau\data\maps|towers\`);
man kann sie auch direkt dorthin kopieren. Ins Repo: Datei nach `data/maps/` bzw. `data/towers/` legen.

## Format
Geschrieben wird wie `Database.save_json` (Tabs, Kommazahlen bleiben Kommazahlen, unbekannte Felder bleiben
erhalten). Jede mitgelieferte Map und jeder Tower kommt unverändert Byte für Byte gleich heraus
(geprüft in `pruefen.mjs`). Die JSON-Funktionen stammen aus dem Balance-Editor (`tools/balance_editor/`).

## Dateien
- `editor.html`: der Editor (ohne Daten: dann nur über „Datei öffnen“).
- `bauen.py`: bettet Maps, Tower, Wellen-Sets, Modi, Effekte, Fähigkeiten und Schrift ein, Ergebnis
  `/mnt/project-files/editoren/td_editor.html` (eine Datei zum Weitergeben, etwa 1 MB).
- `pruefen.mjs`: Test im Browser (Format, Malen, Weg, Rückgängig, Speichern und Öffnen, Tower mit Rezept).
  `tools/run_tests.sh htmleditor`.
