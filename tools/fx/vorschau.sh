#!/usr/bin/env bash
# Effekt-Vorschau (Xvfb + Vulkan über lavapipe), Optionen siehe tools/fx/vorschau.gd
set -euo pipefail
cd "$(dirname "$0")/../.."
export PATH="$HOME/.local/bin:$PATH"
source tools/render_treiber.sh
tools/godot_import.sh
LOG=$(mktemp)
xvfb-run -a -s "-screen 0 1600x1000x24" godot "${RENDER_ARGS[@]}" --resolution 1600x1000 --path . \
  res://tools/fx/vorschau.tscn -- "$@" >"$LOG" 2>&1 || true
grep -E '^BILD|^TOWER' "$LOG" || { echo "Kein Bild erzeugt:"; grep -E "ERROR|SCRIPT" "$LOG" | head -20; rm -f "$LOG"; exit 1; }
mapfile -t BILDER < <(grep '^BILD' "$LOG" | cut -c6-)
[ ${#BILDER[@]} -gt 0 ] && python3 tools/ansicht.py "${BILDER[@]}" || true
grep -E "SCRIPT ERROR|ERROR" "$LOG" | head -10 || true
rm -f "$LOG"
