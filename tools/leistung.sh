#!/usr/bin/env bash
# Leistung messen: startet das Spiel wie tools/screenshot.sh (Xvfb + OpenGL, Software-Rendering) und misst
# statt eines Bildes einige Sekunden lang Bildzeit, Skriptzeit, Draw Calls, Objekte, Lichter, Knoten.
# Absolute Bildraten sind ohne Grafikkarte wenig wert, Draw Calls, Objekte und Skriptzeit aber vergleichbar.
#   tools/leistung.sh                      alle Standard-Szenen (je Modus eine Welle mit Towern)
#   tools/leistung.sh gemtd eeve           nur diese Szenen
#   tools/leistung.sh -- --map=classic --runden=3 --phase=welle   eigene Optionen (siehe tools/screenshot.gd)
# SEKUNDEN=8 ändert die Messdauer, GROESSE=1280x720 die Fenstergröße.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.local/bin:$PATH"
SIZE=${GROESSE:-1280x720}
SEK=${SEKUNDEN:-6}
declare -A SZENEN=(
  [menu]="--szene=menu"
  [gemtd]="--runden=4 --welle=30 --phase=welle --warten=3"
  [eeve]="--map=eeve --phase=welle --warten=3"
  [maul]="--szene=maul --filiale=hm --sandbox --level=3 --welle --warten=3"
  [randgruppen]="--map=randgruppen --phase=welle --warten=3"
  [youtd]="--map=youtd --phase=welle --warten=3"
)
REIHE=(menu gemtd eeve maul randgruppen youtd)
tools/godot_import.sh
# Jede Szene zweimal: ohne Grafik (--headless, Bildzeit = nur Skripte und Physik) und mit Grafik.
lauf() {
  local name=$1; shift
  local log1 log2; log1=$(mktemp); log2=$(mktemp)
  godot --headless --path . res://tools/screenshot.tscn -- --messen="$SEK" "$@" >"$log1" 2>&1 || true
  xvfb-run -a -s "-screen 0 ${SIZE}x24" godot --rendering-driver opengl3 --resolution "$SIZE" --path . \
    res://tools/screenshot.tscn -- --messen="$SEK" "$@" >"$log2" 2>&1 || true
  echo "== $name"
  if ! grep -q '^MESSUNG' "$log2"; then
    echo "  keine Messung:"; grep -E "ERROR|SCRIPT" "$log2" | head -8
  else
    grep '^MESSUNG prozess_ms' "$log1" | sed 's/^MESSUNG prozess_ms/  skript_ms (ohne Grafik)/'
    grep '^MESSUNG' "$log2" | grep -v prozess_ms | sed 's/^MESSUNG /  /'
  fi
  grep -E "SCRIPT ERROR" "$log2" | head -3 || true
  rm -f "$log1" "$log2"
}
if [[ ${1:-} == "--" ]]; then shift; lauf eigene "$@"; exit; fi
[[ $# -gt 0 ]] && REIHE=("$@")
for n in "${REIHE[@]}"; do
  # shellcheck disable=SC2086
  lauf "$n" ${SZENEN[$n]}
done
