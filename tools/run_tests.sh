#!/usr/bin/env bash
# Führt die Tests aus und gibt nur eine Zusammenfassung aus. Volle Ausgaben liegen in $LOG_DIR.
# Aufruf: tools/run_tests.sh [schnell|alle|<name> ...]
#   schnell (Standard): Prüfskripte, Smoke, Geschosse, eeveTD, Shopping Maul, Netz, Sitzung, Koop, Lobby
#   alle:               dazu Balance (Welle 1), Tempo und späte Wellen
#   <name>:             einzelne Tests, z. B. tools/run_tests.sh smoke koop
# Exit-Code 0 = alles grün.
set -uo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.local/bin:$PATH"
GODOT="${GODOT:-godot}"
LOG_DIR="${LOG_DIR:-/tmp/gemtd-tests}"
mkdir -p "$LOG_DIR"
command -v "$GODOT" >/dev/null || { echo "Godot fehlt: tools/setup_godot.sh --ohne-vorlage"; exit 2; }

FAILED=0
# Zeilen, die headless immer kommen und nichts bedeuten.
NOISE='Parameter "m" is null|^Godot Engine|^\s*at: |^$'

summary() {  # name log exit
  local name=$1 log=$2 code=$3 ok fail
  ok=$(grep -c '^OK' "$log" 2>/dev/null || true)
  fail=$(grep -cE '^FAIL|SCRIPT ERROR|Parse Error' "$log" 2>/dev/null || true)
  if [ "$code" -eq 0 ] && [ "$fail" -eq 0 ]; then
    printf '✓ %-14s %s\n' "$name" "$( [ "$ok" -gt 0 ] && echo "$ok OK" || tail -n1 "$log")"
  else
    FAILED=1
    printf '✗ %-14s Exit %s, %s Fehler (Log: %s)\n' "$name" "$code" "$fail" "$log"
    grep -E '^FAIL|SCRIPT ERROR|Parse Error|ERROR' "$log" | grep -vE "$NOISE" | head -n 15 | sed 's/^/    /'
  fi
}

run_one() {  # name scene [args...]
  local name=$1 scene=$2; shift 2
  local log="$LOG_DIR/$name.log"
  timeout 900 "$GODOT" --headless --path . "res://tests/$scene.tscn" "$@" >"$log" 2>&1
  summary "$name" "$log" $?
}

run_fixed() {  # Balance-Tests mit fester Bildrate
  local name=$1 scene=$2; shift 2
  local log="$LOG_DIR/$name.log"
  timeout 1800 "$GODOT" --headless --fixed-fps 60 --path . "res://tests/$scene.tscn" "$@" >"$log" 2>&1
  summary "$name" "$log" $?
}

run_pair() {  # name scene: Host und Client als zwei Prozesse
  local name=$1 scene=$2
  local hl="$LOG_DIR/$name-host.log" cl="$LOG_DIR/$name-client.log"
  timeout 600 "$GODOT" --headless --path . "res://tests/$scene.tscn" -- --role=host >"$hl" 2>&1 &
  local hp=$!
  sleep 1
  timeout 600 "$GODOT" --headless --path . "res://tests/$scene.tscn" -- --role=client >"$cl" 2>&1
  local cc=$?
  wait $hp; local hc=$?
  cat "$hl" "$cl" > "$LOG_DIR/$name.log"
  summary "$name" "$LOG_DIR/$name.log" $(( hc != 0 ? hc : cc ))
}

run_check() {  # name command...
  local name=$1; shift
  local log="$LOG_DIR/$name.log"
  "$@" >"$log" 2>&1
  local code=$?
  if [ $code -eq 0 ]; then printf '✓ %-14s %s\n' "$name" "$(tail -n1 "$log")"
  else FAILED=1; printf '✗ %-14s\n' "$name"; head -n 15 "$log" | sed 's/^/    /'; fi
}

do_test() {
  case $1 in
    tabelle) run_check tabelle python3 tools/tower_tabelle.py --pruefen ;;
    ui)      run_check ui python3 tools/pruefe_ui.py ;;
    maps)    run_check maps python3 tools/map_check.py --kurz ;;
    smoke)   run_one smoke smoke_test ;;
    maul)    run_one maul maul_test ;;
    eeve)    run_one eeve eeve_test ;;
    geschosse) run_one geschosse geschoss_test ;;
    netz)    run_pair netz net_test ;;
    sitzung) run_pair sitzung session_test ;;
    koop)    run_pair koop coop_test ;;
    lobby)   run_pair lobby lobby_test ;;
    balance) run_fixed balance balance_test ;;
    tempo)   run_fixed tempo speed_test -- --runs=1 ;;
    spaet)   run_fixed spaet late_balance_test ;;
    *) echo "Unbekannter Test: $1"; FAILED=1 ;;
  esac
}

# Beim ersten Lauf in einem frischen Checkout Ressourcen importieren.
[ -d .godot/imported ] || "$GODOT" --headless --import --path . >"$LOG_DIR/import.log" 2>&1

MODE=${1:-schnell}
case $MODE in
  schnell) set -- tabelle ui maps smoke geschosse eeve maul netz sitzung koop lobby ;;
  alle)    set -- tabelle ui maps smoke geschosse eeve maul netz sitzung koop lobby balance tempo spaet ;;
esac
# Prüfskripte, Smoke und die Host/Client-Paare (eigene Ports) laufen parallel, Balance-Läufe danach einzeln.
PAR=(); SEQ=()
for t in "$@"; do case $t in balance|tempo|spaet) SEQ+=("$t") ;; *) PAR+=("$t") ;; esac; done
for t in "${PAR[@]}"; do
  ( FAILED=0; do_test "$t" > "$LOG_DIR/$t.sum"; echo $FAILED > "$LOG_DIR/$t.rc" ) &
done
wait
for t in "${PAR[@]}"; do
  cat "$LOG_DIR/$t.sum"
  [ "$(cat "$LOG_DIR/$t.rc")" = 0 ] || FAILED=1
done
for t in "${SEQ[@]}"; do do_test "$t"; done
exit $FAILED
