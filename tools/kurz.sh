#!/usr/bin/env bash
# Startet einen langen oder gesprächigen Befehl und zeigt nur das Nötige: das volle Log landet in
# /tmp/gemtd-kurz/<name>.log, ausgegeben werden Exit-Code, Dauer, Fehler-/Warnzeilen (ohne Godot-Headless-Rauschen,
# gleiche Zeilen nur einmal) und die letzten Zeilen. Spart bei Build, Import, Modell-Umwandlung, pip usw.
# hunderte Zeilen Kontext, die sonst bei jedem weiteren Schritt mitbezahlt werden.
#   tools/kurz.sh [--name=x] [--schluss=8] [--muster='REGEX'] <befehl> [argumente …]
# Danach gezielt nachsehen: grep -n 'wort' /tmp/gemtd-kurz/<name>.log oder sed -n 'a,bp'.
set -uo pipefail
NAME=""; SCHLUSS=8; MUSTER='error|fehler|failed|fehlgeschlagen|traceback|exception|warning|warnung|SCRIPT ERROR|not found|nicht gefunden|denied'
while [ $# -gt 0 ]; do
  case $1 in
    --name=*) NAME=${1#--name=} ;; --schluss=*) SCHLUSS=${1#--schluss=} ;; --muster=*) MUSTER=${1#--muster=} ;;
    --) shift; break ;; -*) echo "Unbekannte Option $1"; exit 2 ;; *) break ;;
  esac
  shift
done
[ $# -gt 0 ] || { sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
[ -n "$NAME" ] || NAME=$(basename "$1" | tr -c 'A-Za-z0-9_.-\n' '_')
DIR=/tmp/gemtd-kurz; mkdir -p "$DIR"; LOG=$DIR/$NAME.log
T0=$SECONDS
"$@" >"$LOG" 2>&1; RC=$?
ZEILEN=$(wc -l <"$LOG")
echo "Exit $RC nach $((SECONDS - T0)) s, $ZEILEN Zeilen in $LOG"
# Bekanntes Rauschen von Godot headless und Xvfb ausblenden
RAUSCH='Parameter "m" is null|ObjectDB instances leaked|resources still in use|_xkb|XKEYBOARD|Vulkan|xdg-|Orphan StringName|at: cleanup'
TREFFER=$(grep -inE "$MUSTER" "$LOG" | grep -vE "$RAUSCH" | awk -F: '{ z = $0; sub(/^[0-9]+:/, "", z); if (!seen[z]++) print }')
if [ -n "$TREFFER" ]; then
  N=$(echo "$TREFFER" | wc -l)
  echo "Auffällige Zeilen ($N, je Text einmal):"; echo "$TREFFER" | head -15 | cut -c1-220 | sed 's/^/  /'
  [ "$N" -gt 15 ] && echo "  … $((N - 15)) weitere: grep -inE '…' $LOG"
fi
if [ "$ZEILEN" -gt 0 ] && [ "$SCHLUSS" -gt 0 ]; then
  echo "Schluss:"; tail -n "$SCHLUSS" "$LOG" | cut -c1-220 | sed 's/^/  /'
fi
exit $RC
