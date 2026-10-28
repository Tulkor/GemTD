# eeveTD: Regeln

Nachbau der Warcraft-3-Karte **eeve! TD v1.01** von geX (Überblick über TD Hub in der [README](../README.md)).
Alle Zahlen stehen in `data/eeve.json`, Tower und Gegner in `data/towers/eeve_*.json` und `data/enemies/eeve_*.json`
(erzeugt von `tools/wc3/eeve/eeve_daten.py` aus der Kartendatei).

## Vor dem Start

Im Startfenster wählt man (im Koop der Host):

**Schwierigkeit**

| Stufe | Gegner-Leben | Zusatzrüstung (Stufe 1 → 10) | Zauberschaden | Punkte | Pause |
|---|---|---|---|---|---|
| Anfänger | 35 % | 0 | 100 % | ×0,65 | 30 s |
| Leicht | 55 % | +1 → +5 | 90 % | ×1 | 30 s |
| Mittel | 80 % | +3 → +12 | 80 % | ×1,5 | 20 s |
| Schwer | 100 % | +5 → +22 | 67 % | ×2 | 15 s |
| SICK! | 100 % | +7 → +32 | 50 % | ×3,25 | 15 s |
| IMPOSSIBLE! | 100 % | +12 → +70 | 34 % | ×4,5 | 15 s |

„Zauberschaden“ ist der Anteil, den Fähigkeiten wie Novas noch anrichten. „Pause“ ist die Zeit zwischen zwei Leveln
(vor Level 1 immer 45 s).

**Feld:** *Offenes Feld* (leer), *Felsenfeld* (250 zufällige Felsen) oder *WTF-Feld* (600 Felsen). Felsen versperren nie
den Weg und lassen sich nicht entfernen.

## Ressourcen

- **Leben:** 50, im Koop gemeinsam.
- **Gold:** 200 zum Start. Zu Beginn jedes Levels gibt es 5 % Zinsen auf das vorhandene Gold und
  10 + 4 × Level Gold Einkommen, dazu Kopfgeld für jeden Kill.
- **Food:** begrenzt die Zahl der Tower und Fallen (jeder belegt eins). Start 40, jedes Level kommen 1 oder 2 dazu.
- **Holz:** brauchen die stärksten Tower und alle Fallen. Es gibt 1 Holz alle 7 Level.
- **Elementpunkte:** 1 zum Start, ein weiterer alle 7 Level. Ein Punkt hebt eines der sechs Elemente um eine Stufe.
  Normal geht jedes Element bis Stufe 4. Nach jeder Golem-Challenge (Level 11, 22, 33, 44) steigt ein zufälliges
  Element zusätzlich um eine Stufe, auch über 4 hinaus (höchstens 8).

## Bauen

1. **Barrikade** (2 Gold) auf ein freies Feld setzen. Barrikaden bilden das Labyrinth, der Weg bleibt immer offen.
2. Die Barrikade zu einem **Element-Grundturm** aufwerten (48 Gold, Element auf Stufe 1).
3. Jeder Grundturm verzweigt in vier Linien, die sich Stufe für Stufe weiter aufwerten lassen. Jede Stufe braucht
   das Element auf einer bestimmten Stufe (1 bis 6), die Endstufen kosten zusätzlich Holz.

Ein Tower wird pro Stufe seines Elements um 10 % stärker (Grundschaden). Abreißen gibt kein Gold zurück.

| Element | Stärken | Schwäche |
|---|---|---|
| Natur | Abprall-Angriff, Gift mit Verlangsamung, Tempo-Aura | kein Flächenschaden |
| Erde | Flächenschaden, Betäubung, Gold-Aura | sehr schwach gegen Luft |
| Feuer | großer Flächenschaden, Einzelschaden, Schadens-Aura | keine besonderen Effekte |
| Sturm | Mehrfachschuss, stark gegen Luft, Verlangsamungs-Aura | etwas schwach gegen Boden |
| Magie | sehr guter Einzelschaden, Rüstung senken | kein Flächenschaden, schwer als erstes Element |
| Wasser | leichter Flächenschaden, Verlangsamung, Rüstungs-Aura | wenig Einzelschaden, schwer gegen Bosse |

**Dual-Tower:** Stehen zwei Elemente auf Stufe 3, lässt sich eine Barrikade zum **Dual-Grundturm** aufwerten
(1998 Gold, 1 Holz). Er wird zu einem der 15 Dual-Tower, je einer für jedes Elementpaar, das auf Stufe 3 steht:

| | Natur | Erde | Feuer | Sturm | Magie |
|---|---|---|---|---|---|
| **Erde** | Dornkrautfeld | | | | |
| **Feuer** | Feuerbeerenstrauch | Vulkan | | | |
| **Sturm** | Natürlicher Mahlstrom | Blitz-Felselementar | Roter Blitzgenerator | | |
| **Magie** | Magische Pilze | Runenfels | Arkane Lavahaufen | Arkaner Blitzgenerator | |
| **Wasser** | Säurebrunnen | Gaia-Quelle | Feuerspeiender Schneemann | Strahlende Wolke | Eisiger Zeitkristall |

**Fallen:** Mit einem Element auf Stufe 4 gibt es dessen Falle (900 Gold, 1 Holz), gesetzt über die Seitenleiste.
Fallen sind 3×3 Felder groß und liegen auf dem Weg, Gegner laufen darüber: Giftranken-Falle (Natur),
Erdfessel-Falle (Erde, betäubt), Flammenrost (Feuer, brennende Gegner explodieren beim Tod), Blitzfalle (Sturm),
Kristallfalle (Magie, senkt Rüstung), Bremspfütze (Wasser).

## Level

57 Level. Gegner werden alle 5,5 Level eine Stufe stärker (10 Stufen). Fest sind nur die Challenges, alles andere
wird pro Spiel neu ausgewürfelt (die nächsten Level stehen links im Bild):

- Level 1 Boden, Level 2–3 zu 25 % Flieger.
- Ab Level 4: 20 % Boss, 25 % Flieger, sonst Boden. Boden und Flieger kommen zu 35 % als Masse
  (40 statt 10 Gegner, in Reihen zu viert, mit weniger Leben).
- Ab Level 4 haben Gegner null bis zwei Eigenschaften: *Schnell*, *Zauberimmun*, *Zäh* (15 Schaden weniger pro Treffer)
  oder ab Level 9 *Gepanzert* (+20 Rüstung). Dafür haben sie weniger Leben.
- **Challenges:** Level 11, 22, 33 und 44 je ein Golem (Lehm, Fleisch, Fels, Stahl), 55 eine Massen-Challenge,
  56 eine Luft-Challenge, 57 der Höllengolem. Challenges kosten keine Leben.

Ein durchgelassener Gegner kostet Leben. Ein Boss kostet Level + seine restlichen Leben in Prozent
(Level 20 mit 11 % Rest: 31 Leben). Wer Level 57 übersteht, hat gewonnen.

## Bonusfelder

Auf jedem Feld liegen je 15 Bonusfelder (WTF-Feld 18) jeder Sorte, so groß wie ein Tower. Der Tower muss genau
darauf stehen: **Lava** +40 % Schaden, **Eis** +35 % Angriffstempo, **schwarzer Marmor** doppelte Erfahrung
(Kills zählen doppelt für die Kill-Ränge). Felsen liegen nie auf Bonusfeldern, Fallen bekommen keinen Bonus.

## Wertung

Wie im Original (Werte aus der Kartendatei), alles mal Punktefaktor der Schwierigkeit (0,65 bis 4,5):

- **Punkte je Kill:** jeder Gegner hat einen festen Punktwert (`points` in `data/enemies/eeve_*.json`).
- **Challenge-Punkte:** Anteil des Schadens an der Challenge mal 3000 (Lehmgolem), 5000 (Fleisch), 7000 (Fels),
  9000 (Stahl) oder 20000 (Massen-, Luft-Challenge, Höllengolem; bei der Masse geteilt auf die 40 Gegner).
  Nach jeder Challenge steht in der Seitenleiste, wie viel Prozent Schaden das gebracht hat.
- **Am Ende, nur nach einem Sieg:** 100 je übrigem Leben, 0,5 je übrigem Gold (alle Spieler) und der Feldbonus
  (Felsenfeld 3000, WTF-Feld 5000).

Den Zwischenstand zeigt die Seitenleiste („Wertung“), die Aufschlüsselung der Endbildschirm. Im Koop zählt ein
gemeinsamer Stand. Der Zeitbonus des Speed-Modus fehlt, solange es den Modus nicht gibt.

## Items und Marktplatz

Werte in `data/eeve_items.json` (im Balance-Editor unter eeveTD → Items), wie in der Originalkarte.

- **Marktplatz:** eine Barrikade für 38 Gold zum Marktplatz aufwerten (zusammen 40 Gold und 1 Food), einer je Spieler.
  Anklicken öffnet das Fenster: Holz (900), Erweiterungstrank (650), Läuterungstrank (350), Leere Erfahrungsphiole (140),
  Items verkaufen (halber Wert) und Upgrades für alle eigenen Tower: Schaden +10 %, Reichweite +40, Tempo +8 %,
  je 4 Stufen zu 300/600/900/1.200 Gold und 1 Holz.
- **Lager** (rechts unten, 8 Plätze): Item anklicken, eigenen Tower wählen, „einsetzen“ bzw. „benutzen“.
- **Item-Plätze:** ab Elementstufe 3 einer, je Stufe einer mehr, Dual-Tower 2, Fallen keine; Erweiterungstrank bis 6.
  Eingesetzte Items bleiben im Tower, nur der Läuterungstrank holt sie zurück. Abreißen gibt sie ins Lager.
- **Items:** Klingen (+50 bis +300 Schaden), Ärmel (+10 bis +40 % Tempo), Klauen (Schaden + 15 % Krit), Hämmer
  (Schaden + Betäubung mit Zusatzschaden), Glühende Kette der Macht, Kugeln (Zauberschaden auf zufällige Gegner),
  Erfahrungstrank (+10 Kills). Den Zauberschild des Originals gibt es nicht, weil Gegner keine Tower verzaubern.
- **Drops:** ab Level 11 wird je Level gewürfelt, ob der erste Kill ein Item bringt (Chance und Stufe steigen mit dem
  Level). Golems (Level 11–44) bringen immer ein Verbrauchs-Item und ein Item. Holz zählt sofort, volles Lager verkauft.

## Koop

Bis 4 Spieler. Alle bauen auf einem Feld und teilen die Leben. Jeder hat eigenes Gold, Food, Holz und eigene
Elementpunkte und wertet nur seine eigenen Tower auf. Pro zusätzlichem Spieler haben die Gegner 75 % mehr Leben.
Alternativ spielt in der Lobby jeder sein eigenes Feld (verschiedene Feldnummern).

## Sonstiges

- Umgebung: Wald mit Friedhof und Bergwerk, Laternen an jedem Wegpunkt. eeveTD spielt nachts
  (Glühwürmchen, Nebel über Friedhof und Bergwerk); Tag gibt es über das Debug-Menü („Tageszeit“).
- Debug-Menü: Ressourcen, alle Elemente auf 8, jeden Tower und jede Falle gratis setzen, Level-Sprung, Unsterblich.
