"""Erzeugt die YouTD-Karte data/maps/youtd.json: fester Weg in Schlangenlinien, Bauflächen daneben.

    python3 -I tools/youtd/youtd_map.py

74×74 Felder (ein Feld = eine halbe Towerbreite). Der Weg ist 3 Felder breit ("_", begehbar, nicht bebaubar),
alles andere ist Baufläche ("."). Gegner laufen in YouTD nur auf dem Weg: youtd_game.gd sperrt die Bauflächen
für die Wegsuche, Tower versperren deshalb nie etwas (kein Mazing).
Der Weg läuft in vier Bahnen von links oben nach links unten, die Wegpunkte liegen in den Kurven.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
W = H = 74
ROAD = 3          # Breite des Wegs in Feldern
ROWS = [8, 26, 44, 62]   # obere Kante jeder Bahn
LEFT, RIGHT = 6, 65       # linke Kante der Kurven links und rechts

grid = [["." for _ in range(W)] for _ in range(H)]
for x in range(W):
    grid[0][x] = grid[H - 1][x] = "#"
for y in range(H):
    grid[y][0] = grid[y][W - 1] = "#"


def road(x0, y0, x1, y1):
    for y in range(min(y0, y1), max(y0, y1) + ROAD):
        for x in range(min(x0, x1), max(x0, x1) + ROAD):
            grid[y][x] = "_"


mid = ROAD // 2
points = []
x_start = 1
for i, y in enumerate(ROWS):
    going_right = i % 2 == 0
    a, b = (LEFT, RIGHT) if going_right else (RIGHT, LEFT)
    if i == 0:
        road(x_start, y, b, y)
    else:
        road(a, ROWS[i - 1], a, y)
        road(a, y, b, y)
        points.append([a + mid, y + mid])
    if i < len(ROWS) - 1:
        points.append([b + mid, y + mid])
# letzte Bahn (nach links) läuft bis zum linken Rand
road(1, ROWS[-1], LEFT, ROWS[-1])
spawn = [x_start + mid, ROWS[0] + mid]
goal = [1 + mid, ROWS[-1] + mid]

data = {
    "format": 2,
    "id": "youtd",
    "name": "YouTD",
    "game": "youtd",
    "width": W,
    "height": H,
    "tiles": ["".join(r) for r in grid],
    "spawn": spawn,
    "goal": goal,
    "checkpoints": points,
    "marker_radius": 1,
    "waves": "classic",
    "lives": 100,
    "start_gold": 70,
    "variance": {"random_rocks": 0, "seed": -1},
}
path = ROOT / "data" / "maps" / "youtd.json"
path.write_text(json.dumps(data, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")
print(path.relative_to(ROOT), "Wegpunkte:", points)
