# GemTD Nachbau (Godot 4, GDScript)

Erster Stand: Labyrinthbau, Gegner und Wellen, Map-Editor, Tower-Editor.
Getestet mit Godot 4.3, sollte in jeder neueren 4.x-Version laufen.

## Starten

Godot öffnen → *Importieren* → `project.godot` wählen → F5.
Im Hauptmenü Map wählen und *Spielen*.

**Spielablauf (wie in GemTD):**
1. Bauphase: 5 zufällige Gems ins Feld setzen (Linksklick). Das Spiel lässt nicht zu, dass der Weg komplett blockiert wird.
2. Einen der 5 neuen Gems anklicken und rechts wählen: behalten, 2 gleiche → nächste Stufe, 4 gleiche → +2 Stufen, oder ein Spezial-Rezept (z. B. Topas + Diamant + Saphir → Silber). Die anderen 4 werden zu Steinen.
3. Die Welle startet. Gegner laufen Spawn (S) → Checkpoints 1…n → Ziel (Z). Flieger fliegen direkt von Punkt zu Punkt.

Mit Gold aus Kills steigt die *Chance-Stufe* (bessere Gem-Qualitäten).
Tasten 1/2/3 = Tempo 1x/2x/4x. Unter „Debug: nächster Gem“ kann man jeden Tower gezielt setzen.

## Ordnerstruktur

```
data/
  balance.json        Gems pro Runde, Chance-Stufen (Kosten, Gewichte je Qualität)
  maps/*.json         Maps
  towers/*.json       ein Tower pro Datei
  enemies/*.json      ein Gegnertyp pro Datei
  waves/*.json        Wellen-Sets (eine Map verweist per "waves" auf ein Set)
scenes/               Hauptmenü, Spiel, Map-Editor, Tower-Editor (UI wird im Code gebaut)
scripts/
  autoload/database.gd  lädt alle JSON-Daten
  autoload/session.gd   Übergaben zwischen Szenen
  map/                  MapData (Format), Pathfinder (A* über Checkpoints), MapView (Zeichnen)
  game/                 Spiel, Tower, Gegner, Fähigkeiten, HUD
  editor/               Map-Editor, Tower-Editor
tests/smoke_test.tscn   automatischer Test
```

Alles ist datengetrieben: neue Maps, Tower, Gegner und Wellen brauchen keinen Code.
Dateien unter `user://data/<typ>/` werden zusätzlich geladen und überschreiben gleiche IDs (für Mods/Exporte).

## Map-Format (`data/maps/*.json`)

```json
{
  "id": "classic", "name": "Klassisch",
  "width": 37, "height": 37,
  "tiles": ["#####…", "#....…", …],
  "spawn": [4, 4], "goal": [32, 32],
  "checkpoints": [[4, 18], [32, 18], …],
  "marker_radius": 1,
  "waves": "classic", "lives": 50, "start_gold": 0,
  "variance": {"random_rocks": 25, "seed": -1}
}
```
Kacheln: `.` Boden (bebaubar), `#` blockiert, `_` nur Weg (begehbar, nicht bebaubar).
Um Spawn, Ziel und Checkpoints ist im Umkreis `marker_radius` nicht bebaubar.
`variance.random_rocks` setzt bei jedem Spielstart zufällig Steine (ohne den Weg zu blockieren), `seed` ≥ 0 macht das reproduzierbar.

**Map-Editor:** Kacheln malen (Linksklick, ziehen), Rechtsklick radiert. Spawn/Ziel/Checkpoints per Werkzeug setzen; Checkpoints werden in Klick-Reihenfolge nummeriert, erneuter Klick entfernt. Der Weg wird live angezeigt. *Testen* startet das Spiel direkt mit der Map, *Zurück* führt in den Editor zurück.

## Tower-Format (`data/towers/*.json`)

```json
{
  "id": "ruby", "name": "Rubin",
  "category": "gem",            // "gem" = wird gewürfelt, "special" = per Rezept
  "color": "#e0303a",
  "targets": "both",            // "both" | "ground" | "air"
  "recipe": [{"tower": "topaz", "tier": 0}, …],   // nur bei "special"
  "tiers": [                    // bei Gems: Splitter, Fehlerhaft, Normal, Makellos, Perfekt
    {"damage": [8, 11], "range": 3.0, "cooldown": 0.8,
     "abilities": [{"type": "splash", "radius": 1.0, "factor": 0.5}]}
  ]
}
```
Reichweite und Radien in Feldern, Abklingzeit in Sekunden. Eine Stufe kann optional `"name"` und `"targets"` überschreiben.

Fähigkeiten (`scripts/game/abilities.gd`): `splash`, `slow`, `poison`, `crit`, `multishot`, `speed_aura`.
Eine neue Fähigkeitsart: in `Abilities.SCHEMA` eintragen (dann erscheint sie im Tower-Editor) und in `Tower._attack()`/`_hit()` umsetzen.

**Tower-Editor:** Tower wählen oder neu anlegen, Werte, Stufen, Fähigkeiten und Rezept bearbeiten. *Speichern und im Spiel testen* öffnet das Spiel mit diesem Tower als nächstem Gem.
Aus dem Godot-Editor gestartet, speichern beide Editoren direkt nach `res://data/…`; in einem exportierten Spiel nach `user://data/…`.

## Gegner und Wellen

`data/enemies/*.json`: `hp`, `speed` (Felder/s), `armor` (WC3-Formel), `bounty`, `damage` (Leben bei Durchbruch), `flying`, `color`, `size`.
`data/waves/*.json`: Liste von Wellen, jede mit `groups`: `{"enemy": "grunt", "count": 10, "interval": 0.8, "hp": 30}` – `hp`, `speed`, `armor`, `bounty`, `damage` überschreiben die Grundwerte.

## Test

```
godot --headless --path . res://tests/smoke_test.tscn
```
Prüft Laden aller Daten, Wegfindung, Blockier-Schutz, alle Szenen, 3 automatisch gespielte Wellen sowie Kombinieren und Rezepte.

## Bewusst noch offen

- Balancing (Werte sind grobe Schätzungen), nur 2 Spezial-Tower, keine Upgrades von Spezial-Towern
- Gems sind 1×1 Feld (in WC3 2×2), Steine lassen sich nicht entfernen
- Kein Export-Preset; beim Export `*.json` in die Ressourcen-Filter aufnehmen
