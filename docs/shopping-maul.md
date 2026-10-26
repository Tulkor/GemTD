# Shopping Maul: Regeln

Nachbau der Warcraft-3-Karte **Shopping Maul 5.44f** (Überblick über TD Hub in der [README](../README.md)).
Regeln stehen in `data/maul/rules.json` und `data/maul/pro.json` (von Hand gepflegt), Karte, Filialen und Level in
`data/maul/map.json`, `shops.json` und `waves.json` (erzeugt von `tools/wc3/maul_daten.py` aus der Kartendatei).

## Ziel

Jeder Spieler hat ein eigenes Gebiet auf der Karte. Die Gegner laufen nacheinander durch die Gebiete aller Spieler
ins gemeinsame Ziel. Wer 40 Level übersteht, besiegt die Gewerbeaufsicht; danach kommen noch 10 Bonuslevel.
Shopping Maul läuft solo oder als Koop mit bis zu 8 Spielern, die Leben sind gemeinsam.

## Vor dem Start

Im Startfenster wählt man die Filiale, die Schwierigkeit und die Spielart:

| Schwierigkeit | Leben | Gegner-Leben | XP |
|---|---|---|---|
| Einfach | 250 | ×0,9 | ×0,66 |
| Normal | 150 | ×1 | ×1 |
| Schwer | 75 | ×1,1 | ×1,75 |
| Sehr schwer | 25 | ×1,25 | ×2,5 |

*Standard (Gruppe)* schickt die Gegner in Gruppen, *Standard (Linie)* einzeln hintereinander (höchstens 120 gleichzeitig).
Die Filiale lässt sich auch zufällig wählen.

## Ablauf

- Vor Level 1 bleiben 90 Sekunden zum Bauen (ab 4 Spielern 65), zwischen den Leveln 18 Sekunden, nach Level 40
  70 Sekunden. Der Host kann mit „Jetzt starten“ früher beginnen.
- 50 Level: 40 Boden-, 5 Flug- und 5 Bosslevel (10, 20, 30, 40, 50). Viele Level haben Besonderheiten:
  *Unsichtbar* (nur mit Enttarnung angreifbar), *Schnell*, *Zauberresistent*, *Geist* (wenig Rüstung) und
  *Frost* (Tower in der Nähe eines Gegners greifen 33 % langsamer an).
- Die Stärke passt sich an: Läuft kaum etwas durch, werden die nächsten Level schwerer, bei vielen Durchbrüchen leichter.
  Weniger Spieler machen die Gegner etwas stärker pro Kopf.
- Gegner, die durch ein leeres Gebiet ohne Tower laufen, sind dort dreimal so schnell. An Abzweigungen laufen sie in
  das bebaute Gebiet, sonst abwechselnd links und rechts.

**Leben:** Alle Gegner eines Levels zusammen kosten höchstens 600 Leben, einer höchstens 25. Ein Boss kostet 15,
der Boss in Level 40 kostet 30. Ein Level ganz ohne Durchbruch bringt 5 Leben zurück.

**Gold:** 500 Startgold, aufgeteilt auf alle Spieler (Spieler 1 bekommt 45 extra). Nach jedem Level gibt es Einkommen,
das von Level zu Level wächst (nach den Bossen in Level 10, 20 und 30 einmalig mehr) und auf alle Spieler verteilt wird,
dazu Kopfgeld für jeden eigenen Kill.

## Bauen

- Tower gibt es nur aus der eigenen Filiale und nur im eigenen Gebiet. Wege dürfen nicht versperrt werden,
  solange ein Boss lebt, wird nicht gebaut.
- Höchstens 80 Tower pro Spieler (TUI Reisebüro und Waffenladen: 6).
- Tower lassen sich aufwerten; Verkaufen gibt 75 % des Werts zurück.
- **Bonus-Upgrade** (5 Stufen): je nach Filiale +5 % Schaden für alle Tower oder 5 % Rabatt auf jeden Kauf pro Stufe.
- **Enttarnung:** Media Markt, Aldi und Mc Donalds sehen unsichtbare Gegner immer. Alle anderen haben „Aufdecken“
  (30 Sekunden, alle 60 Sekunden), dazu enttarnen manche Tower in ihrer Reichweite.

## Filialen

| Filiale | Reichweite / Schaden / Tempo | Besonderheit |
|---|---|---|
| Media Markt | normal / normal / normal | enttarnt immer, gut gegen große Gruppen; Rabatt statt Schadensbonus |
| H&M | hoch / niedrig / sehr hoch | kritische Treffer und Betäubung |
| Obi Baumarkt | sehr niedrig / sehr hoch / hoch | verliert jede Runde 1 % des Towerwerts |
| Mc Donalds | extrem hoch / sehr niedrig / hoch | enttarnt immer, verlangsamt |
| Aldi | hoch / hoch / sehr niedrig | enttarnt immer, viel Flächenschaden |
| Tante Emma Laden | normal / anfangs niedrig / hoch | viele Tower vergiften |
| Porsche Autohaus | hoch / hoch / hoch | teure Tower, Frost, Verlangsamungs-Aura |
| Deutsche Bank | normal / normal / hoch | greift nur Bodengegner an |
| Aral Tankstelle | niedrig–normal / normal / hoch | ein Grundtower mit langer Upgradekette, oft Betäubung |
| Beate Uhse Sexshop | normal / hoch / niedrig | schnell gebaut, Flächenzauber; Rabatt statt Schadensbonus |
| CinemaxX | mäßig / mäßig / sehr hoch | drei Tower gegen Luft |

### Konto, Deutsche Bank und Stammkundin

Im Hauptgebäude (Reiter „Zentrale“) hat jeder Spieler ein **Konto** wie im Original (dort die Chatbefehle `-da`, `-wa`, `-ad`):
Einzahlen, am Levelende 4 % Zinsen (höchstens auf 5.000 Gold), Abheben dauert 25 s. Drei **Bank-Upgrades**
(75/150/225 Gold) bringen je +2 % Zinsen und 5 s schnelleres Abheben. „Am Levelende alles einzahlen“ legt das Gold
vor den Zinsen aufs Konto.

- **Deutsche Bank:** kein eigenes Konto, bekommt am Levelende 5 % der Summe aller Konten (fest 750 Gold ab 15.000).
- **Tante Emma Laden:** das Altenheim (50 Gold) wirbt eine Stammkundin an, die alle 10 s 10 Gold aus dem Laden holt,
  bis 15.000 Gold geholt sind. Im Original läuft sie zwischen Laden und Altenheim hin und her, die Dauer eines Gangs
  ist geschätzt (`data/maul/pro.json`, `stammkundin.trip`).

Logik in `scripts/maul/maul_bank.gd`, Werte unter `bank` und `stammkundin` in `data/maul/pro.json`.

## Erfahrung und Profi-Filialen

Nach jedem Level gibt es Erfahrungspunkte (mehr bei höherer Schwierigkeit und mehr Spielern). Sie werden auf dem
Rechner im Spielerprofil gespeichert (`user://profile/profile.json`, `modes.maul.progress`) und bleiben zwischen den Partien erhalten, auch solo.

- Ab **25 XP** sind die Profi-Filialen wählbar.
- Ab 10 XP und weiteren Schwellen (bis 800 XP) werden **XPert-Tower** frei, die jede Filiale bauen kann:
  höchstens ein XP-Tower und ein Ultimate-Tower (ab Level 21) gleichzeitig.

| Profi-Filiale | Besonderheit |
|---|---|
| Post | Tower mit Waffen-Slots, Waffen lassen sich während des Levels zwischen Towern tauschen |
| Copyshop | ein Kopierer, der sich in jeden Tower jeder Filiale verwandelt (etwa 5 % teurer) |
| TUI Reisebüro | höchstens 6 Tower, Schaden und Reichweite getrennt erforschbar |
| AOK | Angriffe springen über, 10 % Chance auf Leben pro Kill, Gold bei Lebensverlust, +33 % Schaden bei vollen Leben |
| IKEA | Show Houses mit Möbel-Slots, zwei passende Teile ergeben ein besseres |
| Gärtnerei | billige Pflanzen, die Wasser aus Bewässerungsanlagen brauchen |
| Fitness-Studio | Tower brauchen jede Runde bezahlte Anabolika, werden dafür stärker, Doping möglich |
| Bestattungsinstitut | Friedhöfe erwecken bewegliche Zombies, Kultstätten heilen sie |
| Waffenladen | bis zu 5 mobile Kampfdrohnen mit Modulen, die am Drone Charger aufladen; höchstens 6 Tower |

## Koop

Shopping Maul startet aus der Lobby immer als Koop: jeder Spieler bekommt ein Gebiet, der Host rechnet.
Jeder sieht nur die Wege durch das eigene Gebiet, „Alle Wege zeigen“ blendet die übrigen ein.
Das Spieltempo bestimmt der Host.

## Sonstiges

- Spielfeld im Art-déco-Stil mit Blockstadt rund um die Gebiete, dazu eine Minikarte.
- Debug-Menü (im Koop nur der Host): Gold, Leben, XP ohne Speichern, Filiale wechseln (auch Profi), freies Bauen,
  Level-Sprung.
