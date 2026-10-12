#!/usr/bin/env python3
"""Startet tools/map_check.gd mit Godot (Kennzahlen und Fehler aller Maps). Argumente werden durchgereicht."""
import os
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
godot = os.environ.get("GODOT", str(pathlib.Path.home() / ".local/bin/godot"))
r = subprocess.run([godot, "--headless", "--path", str(ROOT), "res://tools/map_check.tscn", "--"] + sys.argv[1:],
                   capture_output=True, text=True)
lines = [l for l in r.stdout.splitlines() if l.strip() and not l.startswith("Godot Engine")]
print("\n".join(lines))
errs = [l for l in r.stderr.splitlines() if "SCRIPT ERROR" in l or "Parse Error" in l]
if errs:
    print("\n".join(errs[:10]))
sys.exit(r.returncode or (1 if errs else 0))
