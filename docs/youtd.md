# YouTD: Designdokument

Fünfter Modus in TD Hub: Nachbau von **YouTD** (Warcraft-3-Karte von geX und der YouTD-Community) nach dem Vorbild
des Open-Source-Nachfolgers **YouTD 2** (Godot, github.com/Praytic/youtd2, ausgewertet: Stand `main` vom 4. Juli 2026,
Commit `d7532f3`, letzte Version v0.19.0).

Kurz: Tower **ohne Mazing** neben einem **festen Weg**, Tower werden **gewürfelt** (oder gekauft) und über
**Elemente** freigeschaltet, sammeln **Erfahrung**, tragen **Items** in vier **Seltenheiten**; der Spieler sammelt
**sessionübergreifend XP** und schaltet damit Baumeister und Weisheits-Boni frei. Optik und Oberfläche: **Druidenhain**
wie eeveTD.

## Lizenz: was wir übernehmen dürfen

| Teil von YouTD 2 | Lizenz | Bei uns |
|---|---|---|
| Quellcode (`src/`, GDScript) | MIT (Copyright 2023 Icob2Games) | Formeln und Abläufe nachbauen bzw. portieren, Hinweis + MIT-Text in `data/youtd/QUELLEN.md` |
| Daten (`data/*.csv`: Tower, Items, Wellen-Specials, XP-Tabellen) | im Repo ohne eigene Lizenz, gehört zum MIT-Teil | als Werte nach `data/youtd/*.json` umwandeln (Skript `tools/youtd/youtd_daten.py`) |
| Assets (`assets/`: Grafik, Sounds, Icons, Schriften) | CC-BY-NC 4.0 | **nicht** übernehmen (NC verbietet Verkauf, siehe Lizenzregel) |
| Texte (`texts.csv`, Beschreibungen) | nicht im Repo (liegt bei den Entwicklern auf Google Drive) | Beschreibungen schreiben wir selbst auf Deutsch + en.json |

Tower- und Itemnamen sind Eigennamen aus dem Original (z. B. „Tiny Shrub“) und bleiben englisch, wie im Original.
Optik kommt aus unseren CC0-Paketen (Stylized Nature MegaKit, Quaternius-Monster, Kenney/Brackeys-Effekte).

## Spielablauf

1. **Startfenster** (Druidenhain): Spielmodus, Länge, Schwierigkeit, Baumeister, Weisheits-Boni.
   - Spielmodus: **Zufall mit Aufwertungen** (Standard), **Bauen** (frei kaufen), **Komplett zufällig**.
   - Länge: Probe 80, Voll 120, Endlos 240 Wellen (danach Bonuswellen mit steilem HP-Anstieg).
   - Schwierigkeit: Anfänger, Leicht, Mittel, Schwer, Extrem.
2. **Vorbereitung** 180 s, dann kommt alle **15 s** automatisch die nächste Welle (Knopf „Nächste Welle jetzt“).
   Wellen laufen also überlappend, es gibt keine Bauphase wie in GemTD.
3. Gegner laufen einen **festen Weg** zum Portal. Tower stehen auf Bauflächen neben dem Weg und blockieren nie.
4. Das Portal hat **100 % Leben**. Ein durchgelaufener Gegner kostet `2,5 % × Größenfaktor` (Masse 1, Normal 2,
   Luft/Champion 4, Boss 20), weniger je mehr Schaden er schon genommen hat (`× (1 − Schadensanteil^5)`, Boss `^4`).
   Challenges kosten nichts, der Endboss alles. Bei 0 % ist das Spiel verloren, nach der letzten Welle gewonnen.
5. Am Ende: Punkte → **Spieler-XP** (× 0,002), wird im Profil gespeichert.

## Wellen (1:1 aus YouTD 2)

Wellen sind nicht fest gespeichert, sondern werden pro Spiel mit festem Seed **gewürfelt**, genau wie im Original:

- **Größe**: Masse 15 %, Normal 50 %, Luft 15 %, Boss 20 %. Jede **8.** Welle ist eine **Challenge** (Challenge-Boss,
  jede 16. Challenge-Masse), Rüstung Zod.
- **Rasse**: Untot, Magisch, Natur, Ork, Humanoid (für Fähigkeiten mit Bonus gegen Rassen).
- **Anzahl**: Kapazität `20 + Welle/40`, Gewicht Masse 1, Normal 2, Luft/Champion 4, Boss 20; **Champions**
  (Normal: 0–3, Masse: 0–1) werden gleichmäßig eingestreut.
- **Leben**: Polynom 6. Grades je Schwierigkeit (`a + j(b + j(c + …))`, j = Welle − 1) × `(0,9 − 0,002·Welle)`,
  × Größenfaktor (Masse 0,3, Normal/Luft 1, Champion 1,75, Boss 6, Challenge 1,6/12). Sif-Rüstung × 0,48.
- **Rüstung**: `floor(a + j(b + j·c))` je Schwierigkeit.
- **Rüstungstyp**: Hel, Myt, Lua, Sol zufällig, ab Welle 32 zu 15 % Sif.
- **Specials** (ab Welle 8): 41 Eigenschaften mit Mindestwelle, Häufigkeit und Gruppen, die sich ausschließen,
  z. B. Speed, Unsichtbar, Rüstung, Ausweichen, Magieimmun, Regeneration, Zweite Chance, Flock (doppelte Anzahl),
  Manaschild, Nekromant, Mechanisch. Jedes Special senkt bzw. erhöht die HP (Spalte `hp modifier`).

## Schaden: Angriffs- und Rüstungstypen

| Angriff \ Rüstung | Lua | Sol | Hel | Myt | Sif | Zod |
|---|---|---|---|---|---|---|
| Physisch | 180 % | 120 % | 90 % | 60 % | 40 % | 100 % |
| Verfall | 60 % | 180 % | 120 % | 90 % | 40 % | 100 % |
| Energie | 90 % | 60 % | 180 % | 120 % | 40 % | 100 % |
| Essenz | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % |
| Elementar | 120 % | 90 % | 60 % | 180 % | 40 % | 100 % |
| Arkan | 150 % | 150 % | 150 % | 150 % | 40 % | 100 % (kein Schaden an Immunen) |

Dazu Rüstungswert wie in WC3, kritische Treffer (Grundchance 1,25 %, ×1,25), Zauberschaden 90 % (gegen Sif 40 %).

## Elemente und Wissensbücher

- 7 Elemente: **Eis, Natur, Feuer, Astral, Dunkelheit, Eisen, Sturm**.
- **Wissensbücher (Tomes)**: Start 90, +8 je Welle. Forschen kostet `20 + aktuelle Stufe` Bücher, maximal Stufe 15.
- Elementstufe schaltet teurere Tower frei (Kosten 140 → Stufe 1 … 3500 → Stufe 15) und erhöht die Würfelchance
  für dieses Element und für seltenere Tower.

## Tower

- **690 Tower** in **235 Familien** (Stufen 1–7 einer Familie = Aufwertungen), je Element 89–110.
- **Seltenheit**: Gewöhnlich (grün), Ungewöhnlich (blau), Selten (lila), Einzigartig (gold). Bestimmt **Food**
  (2/3/4/6; Start-Food 55, max 300) und im Baumodus zusätzliche Wissensbuch-Kosten (0/4/10/25).
- Werte aus der Tabelle: Angriffstyp, Reichweite, Abklingzeit, Schaden min–max, Mana, Kosten, Geschossgeschwindigkeit,
  Multishot, Splash, Abpraller, Ziel (Boden/Luft) und **Spezialwerte** (z. B. Krit-Chance je Level).
- **Fähigkeiten**: 566 Tower haben ein eigenes Skript (214 Skripte, oft eines je Familie), seit Etappe 2 alle
  portiert: Auslöser bei Angriff, Treffer und Kill, Auren, Autocasts (automatisch oder von Hand über die Auswahlkarte),
  Geschosse, Ketten- und Gabelblitze, Buffs auf Gegnern und Towern. Rechnen tut die YouTD-2-Laufzeit (siehe Technik).
- **Würfeln** (Zufallsmodi): 6 Start-Tower, danach je Welle neue Tower ins Lager, Chance je Element nach Elementstufe,
  Seltenheit nach Elementstufe und Kostenobergrenze. Im Modus „Zufall mit Aufwertungen“ lässt sich ein Tower gegen
  Gold zur nächsten Stufe seiner Familie aufwerten.
- **Verkaufen**: 50 % (Bauen) bzw. 75 % (Zufallsmodi).
- **Tower-XP**: Kills geben Erfahrung (Masse 1, Normal 2, Luft/Champion 4, Boss 20). Level 0–25 (mit Bonus bis 30),
  Tabelle `exp_for_level`. Je Level +4 % Grundschaden, +1 % Angriffstempo, +0,15 % Krit-Chance, +2 % Krit-Schaden.

## Items

- **315 Items**: 283 normale, 24 Öle (dauerhafte Verbesserung, werden verbraucht), 8 Verbrauchsgegenstände.
- Seltenheit wie bei Towern; Drop beim Kill (Grundchance 4,75 %, mehr Würfe bei größeren Gegnern, Boss 20),
  Stufe nach Gegnerwelle („required wave level“).
- Jeder Tower hat **Item-Plätze** (1–6, nach Kosten und Seltenheit). Items liegen sonst im Lager.
- 180 Items wirken nur über Werte (z. B. „+25 % Schaden“) und kommen sofort, 135 haben eigene Skripte (Etappe 3).
- **Horadrischer Würfel**: 8 Rezepte (z. B. 2 Verbrauchsgegenstände → 1 neuer, 5 gleiche Items → 1 seltener). Etappe 3.

## Spieler-XP und Level (sessionübergreifend)

- Jeder getötete (und anteilig jeder durchgelaufene) Gegner gibt **Punkte**: Größenfaktor × Schwierigkeit (1–5) ×
  Modus (Bauen 0,9, Zufall 1, Komplett zufällig 1,35) × Länge (Endlos 0,9).
- **Spieler-XP = Punkte × 0,002**, Level 0–300 nach Tabelle `player_exp_for_level` (Level 20 bei 411 XP, Level 60 bei
  2431 XP). Gespeichert im Spielerprofil unter `modes.youtd.progress` (wie Maul-XP), im Profilfenster sichtbar.
- **Baumeister** (Builder) werden mit dem Level freigeschaltet: 5 Anfänger (Level 0), 6 Fortgeschrittene (Level 5),
  8 Spezialisten (Level 10), 2 Hardcore (Level 20). Jeder verändert die Regeln (z. B. mehr Gold, mehr Items).
- **Weisheits-Boni**: alle 6 Level ein Punkt (bis 24 Boni), vor dem Spiel frei verteilbar: z. B. +8 % Grundschaden,
  +7 % Angriffstempo, +40 Bücher, +16 Food, +20 % Leben, +25 Reichweite, +2 maximale Elementstufe, +2 maximales
  Tower-Level.

## Etappen

| Etappe | Inhalt |
|---|---|
| **1** | Modus im Hub, Karte mit festem Weg, Startfenster, Wellen-Generator 1:1 inkl. Rüstungstypen, HP-Formel, Champions, Challenges und Specials (die mit reinen Werten: Speed, Rüstung, Ausweichen, Regeneration, Strong, Flock, Unsichtbar), alle 690 Tower mit Grundwerten, Elemente + Bücher, drei Spielmodi mit Würfeln, Food, Tower-XP, Spieler-XP + Level + Weisheits-Boni im Profil, Items mit reinen Werten + Öle, Druidenhain-Optik |
| | Noch nicht in Etappe 1: Spielstände (Speichern/Laden), Verbrauchsgegenstände (fallen noch nicht), Wellen-Eigenschaften ohne eigene Wirkung zählen nur mit ihrem Lebens-Faktor, Tower mit Skript schießen nur normal |
| **2** | Alle 214 Tower-Skripte und alle 41 Wellen-Eigenschaften (Brut, Nekromant, Trächtig, Sprint usw.) aus YouTD 2 portiert, YouTD-2-Laufzeit für Werte, Buffs, Auren, Autocasts, Geschosse und Effekte; Zauber von Hand auf der Auswahlkarte; Test für alle 690 Tower |
| | Noch offen nach Etappe 2: Spielstände (Speichern/Laden), Texte der Buff-Tooltips (im Original-Repo nicht enthalten), Effekte nur angenähert (Treffer-Effekte und Leuchtringe statt der YouTD-Grafiken) |
| 3 | Item-Skripte, Horadrischer Würfel, Baumeister mit Sonderregeln, Koop |

## Technik

- `data/modes.json`: Eintrag `youtd` mit eigener Szene `scenes/youtd_game.tscn`.
- `tools/youtd/youtd_daten.py` erzeugt aus den CSV-Dateien `data/youtd/towers.json`, `items.json`, `specials.json`,
  `xp.json`; Regeln von Hand in `data/youtd/rules.json`.
- `scripts/youtd/`: `youtd_game.gd` (erweitert game.gd wie eeveTD, Befehle `setup`, `research`, `roll`, `build`,
  `item_put`, `next_wave`, `option`), `youtd_waves.gd` (Wellen-Generator), `youtd_roll.gd` (Tower würfeln, Item-Drops),
  `youtd_tower.gd`, `youtd_enemy.gd`, `youtd_data.gd` (Daten laden), `youtd_progress.gd` (Spieler-XP, Level, Weisheit im
  Profil unter `modes.youtd.progress`), `youtd_panel.gd` (Seitenleiste), `youtd_setup_panel.gd` (Startfenster).
- **Laufzeit aus YouTD 2** in `scripts/youtd/rt/` (Klassen mit Präfix `Yt`, umbenannt von `tools/youtd/umbenennen.py`):
  Jeder Tower und Gegner bekommt einen Kern (`YtTower`/`YtCreep`, Kind des Körpers `YoutdTower`/`YoutdEnemy`, Verweis
  `core.body`). Der Kern rechnet Werte, Leben, Angriffe, Buffs, Auren und Autocasts; der Körper zeigt Modell und Weg und
  liefert die Position (`get_position_wc3` = `body.pos × 128`). `YtWorld` (Kind des Bretts) treibt Timer, Einheiten,
  Geschosse (`YtProjectileView`, MultiMesh) und Effekte (`YtEffect` wählt FxPlayer-Treffer nach Schlüsselwort, Dauer-
  effekte als Leuchtring). Items gehen als ein Modifikator an den Kern (`core.set_item_mods`).
- `tools/youtd/faehigkeiten.py` wandelt die Tower-Skripte nach `scripts/youtd/towers/` und die Wellen-Eigenschaften nach
  `scripts/youtd/specials/` um (Feld `script` in towers.json/specials.json), mit kleinen Anpassungen je Datei (`PATCHES`,
  `SPAWN_RULES`). Texte der YouTD-2-Übersetzungstabelle stehen deutsch in `data/youtd/texte.json` (`YtUtils.text`).
- Karte `data/maps/youtd.json` (`game: "youtd"`), Weg fest über Wegpunkte, Bauflächen daneben.
- Tests `tools/run_tests.sh youtd ytfaehig` (ytfaehig: alle 690 Tower am Weg, Schaden, Zauber von Hand, alle
  Wellen-Eigenschaften, Aufwerten; etwa 2 Minuten), Bild `tools/screenshot.sh --map=youtd [--auswahl] [--einstellungen]`
  (unter Xvfb langsam, etwa 3 Minuten).
- Quellen und MIT-Lizenz: `data/youtd/QUELLEN.md`.
