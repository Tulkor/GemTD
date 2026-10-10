# Tower-Werte

Automatisch erzeugt aus `data/towers/*.json` mit `python3 tools/tower_tabelle.py`. Nicht von Hand bearbeiten.

Reichweite in Towerbreiten. **DPS** ist der Schaden pro Sekunde gegen ein einzelnes Ziel ohne Rüstung, mit Crit-Durchschnitt. Mehrfachschuss, Fläche, Gift und Auren sind darin nicht enthalten.

## Grund-Gems

| Gem | Stufe | Schadensart | Schaden | Abklingzeit | DPS | Reichweite | Besonderheiten |
|---|---|---|---:|---:|---:|---:|---|
| Amethyst | Splitter | Durchbohrend | 10–15 | 0,8 | 16 | 7,81 | nur Luft |
|  | Fehlerhaft |  | 20–27 | 1 | 24 | 9,38 | nur Luft |
|  | Normal |  | 30–45 | 1 | 38 | 10,16 | nur Luft |
|  | Makellos |  | 60–80 | 1 | 70 | 10,55 | nur Luft |
|  | Perfekt |  | 140–170 | 1 | 155 | 12,5 | nur Luft |
|  | Groß |  | 350–400 | 1 | 375 | 12,89 | nur Luft; Aura: Gegner-Rüstung −3 (Radius 7,81) |
| Aquamarin | Splitter | Magie | 6–8 | 0,5 | 14 | 2,73 | – |
|  | Fehlerhaft |  | 12–15 | 0,5 | 27 | 2,85 | – |
|  | Normal |  | 24–30 | 0,5 | 54 | 2,97 | – |
|  | Makellos |  | 48–55 | 0,5 | 103 | 3,12 | – |
|  | Perfekt |  | 100–120 | 0,5 | 220 | 4,3 | – |
|  | Groß |  | 280 | 0,5 | 560 | 4,69 | Aura: Tower +10 % Tempo (Radius 11,72) |
| Diamant | Splitter | Normal | 14–17 | 0,8 | 26 | 3,91 | nur Boden; 35 % Crit, 2× Schaden |
|  | Fehlerhaft |  | 16–18 | 1 | 23 | 4,3 | nur Boden; 35 % Crit, 2× Schaden |
|  | Normal |  | 30–37 | 1 | 45 | 4,69 | nur Boden; 35 % Crit, 2× Schaden |
|  | Makellos |  | 58–65 | 1 | 83 | 5,08 | nur Boden; 35 % Crit, 2× Schaden |
|  | Perfekt |  | 140–150 | 1 | 196 | 5,86 | nur Boden; 35 % Crit, 2× Schaden |
|  | Groß |  | 300–350 | 1 | 780 | 6,64 | nur Boden; 35 % Crit, 5× Schaden |
| Smaragd | Splitter | Belagerung | 4–7 | 0,8 | 7 | 3,91 | Gift 2/s für 3 s; verlangsamt 15 % für 3 s |
|  | Fehlerhaft |  | 10–13 | 1 | 12 | 4,3 | Gift 3/s für 4 s; verlangsamt 20 % für 4 s |
|  | Normal |  | 15–25 | 1 | 20 | 4,69 | Gift 5/s für 5 s; verlangsamt 25 % für 5 s |
|  | Makellos |  | 30–37 | 1 | 34 | 5,47 | Gift 8/s für 6 s; verlangsamt 30 % für 6 s |
|  | Perfekt |  | 80–95 | 1 | 88 | 7,03 | Gift 16/s für 8 s; verlangsamt 50 % für 8 s |
|  | Groß |  | 275 | 1 | 275 | 7,03 | Gift 42/s für 15 s; verlangsamt 50 % für 15 s |
| Opal | Splitter | Magie | 9 | 0,8 | 11 | 4,69 | Aura: Tower +10 % Tempo (Radius 4,69) |
|  | Fehlerhaft |  | 10 | 1 | 10 | 5,47 | Aura: Tower +15 % Tempo (Radius 5,47) |
|  | Normal |  | 20 | 1 | 20 | 6,25 | Aura: Tower +20 % Tempo (Radius 6,25) |
|  | Makellos |  | 40 | 1 | 40 | 7,03 | Aura: Tower +25 % Tempo (Radius 7,03) |
|  | Perfekt |  | 85 | 1 | 85 | 7,81 | Aura: Tower +35 % Tempo (Radius 7,81) |
|  | Groß |  | 180 | 1 | 180 | 11,72 | Aura: Tower +50 % Tempo (Radius 11,72) |
| Rubin | Splitter | Held | 9–11 | 1 | 10 | 6,25 | Fläche 50 % im Radius 1,37 |
|  | Fehlerhaft |  | 13–16 | 1 | 14 | 6,25 | Fläche 50 % im Radius 1,37 |
|  | Normal |  | 20–25 | 1 | 22 | 6,25 | Fläche 50 % im Radius 1,76 |
|  | Makellos |  | 38–45 | 1 | 42 | 6,25 | Fläche 50 % im Radius 1,37 |
|  | Perfekt |  | 80–100 | 1 | 90 | 7,03 | Fläche 50 % im Radius 1,72 |
|  | Groß |  | 185 | 0,5 | 370 | 7,03 | 3 Ziele gleichzeitig |
| Saphir | Splitter | Zauber | 8–11 | 0,8 | 12 | 4,3 | verlangsamt 30 % für 5 s |
|  | Fehlerhaft |  | 10–14 | 1 | 12 | 5,86 | verlangsamt 20 % für 5 s |
|  | Normal |  | 16–22 | 1 | 19 | 6,25 | verlangsamt 20 % für 5 s |
|  | Makellos |  | 30–40 | 1 | 35 | 6,64 | verlangsamt 20 % für 5 s |
|  | Perfekt |  | 60–80 | 1 | 70 | 10,94 | verlangsamt 20 % für 5 s |
|  | Groß |  | 200–250 | 1 | 225 | 15,62 | verlangsamt 20 % für 5 s |
| Topas | Splitter | Chaos | 4 | 0,8 | 5 | 3,91 | 3 Ziele gleichzeitig |
|  | Fehlerhaft |  | 8 | 1 | 8 | 3,91 | 4 Ziele gleichzeitig |
|  | Normal |  | 14 | 1 | 14 | 3,91 | 5 Ziele gleichzeitig |
|  | Makellos |  | 25 | 1 | 25 | 3,91 | 6 Ziele gleichzeitig |
|  | Perfekt |  | 75 | 1 | 75 | 4,69 | 9 Ziele gleichzeitig |
|  | Groß |  | 250 | 1 | 250 | 5,47 | 9 Ziele gleichzeitig |

## Kombi-Tower

| Tower | Stufe | Schadensart | Schaden | Abklingzeit | DPS | Reichweite | Besonderheiten | Rezept / Upgrade |
|---|---|---|---:|---:|---:|---:|---|---|
| Blutstein | Blutstein | Held | 115 | 1,5 | 77 | 5,47 | Fläche 50 % im Radius 3,12; Brand-Aura 60/s ohne Rüstung (Radius 3,91) | Rubin Perfekt + Aquamarin Makellos + Amethyst Normal |
|  | Uralter Blutstein |  | 160–240 | 0,8 | 300 | 5,47 | Fläche 50 % im Radius 3,12; Brand-Aura 60/s ohne Rüstung (Radius 3,91); 10 % Crit, 3× Schaden; 10 % Chance: Nova 350 Zauberschaden im Radius 0,78 | Upgrade 300 Gold |
| Dunkler Smaragd | Dunkler Smaragd | Belagerung | 180–300 | 0,8 | 300 | 4,3 | 12,5 % Chance: betäubt 1,5 s | Smaragd Perfekt + Saphir Makellos + Topas Fehlerhaft |
|  | Verzauberter Smaragd |  | 200–400 | 0,7 | 621 | 5,47 | 12,5 % Chance: betäubt 1,5 s; 15 % Crit, 4× Schaden | Upgrade 300 Gold |
| Gelber Saphir | Gelber Saphir | Zauber | 250 | 1 | 250 | 6,25 | Fläche 50 % im Radius 3,12; verlangsamt 20 % für 5 s | Saphir Perfekt + Rubin Makellos + Topas Makellos |
|  | Stern-Gelbsaphir |  | 400 | 0,8 | 500 | 6,64 | Fläche 50 % im Radius 3,12; verlangsamt 20 % für 5 s; Aura: Tower +5 % Schaden (Radius 9,38) | Upgrade 240 Gold |
| Gold | Gold | Durchbohrend | 280–330 | 1 | 412 | 6,25 | 35 % Crit, 2× Schaden; Rüstung −5 für 5 s | Amethyst Perfekt + Amethyst Makellos + Diamant Fehlerhaft |
|  | Ägyptisches Gold |  | 290–360 | 0,75 | 585 | 6,25 | 35 % Crit, 2× Schaden; Rüstung −8 für 5 s | Upgrade 270 Gold |
| Jade | Jade | Magie | 30–35 | 0,5 | 65 | 6,25 | Gift 5/s für 2 s; verlangsamt 50 % für 2 s | Smaragd Normal + Opal Normal + Saphir Fehlerhaft |
|  | China-Jade |  | 50 | 0,5 | 100 | 6,25 | Gift 10/s für 3 s; verlangsamt 50 % für 3 s | Upgrade 60 Gold |
|  | Glücks-China-Jade |  | 55 | 0,35 | 181 | 6,64 | Gift 10/s für 4 s; verlangsamt 50 % für 4 s; 1 % Chance: 0 Gold + 0,5 pro Welle; 1 % Chance: betäubt 2 s; 5 % Crit, 4× Schaden | Upgrade 330 Gold |
| Malachit | Malachit | Belagerung | 6 | 0,5 | 12 | 5,86 | 3 Ziele gleichzeitig | Aquamarin Splitter + Smaragd Splitter + Opal Splitter |
|  | Leuchtender Malachit |  | 11 | 0,5 | 22 | 6,25 | 4 Ziele gleichzeitig | Upgrade 40 Gold |
|  | Mächtiger Malachit |  | 45 | 0,55 | 82 | 6,25 | 99 Ziele gleichzeitig | Upgrade 370 Gold |
| Paraiba-Turmalin | Paraiba-Turmalin | Magie | 10–400 | 0,75 | 273 | 6,64 | Aura: Gegner-Rüstung −4 (Radius 4,69); 20 % Chance: Nova 250 Zauberschaden im Radius 1,95, verlangsamt 20 % | Aquamarin Perfekt + Opal Makellos + Aquamarin Fehlerhaft + Smaragd Fehlerhaft |
|  | Paraiba-Turmalin-Facette |  | 30–420 | 0,75 | 300 | 6,84 | Aura: Gegner-Rüstung −6 (Radius 5,08); 20 % Chance: Nova 350 Zauberschaden im Radius 1,95, verlangsamt 20 % | Upgrade 360 Gold |
| Rosa Diamant | Rosa Diamant | Normal | 150–175 | 0,75 | 433 | 6,25 | nur Boden; 25 % Crit, 5× Schaden | Diamant Perfekt + Diamant Normal + Topas Normal |
|  | Großer Rosa Diamant |  | 175–225 | 0,65 | 846 | 6,64 | nur Boden; 25 % Crit, 8× Schaden | Upgrade 230 Gold |
| Roter Kristall | Roter Kristall | Durchbohrend | 50–75 | 0,8 | 78 | 10,16 | nur Luft; Aura: Gegner-Rüstung −4 (Radius 10,16) | Smaragd Makellos + Rubin Normal + Amethyst Fehlerhaft |
|  | Rote Facette |  | 75–100 | 0,8 | 109 | 10,94 | nur Luft; Aura: Gegner-Rüstung −5 (Radius 10,94) | Upgrade 130 Gold |
|  | Rosenquarz-Kristall |  | 100–125 | 0,8 | 141 | 11,72 | nur Luft; Aura: Gegner-Rüstung −6 (Radius 11,72); Brand-Aura 50/s ohne Rüstung (Radius 11,72) | Upgrade 200 Gold |
| Schwarzer Opal | Schwarzer Opal | Magie | 25 | 1 | 25 | 6,25 | Aura: Tower +30 % Schaden (Radius 7,81) | Opal Perfekt + Diamant Makellos + Aquamarin Normal |
|  | Mystischer Schwarzer Opal |  | 50 | 1 | 50 | 7,81 | Aura: Tower +40 % Schaden (Radius 9,38) | Upgrade 360 Gold |
| Silber | Silber | Zauber | 20–21 | 1 | 20 | 4,3 | Fläche 50 % im Radius 1,95; verlangsamt 20 % für 5 s | Diamant Splitter + Saphir Splitter + Topas Splitter |
|  | Sterlingsilber |  | 40 | 1 | 40 | 5,08 | Fläche 50 % im Radius 1,95; verlangsamt 20 % für 5 s | Upgrade 40 Gold |
|  | Silberritter |  | 150 | 1 | 150 | 5,86 | Fläche 50 % im Radius 1,95; verlangsamt 20 % für 5 s | Upgrade 380 Gold |
| Stein von Bryvx |  | Belagerung | 500 | 0,8 | 625 | 6,64 | Aura: Tower +50 % Schaden (Radius 11,72) | aus Überlauf |
| Sternrubin | Sternrubin | Held | – | – | – | – | Brand-Aura 40/s ohne Rüstung (Radius 2,07) | Rubin Fehlerhaft + Amethyst Splitter + Rubin Splitter |
|  | Blutstern |  | – | – | – | – | Brand-Aura 50/s ohne Rüstung (Radius 3,91) | Upgrade 40 Gold |
|  | Feuerstern |  | 130 | 0,5 | 260 | 4,69 | 99 Ziele gleichzeitig | Upgrade 380 Gold |
| Uran 238 | Uran 238 | Magie | – | – | – | – | Brand-Aura 80/s ohne Rüstung (Radius 3,91); Aura: Gegner −50 % Tempo (Radius 3,91) | Topas Perfekt + Saphir Normal + Opal Fehlerhaft |
|  | Uran 235 |  | 14 | 0,2 | 70 | 7,03 | 99 Ziele gleichzeitig; Brand-Aura 80/s ohne Rüstung (Radius 3,91); Aura: Gegner −50 % Tempo (Radius 3,91) | Upgrade 250 Gold |

## Fallen (Platten)

| Tower | Stufe | Schadensart | Schaden | Abklingzeit | DPS | Reichweite | Besonderheiten | Rezept / Upgrade |
|---|---|---|---:|---:|---:|---:|---|---|
| Geisterplatte |  | Held | 200 | 0,3 | 667 | 1,02 | nur Boden; Aura: Tower +10 % Tempo (Radius 7,81); +35 Schaden pro Treffer am selben Ziel (5 s) | Opalader-Platte + Verlangsamungsplatte |
| Giftplatte |  | Belagerung | 1 | 1 | 1 | 1,02 | Gift 10/s für 20 s; verlangsamt 25 % für 20 s | Smaragd Normal + Topas Fehlerhaft oder Opal Fehlerhaft oder Aquamarin Fehlerhaft (gleiche Runde) |
| Halteplatte |  | Chaos | 160 | 2 | 80 | 1,02 | nur Boden; betäubt 1,5 s | Topas Normal + Amethyst Fehlerhaft oder Saphir Fehlerhaft (gleiche Runde) |
| Luftplatte |  | Durchbohrend | 40 | 0,5 | 80 | 1,02 | Fläche 100 % im Radius 0,78; Reichweite Luft 6,64 | Amethyst Normal + Smaragd Fehlerhaft oder Opal Fehlerhaft oder Rubin Fehlerhaft (gleiche Runde) |
| Opalader-Platte |  | Magie | 80 | 0,5 | 160 | 1,02 | nur Boden; Aura: Tower +10 % Tempo (Radius 5,47) | Opal Normal + Topas Fehlerhaft oder Rubin Fehlerhaft (gleiche Runde) |
| Reichweitenplatte |  | Held | 15 | 0,5 | 30 | 4,69 | 99 Ziele gleichzeitig | Rubin Normal + Topas Fehlerhaft oder Amethyst Fehlerhaft oder Rubin Fehlerhaft (gleiche Runde) |
| Schadensplatte |  | Durchbohrend | – | – | – | 1,02 | nur Boden; +20 Schaden pro Welle; Aura: Tower +10 % Schaden (Radius 1,95) | Diamant Normal + Saphir Fehlerhaft oder Opal Fehlerhaft (gleiche Runde) |
| Uralte Platte |  | Durchbohrend | 50 | 2,5 | 20 | 1,02 | betäubt 1 s; Rüstung −12 für 2,5 s; +20 Schaden pro Welle | Halteplatte + Luftplatte |
| Verlangsamungsplatte |  | Durchbohrend | 100 | 0,5 | 200 | 1,02 | nur Boden; verlangsamt 15 % für 3600 s | Saphir Normal + Diamant Fehlerhaft oder Smaragd Fehlerhaft oder Aquamarin Fehlerhaft (gleiche Runde) |
| Viperplatte |  | Held | 30 | 0,5 | 60 | 5,86 | 99 Ziele gleichzeitig; Brand-Aura 50/s ohne Rüstung (Radius 3,12); Aura: Tower +10 % Schaden (Radius 3,12) | Schadensplatte + Reichweitenplatte |
| Zauberplatte |  | Magie | 30–40 | 0,5 | 70 | 0,86 | 5 % Chance: Nova 100 Zauberschaden im Radius 1,95, verlangsamt 20 %; 5 % Chance: Nova 80 Zauberschaden im Radius 2,34; 5 % Chance: Nova 85 Zauberschaden im Radius 0,78; 5 % Chance: Nova 125 Zauberschaden im Radius 2,34; 5 % Chance: Rüstung −5 für 15 s; 5 % Chance: 3 Gold | Aquamarin Normal + Diamant Fehlerhaft oder Amethyst Fehlerhaft (gleiche Runde) |
| Ältestenplatte |  | Zauber | 100 | 0,33 | 303 | 0,9 | 5 % Chance: Nova 300 Zauberschaden im Radius 1,95, verlangsamt 20 %; 5 % Chance: Nova 150 Zauberschaden im Radius 1,95; 5 % Chance: Nova 150 Zauberschaden im Radius 2,34; 7 % Chance: Rüstung −7 für 25 s; 5 % Chance: Nova 200 Zauberschaden im Radius 2,34; 5 % Chance: 5 Gold; 5 % Chance: Nova 200 Zauberschaden im Radius 1,17; 8 % Chance: Gift 20/s für 2 s | Zauberplatte + Giftplatte |

## Schadensart gegen Rüstungsart

Faktor auf den Schaden, aus `data/balance.json`. Dazu kommt die Rüstung selbst: jeder Punkt senkt den Schaden um etwa 6 %, abnehmend (Rüstung 12 ≈ −42 %, Rüstung 35 ≈ −68 %).

| Schadensart | Ungepanzert | Leicht | Mittel | Schwer | Befestigt | Normal | Held | Göttlich |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Durchbohrend | 1,75 | 0,8 | 0,8 | 0,8 | 0,8 | 0,8 | 0,8 | 0,75 |
| Magie | 1 | 1 | 1,9 | 0,8 | 0,7 | 1 | 0,4 | 0,75 |
| Normal | 0,2 | 1,2 | 1 | 1,6 | 1 | 0,6 | 1 | 0,75 |
| Belagerung | 1,5 | 0,7 | 0,7 | 0,7 | 1,7 | 0,7 | 0,7 | 0,75 |
| Held | 0,8 | 1,8 | 0,8 | 1 | 0,5 | 1 | 1 | 0,75 |
| Zauber | 1 | 1 | 1 | 1 | 1 | 1 | 1,75 | 0,75 |
| Chaos | 1,2 | 0,5 | 1 | 0,6 | 0,7 | 1,6 | 1 | 0,75 |
