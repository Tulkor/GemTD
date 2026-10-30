# Quellen: data/youtd/

Tower-, Item-, Wellen-Eigenschaften-, Baumeister- und Erfahrungsdaten (`towers.json`, `items.json`, `specials.json`,
`builders.json`, `xp.json`) erzeugt `tools/youtd/youtd_daten.py` aus den CSV-Dateien von **YouTD 2**
(github.com/Praytic/youtd2, Stand Juli 2026). Die Formeln in `scripts/youtd/` (Wellen, Würfeln, Item-Drops,
Punkte, Portalschaden) sind aus dessen Quellcode nachgebaut. `rules.json` ist von Hand geschrieben, die Werte
stammen ebenfalls aus YouTD 2.

Seit Etappe 2 ist außerdem Code aus YouTD 2 übernommen: die Laufzeit in `scripts/youtd/rt/` (Einheiten, Buffs,
Auren, Autocasts, Geschosse, Zauber; angepasst an dieses Spiel) und, umgewandelt von `tools/youtd/faehigkeiten.py`,
die Tower-Skripte in `scripts/youtd/towers/` und die Wellen-Eigenschaften in `scripts/youtd/specials/`.
`texte.json` sind eigene deutsche Texte für die Schlüssel der Übersetzungstabelle, die diese Skripte benutzen.

YouTD 2 steht unter der MIT-Lizenz (Text unten). YouTD 2 baut auf **YouTD** auf, der Warcraft-III-Karte von geX
und der YouTD-Community; Tower- und Item-Namen sowie die Autoren je Tower (Feld `author`) sind von dort übernommen.

Nicht übernommen: Grafiken, Sounds und Texte aus `assets/` von YouTD 2 (eigene Lizenzen, teils unklar).
Modelle im Spiel kommen aus unseren CC0-Paketen (siehe `assets/models/`).

## Lizenz YouTD 2

```
MIT License

Copyright (c) 2023 Icob2Games

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- `beschreibungen.json`: englische Texte zu Fähigkeiten, Auren, Zaubern, Items und Towern aus der Release-Spieldatei von YouTD 2 (MIT, gleiche Quelle wie die Daten), geholt mit `tools/youtd/texte_holen.py`.
