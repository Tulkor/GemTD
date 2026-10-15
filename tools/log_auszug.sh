#!/usr/bin/env bash
# Zeigt aus dem Log eines Tests nur das Wichtige: Fehlerstellen mit etwas Umgebung, ohne das
# Headless-Rauschen (tausende "Parameter m is null"-Zeilen). Statt das ganze Log zu lesen.
# Aufruf: tools/log_auszug.sh <test> [--umgebung=3] [--alles]
#   <test>       Name wie in run_tests.sh (smoke, koop, ...); bei Paaren/Trios je Rolle getrennt
#   --umgebung=N Zeilen vor und nach jeder Fehlerstelle (Standard 3)
#   --alles      das ganze Log ohne Rauschen (z. B. um OK-Zeilen zu sehen)
set -uo pipefail
LOG_DIR="${LOG_DIR:-/tmp/gemtd-tests}"
NAME=""; CTX=3; ALL=0
for a in "$@"; do case $a in --umgebung=*) CTX=${a#--umgebung=} ;; --alles) ALL=1 ;; -*) echo "Unbekannt: $a"; exit 2 ;; *) NAME=$a ;; esac; done
[ -n "$NAME" ] || { echo "Aufruf: tools/log_auszug.sh <test> [--umgebung=3] [--alles]"; ls "$LOG_DIR" 2>/dev/null | sed -n 's/\.log$//p' | grep -v -- '-' | tr '\n' ' '; echo; exit 2; }
NOISE='Parameter "m" is null|mesh_get_surface_count|^Godot Engine|^$'
FILES=$(ls "$LOG_DIR/$NAME"-*.log 2>/dev/null || true)
[ -n "$FILES" ] || FILES="$LOG_DIR/$NAME.log"
for f in $FILES; do
  [ -f "$f" ] || { echo "Kein Log: $f (erst tools/run_tests.sh $NAME)"; exit 1; }
  CLEAN=$(grep -vE "$NOISE" "$f")
  echo "== $(basename "$f" .log): $(echo "$CLEAN" | grep -c '^OK') OK, $(echo "$CLEAN" | grep -cE '^FAIL|SCRIPT ERROR|Parse Error') Fehler"
  if [ $ALL -eq 1 ]; then echo "$CLEAN"; continue; fi
  HITS=$(echo "$CLEAN" | grep -nE '^FAIL|SCRIPT ERROR|Parse Error|^ERROR|^WARNING|^USER ERROR|ABGELAUFEN|ABWEICHUNG' | cut -d: -f1)
  if [ -z "$HITS" ]; then echo "$CLEAN" | tail -n 3; continue; fi
  # Fehlerstellen mit Umgebung, überlappende Bereiche zusammengefasst, Stack-Zeilen ("at:") bleiben dabei
  echo "$CLEAN" | awk -v ctx="$CTX" -v hits="$(echo $HITS)" '
    BEGIN { n = split(hits, h, " "); for (i = 1; i <= n; i++) for (j = h[i] - ctx; j <= h[i] + ctx; j++) show[j] = 1 }
    { if (show[NR]) { if (NR > last + 1 && last > 0) print "  ..."; printf "%5d  %s\n", NR, $0; last = NR } }' | head -n 80
done
