#!/usr/bin/env bash
# Führt die Tests aus und gibt nur eine Zusammenfassung aus. Volle Ausgaben liegen in $LOG_DIR.
# Aufruf: tools/run_tests.sh [schnell|alle|<name> ...]
#   schnell (Standard): Prüfskripte (Tower-Tabelle, Texte, Maps, Werkzeuge), alle Skripte laden, Smoke, Geschosse,
#                       eeveTD, Shopping Maul, Netz, Sitzung, Koop, Lobby, Gemischt
#   alle:               dazu Balance (Welle 1), Tempo und späte Wellen
#   geaendert:          nur die Tests, die zu den geänderten Dateien gegenüber origin/main passen
#                       (plus Prüfskripte); unbekannte Code-Änderungen -> schnell
#   <name>:             einzelne Tests, z. B. tools/run_tests.sh smoke koop
# Pro Test eine Zeile mit Dauer. "⚠" darunter = Godot meldet Fehler, obwohl der Test grün ist
# (ERROR/WARNING außerhalb von NOISE/EXPECTED); das sind meist echte, nur unbemerkte Fehler.
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
# Von Tests absichtlich ausgelöst (Smoke: veränderte Spielstand-Datei wird abgelehnt).
EXPECTED='MD5 sum of the decrypted file'

summary() {  # name log exit start
  local name=$1 log=$2 code=$3 ok fail secs warn
  secs=$(( SECONDS - ${4:-$SECONDS} ))
  ok=$(grep -c '^OK' "$log" 2>/dev/null || true)
  fail=$(grep -cE '^FAIL|SCRIPT ERROR|Parse Error' "$log" 2>/dev/null || true)
  if [ "$code" -eq 0 ] && [ "$fail" -eq 0 ]; then
    printf '✓ %-14s %-12s %3ss\n' "$name" "$( [ "$ok" -gt 0 ] && echo "$ok OK" || tail -n1 "$log")" "$secs"
    warn=$(grep -E '^(ERROR|WARNING|USER ERROR|USER WARNING):' "$log" | grep -vE "$NOISE|$EXPECTED" | sort | uniq -c | sort -rn)
    [ -z "$warn" ] || echo "$warn" | head -n 3 | sed 's/^ */    ⚠ /'
  else
    FAILED=1
    printf '✗ %-14s Exit %s, %s Fehler (Log: %s)\n' "$name" "$code" "$fail" "$log"
    grep -E '^FAIL|SCRIPT ERROR|Parse Error|ERROR' "$log" | grep -vE "$NOISE" | head -n 15 | sed 's/^/    /'
  fi
}

run_one() {  # name scene [args...]
  local name=$1 scene=$2; shift 2
  local log="$LOG_DIR/$name.log"
  local t0=$SECONDS
  timeout 900 "$GODOT" --headless --path . "res://tests/$scene.tscn" "$@" >"$log" 2>&1
  summary "$name" "$log" $? $t0
}

run_fixed() {  # Balance-Tests mit fester Bildrate
  local name=$1 scene=$2; shift 2
  local log="$LOG_DIR/$name.log"
  local t0=$SECONDS
  timeout 1800 "$GODOT" --headless --fixed-fps 60 --path . "res://tests/$scene.tscn" "$@" >"$log" 2>&1
  summary "$name" "$log" $? $t0
}

run_pair() {  # name scene: Host und Client als zwei Prozesse
  local name=$1 scene=$2
  local hl="$LOG_DIR/$name-host.log" cl="$LOG_DIR/$name-client.log" t0=$SECONDS
  timeout 600 "$GODOT" --headless --path . "res://tests/$scene.tscn" -- --role=host >"$hl" 2>&1 &
  local hp=$!
  sleep 1
  timeout 600 "$GODOT" --headless --path . "res://tests/$scene.tscn" -- --role=client >"$cl" 2>&1
  local cc=$?
  wait $hp; local hc=$?
  cat "$hl" "$cl" > "$LOG_DIR/$name.log"
  summary "$name" "$LOG_DIR/$name.log" $(( hc != 0 ? hc : cc )) $t0
}

run_trio() {  # name scene: Host und zwei Mitspieler (a, b) als drei Prozesse
  local name=$1 scene=$2
  local hl="$LOG_DIR/$name-host.log" al="$LOG_DIR/$name-a.log" bl="$LOG_DIR/$name-b.log" t0=$SECONDS
  timeout 600 "$GODOT" --headless --path . "res://tests/$scene.tscn" -- --role=host >"$hl" 2>&1 &
  local hp=$!
  sleep 1
  timeout 600 "$GODOT" --headless --path . "res://tests/$scene.tscn" -- --role=a >"$al" 2>&1 &
  local ap=$!
  timeout 600 "$GODOT" --headless --path . "res://tests/$scene.tscn" -- --role=b >"$bl" 2>&1
  local bc=$?
  wait $ap; local ac=$?
  wait $hp; local hc=$?
  cat "$hl" "$al" "$bl" > "$LOG_DIR/$name.log"
  summary "$name" "$LOG_DIR/$name.log" $(( hc != 0 ? hc : (ac != 0 ? ac : bc) )) $t0
}

run_check() {  # name command...
  local name=$1; shift
  local log="$LOG_DIR/$name.log"
  "$@" >"$log" 2>&1
  local code=$?
  if [ $code -eq 0 ]; then printf '✓ %-14s %s\n' "$name" "$(tail -n1 "$log")"
  else FAILED=1; printf '✗ %-14s\n' "$name"; head -n 15 "$log" | sed 's/^/    /'; fi
}

check_tools() {  # Python- und Shell-Werkzeuge unter tools/ auf Syntaxfehler prüfen (ohne __pycache__ zu schreiben)
  local py sh bad=0
  py=$(git ls-files 'tools/*.py'); sh=$(git ls-files 'tools/*.sh' tools/git-hooks/)
  python3 -c 'import ast, sys
for f in sys.argv[1:]: ast.parse(open(f, encoding="utf-8").read(), f)' $py || bad=1
  for f in $sh; do bash -n "$f" || bad=1; done
  [ $bad -eq 0 ] && echo "Werkzeuge: $(echo $py | wc -w) Python, $(echo $sh | wc -w) Shell ohne Syntaxfehler"
  return $bad
}

do_test() {
  case $1 in
    tabelle) run_check tabelle python3 tools/tower_tabelle.py --pruefen ;;
    ui)      run_check ui python3 tools/pruefe_ui.py ;;
    maps)    run_check maps python3 tools/map_check.py --kurz ;;
    werkzeuge) run_check werkzeuge check_tools ;;
    skripte) run_one skripte skripte_test ;;
    smoke)   run_one smoke smoke_test ;;
    maul)    run_one maul maul_test ;;
    eeve)    run_one eeve eeve_test ;;
    geschosse) run_one geschosse geschoss_test ;;
    netz)    run_pair netz net_test ;;
    sitzung) run_pair sitzung session_test ;;
    koop)    run_pair koop coop_test ;;
    lobby)   run_pair lobby lobby_test ;;
    gemischt) run_trio gemischt gemischt_test ;;
    balance) run_fixed balance balance_test ;;
    tempo)   run_fixed tempo speed_test -- --runs=1 ;;
    spaet)   run_fixed spaet late_balance_test ;;
    *) echo "Unbekannter Test: $1"; FAILED=1 ;;
  esac
}

tools/godot_import.sh "$LOG_DIR/import.log"

# Tests passend zu den geänderten Dateien (Commits seit origin/main und ungespeicherte Änderungen).
pick_changed() {
  local base files f n t=" tabelle ui maps werkzeuge skripte "
  base=$(git merge-base HEAD origin/main 2>/dev/null || echo HEAD)
  files=$( { git diff --name-only "$base"; git ls-files --others --exclude-standard; } | sort -u)
  for f in $files; do
    case $f in
      tests/*_test.*)
        n=$(basename "$f"); n=${n%_test.*}
        case $n in
          net) n=netz ;; session) n=sitzung ;; coop) n=koop ;; geschoss) n=geschosse ;;
          speed) n=tempo ;; late_balance) n=spaet ;; skripte) n="" ;;
        esac
        t+="$n " ;;
      tools/*.gd|tools/*.tscn) ;;  # werden von "skripte" geladen
      tools/*|docs/*|*.md|data/i18n/*) ;;
      data/fx/*|assets/fx/*|scripts/game/fx_*|scripts/game/effects.gd) t+="smoke geschosse eeve maul " ;;
      scripts/maul/*|data/maul/*|scenes/maul*) t+="maul " ;;
      scripts/game/eeve*|data/eeve.json|data/*/eeve_*|scenes/eeve*) t+="eeve " ;;
      scripts/ui/lobby*) t+="lobby gemischt " ;;
      scripts/net/*|scripts/autoload/net.gd) t+="netz sitzung koop lobby gemischt " ;;
      scripts/game/save_game.gd|scripts/game/run_history.gd|scripts/autoload/session.gd) t+="smoke sitzung " ;;
      data/towers/*|data/enemies/*|data/waves/*|data/balance.json|data/maps/*) t+="smoke " ;;
      scripts/ui/*|scripts/game/hud.gd|scripts/game/*panel*|scripts/editor/*) t+="smoke " ;;
      *.gd|*.tscn|*.tres|*.gdshader|project.godot|data/*) echo "schnell"; return ;;
    esac
  done
  echo "$t" | tr ' ' '\n' | awk 'NF && !seen[$0]++' | tr '\n' ' '
}

MODE=${1:-schnell}
if [ "$MODE" = geaendert ]; then
  MODE=$(pick_changed)
  echo "Geänderte Dateien -> Tests: $MODE"
  # shellcheck disable=SC2086
  set -- $MODE
fi
case $MODE in
  schnell) set -- tabelle ui maps werkzeuge skripte smoke geschosse eeve maul netz sitzung koop lobby gemischt ;;
  alle)    set -- tabelle ui maps werkzeuge skripte smoke geschosse eeve maul netz sitzung koop lobby gemischt balance tempo spaet ;;
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
echo "Gesamt: ${SECONDS}s"
exit $FAILED
