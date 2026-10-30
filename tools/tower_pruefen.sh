#!/usr/bin/env bash
# Prüft jeden Tower einzeln: Schaden und jede Fähigkeit (tests/lib/tower_probe.gd), Auren-Tower neben einem Helfer.
#   tools/tower_pruefen.sh [gemtd eeve rg maul] [--tower=id1,id2]
# Ohne Modus alle vier. Berichte (Tabelle je Tower) nach /mnt/project-files/tests/tower-pruefung-<modus>.md,
# Ausgabe nur die Fehlerzeilen und eine Zusammenfassung je Modus. YouTD prüft tools/run_tests.sh ytfaehig.
cd "$(dirname "$0")/.." || exit 1
GODOT=${GODOT:-godot}
OUT=${TOWER_BERICHT:-/mnt/project-files/tests}
mkdir -p "$OUT" /tmp/gemtd-tests
MODES=(); EXTRA=()
for a in "$@"; do
  case $a in
    --*) EXTRA+=("$a") ;;
    *) MODES+=("$a") ;;
  esac
done
[ ${#MODES[@]} -eq 0 ] && MODES=(gemtd eeve rg maul)
tools/godot_import.sh /tmp/gemtd-tests/import.log >/dev/null 2>&1
rc=0
for m in "${MODES[@]}"; do
  log=/tmp/gemtd-tests/tower-pruefung-$m.log
  timeout 1200 "$GODOT" --headless --fixed-fps 60 --path . "res://tests/towers_${m}_test.tscn" -- \
    --bericht="$OUT/tower-pruefung-$m.md" "${EXTRA[@]}" >"$log" 2>&1 || rc=1
  grep -E '^(FAIL|SCRIPT ERROR)' "$log" | sort | uniq -c | sed 's/^ *1 //' | head -n 40
  grep -E '^TOWERS [a-z]+:' "$log" || { echo "$m: kein Ergebnis (Log $log)"; rc=1; }
  echo "  Bericht: $OUT/tower-pruefung-$m.md"
done
exit $rc
