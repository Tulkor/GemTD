# Hinweise für Claude

## UI-Stil (Arcade), gilt für alles Neue
Lukas will, dass jede neue Oberfläche automatisch im Arcade-Stil gebaut wird, ohne dass er es extra sagen muss.
Alles kommt aus `scripts/ui/ui_theme.gd`, keine eigenen Farben oder Schriften erfinden:
- Panels: `UiTheme.panel(pad)`: eckig, pinker Rand (3 px), harter Cyan-Schatten.
- Überschriften: `UiTheme.title(label, size)`: Großbuchstaben, fett, pink mit Cyan-Schatten.
  Kleine Abschnittstitel: Großbuchstaben, fett (`UiTheme.font(true)`).
- Hauptaktion: `UiTheme.accent_button(...)`; ausgewählt/gedrückt: `UiTheme.box(UiTheme.CYAN, UiTheme.CYAN)` mit dunkler Schrift.
- Farben: `TEXT`, `MUTED`, `GOLD` (Akzent-Pink), `CYAN`, `COIN` (Goldbeträge), `HAVE` (grün), `MISSING` (rot), `PURPLE_LIGHT`.
- Schrift: DejaVu Sans Mono über das Theme (`UiTheme.get_theme()`), Ecken immer eckig.
- Lange Texte mit Autowrap, damit mit der breiten Monospace-Schrift nichts abgeschnitten wird.
- Alle sichtbaren Texte auf Deutsch schreiben und in `data/i18n/en.json` übersetzen.

## Threads: ein Feature, ein Thread (feste Regel von Lukas)
Jede Antwort schleppt den ganzen Verlauf eines Threads mit, lange Threads kosten deshalb viele Tokens.
- Jedes größere neue Feature bekommt einen eigenen, frischen Thread (z. B. „eeveTD-Modus“, „Maul-Koop“), nicht die alten Kategorie-Threads.
- Die Kategorie-Threads (Game-Systeme, UI und UX, Balance, Grafik) sind nur für kleine Nachbesserungen und Rückfragen.
- Ist ein Feature fertig und gemergt, wird sein Thread geschlossen. Was ein späterer Thread wissen muss, steht im Repo (CLAUDE.md, README, Commit-Texte) oder unter /mnt/project-files/, nicht nur im Chat.

## Werkzeuge: erst diese benutzen, statt Abläufe neu zu schreiben
Godot und die Windows-Vorlage installiert der Session-Start-Hook (`tools/setup_godot.sh`), `godot` liegt in `~/.local/bin`.
- Tests: `tools/run_tests.sh` (schnell: Prüfskripte, Smoke, Netz, Sitzung, Koop) oder `alle` (dazu Balance, Tempo, späte Wellen), einzeln z. B. `tools/run_tests.sh smoke koop`. Gibt nur eine Zeile pro Test aus, Logs in `/tmp/gemtd-tests/`.
- Build (nur wenn Lukas ausdrücklich fragt): `tools/build_windows.sh` → nächste Nummer in `/mnt/project-files/builds/`, Tests vorher, Git-Tag `v0.<N>`. Release-Notes-Entwurf: `python3 tools/release_notes.py <N>`.
- Screenshots: `tools/screenshot.sh --runden=3 --phase=wahl --auswahl --winkel=schraeg,oben --name=…` (Optionen in `tools/screenshot.gd`), Bilder unter `/mnt/project-files/screens/`.
- Tower-Tabelle: `python3 tools/tower_tabelle.py --kopieren`; der Git-Hook `tools/git-hooks/pre-commit` macht das bei Commits mit Tower-Daten automatisch.
- Balance: `python3 tools/balance_bericht.py [--vergleich=main] [--tower=ruby:5,…]` → Tabelle Boss/Normal/Masse/Luft als .md und .html in `/mnt/project-files/balance/`.
- Maps: `python3 tools/map_check.py` (Größe, Weglänge, Abschnitte, Fehler); Maze-Rechner in `tools/maze/`.
- Texte: `python3 tools/pruefe_ui.py [--stil]` findet fehlende englische Übersetzungen und Farben außerhalb des Themes.
- WC3-Karten: `tools/wc3/auslesen.sh karte.w3x ziel/` (siehe `tools/wc3/README.md`).
- Alte Builds: `tools/builds_aufraeumen.sh` zeigt nur an; `--wirklich` nur auf Lukas' ausdrücklichen Wunsch.

## Code-Landkarte
- `scripts/autoload/`: `database.gd` lädt alle JSON-Daten (`Database.towers`, `.enemies`, `.wave_sets`, `.balance`, `list_maps()`); `session.gd` trägt Werte zwischen Szenen (Map, Schwierigkeit, Wertung, Koop, Debug); `loc.gd` Sprache; `display.gd` Fenster; `net.gd` ENet, Lobby und Sitzungen.
- `scripts/game/game.gd`: Spielablauf (Phasen BUILD → CHOOSE → WAVE, Wellen, Gold, Leben/Punkte, Kombinieren, Rezepte). Alle Spieleraktionen laufen als Befehle über `submit(cmd)` → `execute(cmd)`/`_execute` mit Spielernummer; im Koop rechnet nur der Host. Pro Spieler: `player_state.gd`. Wird von Game-Systeme laufend umgebaut, Änderungen klein halten und vorher pullen.
- `tower.gd` (Schießen, Fähigkeiten, Kill-Ränge), `abilities.gd` (Schema aller Fähigkeiten, daraus baut der Tower-Editor sein Formular), `enemy.gd` (Bewegung, Rüstung, Effekte), `tower_stats.gd` (Werte fürs Infofenster).
- Oberfläche im Spiel: `hud.gd` (Leiste oben, Auswahlkarte unten, Endbildschirm), `dps_meter.gd`, `enemy_panel.gd`, `tower_list.gd`, `setup_panel.gd`; Bausteine in `scripts/ui/` (`ui_theme.gd`, `ui_util.gd`, Tooltips, Rezeptbuch, Menü, Lobby, Run-History).
- Spielstände: `save_game.gd` (verschlüsselt, auch mitten in der Welle), `run_history.gd`.
- Karte: `map_data.gd` (Format, Bahnen, Zonen), `pathfinder.gd` (AStar über Wegpunkte, keine Ecken schneiden), `board_3d.gd` (Neon-Gitter, Steine, Weg; `CELL = 0.5`, `footprint()`), `camera_rig.gd`.
- Netz: `scripts/net/` (`coop_sync.gd` gemeinsames Feld, `net_sync.gd`/`remote_field.gd`/`net_panel.gd` Zuschauen im Modus „jeder sein Feld“).
- Tests in `tests/` (Smoke prüft fast alles, Netz/Sitzung/Koop laufen als Host+Client). Daten in `data/` (towers, enemies, waves, maps, balance.json, i18n/en.json).
