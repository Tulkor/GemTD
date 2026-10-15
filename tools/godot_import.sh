#!/usr/bin/env bash
# Importiert die Godot-Ressourcen nur, wenn nötig: frischer Checkout, oder ein Skript bzw. eine
# Asset-Datei ist neuer als der letzte Import (neue class_name nach einem Merge, neue Sprite-Sheets
# aus tools/fx/video_zu_sheet.py). Sonst fehlen Klassen oder Texturen und Tests hängen bis zum Timeout.
# Wird von run_tests.sh, screenshot.sh und fx/vorschau.sh benutzt. Aufruf: tools/godot_import.sh [log]
set -uo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.local/bin:$PATH"
GODOT="${GODOT:-godot}"
MARK=.godot/gemtd_import.stamp
LOG="${1:-/dev/null}"
if [ -d .godot/imported ] && [ -f .godot/global_script_class_cache.cfg ] && [ -f $MARK ] \
   && [ -z "$(find scripts tests tools assets -newer $MARK \( -name '*.gd' -o -name '*.png' -o -name '*.glb' -o -name '*.ttf' -o -name '*.wav' -o -name '*.ogg' -o -name '*.jpg' \) -print -quit)" ]; then
  exit 0
fi
"$GODOT" --headless --import --path . >"$LOG" 2>&1
touch $MARK
