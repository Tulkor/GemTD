# Maze-Rechner

Sucht mit Simulated Annealing eine Anordnung von N Steinen (2×2), die den Weg möglichst lang macht,
optional mit Gewicht auf einen Kreis, durch den die Gegner oft laufen sollen (Cluster für Tower).
Ursprünglich aus dem Balance-Thread (Maze 1 „Weglänge“ und Maze 2 „Cluster“, siehe /mnt/project-files/balance/mazes/).

```bash
python3 tools/maze/map_to_maze.py data/maps/classic.json > /tmp/classic.txt   # gibt -DW/-DH aus
gcc -O2 -DW=56 -DH=56 -o /tmp/maze tools/maze/maze.c -lm
/tmp/maze /tmp/classic.txt 200 3000000 1 > /tmp/bloecke.txt                   # 200 Steine, Iterationen, Seed
/tmp/maze /tmp/classic.txt 200 3000000 1 28 28 12 2 > /tmp/cluster.txt        # mit Kreis um (28,28), Radius 12, Gewicht 2
python3 tools/maze/render.py data/maps/classic.json /tmp/bloecke.txt /tmp/maze.png [cx cy r]   # Schema-Bild (braucht Pillow)
```

Blöcke-Datei: pro Zeile `x y` (linke obere Ecke eines Steins) oder `T x y <tower>` für Tower.
