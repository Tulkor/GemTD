#!/usr/bin/env bash
# Liest eine WC3-Karte (.w3x) komplett aus: entpacken, Objektdaten und Texte als JSON, Skript formatiert.
# Aufruf: tools/wc3/auslesen.sh <karte.w3x> <zielordner>
# Ergebnis im Zielordner: objects.json (Einheiten, Fähigkeiten, Upgrades, Items mit Werten),
# wts.json (Texte), script.j (lesbares JASS-Skript mit Wellen, Einkommen, Regeln), dazu alle Rohdateien.
set -euo pipefail
[ $# -eq 2 ] || { sed -n 2,5p "$0"; exit 2; }
DIR="$(cd "$(dirname "$0")" && pwd)"
python3 -I "$DIR/mpq.py" "$1" "$2" >/dev/null
python3 -I "$DIR/objdata.py" "$2"
J=$(ls "$2"/*war3map.j 2>/dev/null | head -n1 || true)
if [ -n "$J" ]; then python3 -I "$DIR/jfmt.py" "$J" "$2/script.j"; echo "script.j $(wc -l < "$2/script.j") Zeilen"; fi
echo "Fertig: $2 (objects.json, wts.json, script.j)"
