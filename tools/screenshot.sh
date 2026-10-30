#!/usr/bin/env bash
# Screenshots aus dem echten Spiel (Xvfb + OpenGL). Optionen siehe tools/screenshot.gd.
# Am Ende: ANSICHT <jpg> = verkleinerte Ansicht aller Bilder; nur diese lesen (spart Tokens).
# Beispiele:
#   tools/screenshot.sh --runden=3 --phase=wahl --auswahl --winkel=schraeg,oben --name=auswahl
#   tools/screenshot.sh --szene=menu --sprache=en --name=menu_en
#   tools/screenshot.sh --groesse=1280x720 --runden=2 --phase=welle --warten=4 --winkel=nah --name=welle
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.local/bin:$PATH"
SIZE=1920x1080
ARGS=()
for a in "$@"; do
  case $a in --groesse=*) SIZE=${a#--groesse=} ;; *) ARGS+=("$a") ;; esac
done
tools/godot_import.sh
LOG=$(mktemp)
xvfb-run -a -s "-screen 0 ${SIZE}x24" godot --rendering-driver opengl3 --resolution "$SIZE" --path . \
  res://tools/screenshot.tscn -- "${ARGS[@]}" >"$LOG" 2>&1 || true
grep -E '^BILD|^TREFFER|^UI ' "$LOG" || { echo "Kein Bild erzeugt:"; grep -E "ERROR|SCRIPT" "$LOG" | grep -v 'Parameter "m"' | head -15; rm -f "$LOG"; exit 1; }
# Zum Ansehen die verkleinerte Ansicht lesen (alle Winkel in einem Bild), die PNGs bleiben für Lukas.
mapfile -t BILDER < <(grep '^BILD' "$LOG" | cut -c6-)
python3 tools/ansicht.py "${BILDER[@]}" || true
grep -E "SCRIPT ERROR" "$LOG" | head -5 || true
rm -f "$LOG"
