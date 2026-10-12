#!/usr/bin/env bash
# Räumt alte Builds im Projektordner auf. Ohne --wirklich wird nur angezeigt, was gelöscht würde.
# Nur auf ausdrücklichen Wunsch von Lukas mit --wirklich ausführen (Löschen lässt sich nicht rückgängig machen).
# Aufruf: tools/builds_aufraeumen.sh [--behalten=10] [--wirklich] [--ordner=/mnt/project-files/builds]
#   behält die neuesten N GemTD_V0_<N>.zip; die alten GemTD-Linux/-macOS/-Windows.zip zählen als veraltet.
set -euo pipefail
KEEP=10; REAL=0; DIR=/mnt/project-files/builds
for a in "$@"; do
  case $a in
    --behalten=*) KEEP=${a#*=} ;;
    --wirklich) REAL=1 ;;
    --ordner=*) DIR=${a#*=} ;;
    *) echo "Unbekannte Option: $a"; exit 2 ;;
  esac
done
mapfile -t ALL < <(ls "$DIR" | sed -nE 's/^GemTD_V0_([0-9]+)\.zip$/\1/p' | sort -n)
DEL=()
if [ ${#ALL[@]} -gt "$KEEP" ]; then
  for n in "${ALL[@]:0:${#ALL[@]}-KEEP}"; do DEL+=("GemTD_V0_${n}.zip"); done
fi
for f in GemTD-Linux.zip GemTD-macOS.zip GemTD-Windows.zip; do [ -e "$DIR/$f" ] && DEL+=("$f"); done
[ ${#DEL[@]} -eq 0 ] && { echo "Nichts aufzuräumen."; exit 0; }
SIZE=$(cd "$DIR" && du -ch "${DEL[@]}" | tail -n1 | cut -f1)
echo "${#DEL[@]} Dateien, zusammen $SIZE: ${DEL[0]} … ${DEL[-1]}"
if [ $REAL -eq 1 ]; then
  (cd "$DIR" && rm -f -- "${DEL[@]}"); echo "Gelöscht. Behalten: die neuesten $KEEP Builds."
else
  echo "Nur Vorschau. Zum Löschen: $0 --behalten=$KEEP --wirklich"
fi
