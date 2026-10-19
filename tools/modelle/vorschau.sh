#!/usr/bin/env bash
# Kontaktbogen für Modelle: tools/modelle/vorschau.sh <bogen.png> <a.glb> [b.glb …]
# Rendert jedes Modell einzeln (Xvfb + OpenGL) und setzt die Bilder mit Namen zu einem Bogen zusammen.
set -euo pipefail
cd "$(dirname "$0")/../.."
export PATH="$HOME/.local/bin:$PATH"
OUT=$1; shift
TMP=$(mktemp -d)
FILES=()
for f in "$@"; do FILES+=("$(realpath "$f")"); done
xvfb-run -a -s "-screen 0 320x320x24" godot --rendering-driver opengl3 --resolution 320x320 --path . \
  -s tools/modelle/vorschau.gd -- "$TMP" "${FILES[@]}" 2>&1 | grep -E "^(BILD|FEHLER)" || true
python3 -I - "$TMP" "$OUT" <<'PY'
import os, sys
from PIL import Image, ImageDraw
src, out = sys.argv[1], sys.argv[2]
files = sorted(f for f in os.listdir(src) if f.endswith(".png"))
s, cols = 200, 6
rows = (len(files) + cols - 1) // cols
im = Image.new("RGB", (cols * s, max(1, rows) * (s + 14)), (30, 30, 40))
d = ImageDraw.Draw(im)
for i, f in enumerate(files):
    t = Image.open(os.path.join(src, f)).convert("RGB")
    t.thumbnail((s, s))
    x, y = (i % cols) * s, (i // cols) * (s + 14)
    im.paste(t, (x, y))
    d.text((x + 2, y + s), f[:-4][:30], fill=(255, 255, 255))
im.save(out)
print("BOGEN", out)
PY
rm -rf "$TMP"
