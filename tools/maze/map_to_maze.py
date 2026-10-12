#!/usr/bin/env python3
"""Wandelt eine Map (data/maps/<id>.json) in die Eingabe für maze.c um.

Aufruf: python3 tools/maze/map_to_maze.py data/maps/classic.json > /tmp/classic.txt
Ausgabe: H Zeilen mit W Zeichen ('b' bebaubar, '.' nur laufbar, '#' gesperrt),
dann Anzahl Wegpunkte und die Wegpunkte (Spawn, Checkpoints, Ziel; nur Bahn 0).
"""
import json
import sys

d = json.load(open(sys.argv[1], encoding="utf-8"))
W, H, r = d["width"], d["height"], d.get("marker_radius", 1)
wps = [d["spawn"]] + d["checkpoints"] + [d["goal"]]
for y in range(H):
    row = []
    for x in range(W):
        t = d["tiles"][y][x]
        near = any(max(abs(px - x), abs(py - y)) <= r for px, py in wps)
        row.append("#" if t == "#" else ("b" if t == "." and not near else "."))
    print("".join(row))
print(len(wps))
for x, y in wps:
    print(x, y)
print("Größe: -DW=%d -DH=%d" % (W, H), file=sys.stderr)
