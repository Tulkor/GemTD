# GemTD Nachbau (Godot 4, GDScript, 3D)

Nachbau der Warcraft-3-Map **Gem TD**. Alle Tower, Fallen, Rezepte und Werte stammen aus
**[BK's] Gem Tower Defense v3.1** (letzte offizielle Version von Bryvx), die Gegner und
Level aus **Gem TD+ 1.6.14**. Die Recherche mit Quellen liegt in `docs/wc3_referenz.md`.
Getestet mit Godot 4.3, sollte in jeder neueren 4.x-Version laufen.

![Screenshot](docs/screenshot_3d.png)

## Starten

Godot öffnen → *Importieren* → `project.godot` wählen → F5.
Im Hauptmenü Map wählen und *Spielen*.

**Steuerung:** Linksklick setzt Gems bzw. wählt Tower/Steine, Rechtsklick/Esc hebt die Auswahl auf.
Kamera: WASD/Pfeile, Maus an den Fensterrand oder mit gedrückter rechter Maustaste ziehen verschiebt, Q/E oder mittlere Maustaste drehen, Mausrad zoomt. Tasten 1/2/3: Tempo.
Leertaste: große Aktion unten rechts (Behalten, bzw. lila One-Shot). R: Rezeptbuch.

**Oberfläche:** Leiste oben (Welle, Leben, Gold, Chance-Stufe, Tempo), darunter das Phasenbanner.
Unten die Auswahlkarte: die neuen Gems der Runde (lila Rand = Zutat für einen One-Shot/Spezial-Tower),
Werte des angeklickten Towers, „Wird gebraucht für“ mit allen Rezepten, in denen er vorkommt, und die Aktionen.
Im Rezeptbuch (R) stehen alle Spezial-Rezepte, Zutaten grün (✓ vorhanden) oder rot (✗ fehlt).
Mit „Pin“ angepinnte Rezepte erscheinen links oben und zeigen, was noch fehlt.
„Weg“ in der Leiste oben zeigt die Länge des Laufwegs in Feldern, in der Bauphase mit der Änderung seit Rundenbeginn.
Am Spielende öffnet sich ein Menü: nochmal mit denselben Einstellungen spielen oder zurück ins Hauptmenü.

**Spielablauf wie in Gem TD:**
1. Bauphase: 5 zufällige Gems setzen. Der Weg kann nie ganz blockiert werden.
   Das Raster ist halb so groß wie ein Tower: Tower belegen 2×2 Felder, lassen sich also um eine
   halbe Breite versetzen, und Gegner passen durch Lücken von einem Feld (wie in WC3).
2. Einen der 5 neuen Gems anklicken und rechts wählen: behalten, 2 gleiche → +1 Qualität,
   4 gleiche → +2 Qualitäten (über „Großartig“ hinaus entsteht der Stein von Bryvx),
   oder ein Spezial-Rezept. Die anderen 4 werden zu Steinen. Mit „Abstufen“ behält man einen Gem
   eine Qualität niedriger (z. B. Fehlerhaft → Splitter), etwa weil ein Rezept genau diese Stufe braucht.
   **One-Shot:** Sind schon während der Bauphase alle Zutaten eines Spezial-Rezepts da (gesetzte Gems
   dieser Runde; fertige Tower auf dem Feld zählen dafür nicht), zeigt das Spiel das an. Gem anklicken und „One-Shot“
   wählen baut den Spezial-Tower sofort; die restlichen Gems der Runde entfallen.
3. Die Welle startet. Gegner laufen Spawn (S) → Checkpoints 1…5 → Ziel (Z). Flieger fliegen direkt.

Weitere Regeln:
- **Spezial-Tower:** Zutaten aus den Gems dieser Runde *oder* fertige Tower auf dem Feld. Fertige Tower
  untereinander kombinieren geht nur während der Welle. Beim Setzen und Auswählen der neuen Gems zählen
  für Rezepte nur die Gems dieser Runde.
  Verbrauchte Tower vom Feld werden zu Steinen. Upgrades (z. B. Silber → Sterlingsilber → Silberritter) kosten Gold.
- **Fallen (Platten):** Normaler Gem + einer der passenden fehlerhaften Gems in derselben Runde.
  Gegner laufen über Fallen. Zwei Fallen auf dem Feld ergeben eine kombinierte Falle
  (z. B. Halteplatte + Luftplatte → Uralte Platte): während der Welle eine Falle anklicken, dann „Kombinieren“.
- **Steine** in der Bauphase anklicken und kostenlos entfernen.
- **Gem-Qualität** gegen Gold steigern (8 Stufen, 20–230 Gold), danach kommen bessere Gems.
- **Kill-Ränge:** +10 % Schaden pro 10 Kills (max. +120 %).
- **Schadensarten gegen Rüstungsarten** wie in WC3 (Tabelle in `data/balance.json`).

Unter „Debug: nächster Gem“ lässt sich jeder Tower in jeder Stufe direkt setzen.

## Tower

| Gems (je 6 Qualitäten) | Spezial-Tower (mit Upgrades) | Fallen |
|---|---|---|
| Amethyst, Aquamarin, Diamant, Smaragd, Opal, Rubin, Saphir, Topas | Silber, Malachit, Sternrubin, Jade, Roter Kristall, Dunkler Smaragd, Gold, Uran 238, Rosa Diamant, Paraiba-Turmalin, Schwarzer Opal, Blutstein, Gelber Saphir, Stein von Bryvx | Luft-, Halte-, Verlangsamungs-, Opalader-, Zauber-, Gift-, Reichweiten-, Schadensplatte; kombiniert: Uralte, Geister-, Ältesten-, Viperplatte |

Vereinfachungen gegenüber WC3 (stehen auch in den Tower-Dateien als Fähigkeiten):
Zauber wie Frostnova, Blitz oder Messerfächer sind als „nova“ (Flächenschaden mit Chance) umgesetzt;
die Teleport-Fähigkeit der Platten, das „Swap“ des Schwarzen Opals und Extra Chance fehlen noch;
Ein Tower ist 128 WC3-Einheiten breit und belegt 2×2 Felder; ein Feld sind 64 WC3-Einheiten.

## Ordnerstruktur

```
data/
  balance.json        Gems pro Runde, Qualitätsstufen, Schadenstabelle, Kill-Ränge, Steinkosten
  maps/*.json         Maps
  towers/*.json       ein Tower bzw. eine Falle pro Datei
  enemies/*.json      ein Gegnertyp pro Datei
  waves/*.json        Wellen-Sets (eine Map verweist per "waves" auf ein Set)
assets/models/        3D-Modelle (CC0, siehe CREDITS.md)
scenes/               Hauptmenü, Spiel, Map-Editor, Tower-Editor (UI wird im Code gebaut)
scripts/
  autoload/           Database (lädt alle JSON-Daten), Session (Übergaben zwischen Szenen)
  map/                MapData (Format), Pathfinder (A* über Checkpoints), Board3D, CameraRig
  game/               Spiel, Tower, Gegner, Fähigkeiten, Modelle, HUD
  editor/             Map-Editor, Tower-Editor
tests/smoke_test.tscn automatischer Test
docs/                 WC3-Referenzdaten und Screenshot
```

Alles ist datengetrieben: neue Maps, Tower, Gegner und Wellen brauchen keinen Code.
Dateien unter `user://data/<typ>/` werden zusätzlich geladen und überschreiben gleiche IDs.

## Map-Format (`data/maps/*.json`)

```json
{
  "format": 2, "id": "classic", "name": "Klassisch", "width": 74, "height": 74,
  "tiles": ["#####…", "#....…", …],
  "spawn": [8, 8], "goal": [65, 65], "checkpoints": [[8, 36], [65, 36], …],
  "marker_radius": 1, "waves": "classic", "lives": 50, "start_gold": 0,
  "variance": {"random_rocks": 25, "seed": -1}
}
```
Alle Angaben in Feldern (halbe Towerbreite). Maps ohne `"format": 2` stammen aus der Zeit, als ein Feld
ein Tower war, und werden beim Laden automatisch verdoppelt.
Kacheln: `.` Boden (bebaubar), `#` blockiert, `_` nur Weg. Um Spawn, Ziel und Checkpoints ist im Umkreis
`marker_radius` nicht bebaubar. `variance.random_rocks` setzt bei jedem Start zufällig Steine.

**Map-Editor:** Kacheln malen (Linksklick, ziehen, Pinselgröße einstellbar), Rechtsklick radiert (rechts ziehen verschiebt die Kamera). Spawn/Ziel/Checkpoints per Werkzeug.
Der Weg wird live angezeigt, *Testen* startet das Spiel mit der Map.

## Tower-Format (`data/towers/*.json`)

```json
{
  "id": "silver", "name": "Silber",
  "category": "special",          // "gem" = wird gewürfelt, "special" = per Rezept
  "kind": "tower",                // "trap" = Falle, Gegner laufen darüber
  "color": "#c8d0d8",
  "model": "res://assets/models/crystals/crystal_09.glb",   // optional, sonst einfache Form
  "damage_type": "spells",        // pierce, magic, normal, siege, hero, spells, chaos
  "targets": "both",              // both | ground | air
  "recipe": [{"tower": "topaz", "tier": 0}, {"any_of": [{"tower": "ruby", "tier": 1}, …]}],
  "recipe_same_round": false,     // true = alle Zutaten aus derselben Runde
  "upgrades": [{"cost": 25, "recipe": []}],     // Stufe 1 → 2, 2 → 3 …
  "tiers": [
    {"name": "Silber", "damage": [20, 21], "range": 4.3, "cooldown": 1.0,
     "abilities": [{"type": "splash", "radius": 1.95, "factor": 0.5}, {"type": "slow", "factor": 0.2, "duration": 5}]}
  ]
}
```
Reichweite/Radien in Towerbreiten (1 = 128 WC3-Einheiten), Abklingzeit in Sekunden. Optional pro Stufe: `range_air`, `model`, `model_scale`.
Fähigkeiten (`scripts/game/abilities.gd`): splash, slow, poison, crit, multishot, bounce, armor_reduce, stun,
air_bonus, gold_on_hit, nova, stacking_damage, wave_damage, speed_aura, damage_aura, burn_aura, slow_aura, armor_aura.
Jede Treffer-Fähigkeit kann `"chance"` haben.

**Tower-Editor:** Tower wählen oder neu anlegen; Art, Modell, Stufen, Fähigkeiten, Rezept und Upgrades bearbeiten.
*Speichern und im Spiel testen* öffnet das Spiel mit diesem Tower als nächstem Gem.

## Gegner

`data/enemies/*.json`: `hp`, `speed` (Towerbreiten/s), `armor`, `armor_type`, `bounty`, `damage` (Leben bei Durchbruch),
`flying`, `boss`, `color`, `size`, optional `shape` und `model`.
Platzhalterformen: Würfel = Boden, Kugel = Flieger, großer Quader = Boss, Pyramide = Massenwelle (`"shape": "pyramid"`).

## Test

```
godot --headless --path . res://tests/smoke_test.tscn
godot --headless --fixed-fps 60 --path . res://tests/balance_test.tscn -- --tier=0 --wave=1
```
Der Balance-Test stellt jeden Gem einzeln an den Laufweg (Ecke und Gerade, ohne Labyrinth) und zählt,
wie viele Gegner der Welle durchkommen. Splitter schaffen Welle 1 ohne Durchbruch (außer Amethyst, der nur Luft trifft).
