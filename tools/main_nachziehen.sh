#!/usr/bin/env bash
# Holt origin/main in den aktuellen Branch (Merge, kein Rebase) und gibt nur das Wichtige aus:
# neue Commits von main, Konflikte mit ihren Stellen, danach auf Wunsch die Schnelltests.
# Aufruf: tools/main_nachziehen.sh [--tests] [--basis=main]
# Exit 0 = gemergt (und Tests grün), 1 = Konflikte offen (Merge läuft noch, nach dem Lösen: git add + git commit), 2 = sonstiger Fehler.
set -uo pipefail
cd "$(dirname "$0")/.."
BASE=main; TESTS=0
for a in "$@"; do case $a in --tests) TESTS=1 ;; --basis=*) BASE=${a#--basis=} ;; *) echo "Unbekannt: $a"; exit 2 ;; esac; done

if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  echo "Ungespeicherte Änderungen, erst committen oder stashen:"; git status --short --untracked-files=no | head -20; exit 2
fi
# en.json: Übersetzungen beider Seiten zusammenführen statt Konflikt (tools/git-hooks/json_merge.py)
git config merge.json_schluessel.driver "python3 tools/git-hooks/json_merge.py %O %A %B %P"
for i in 1 2 3 4; do git fetch -q origin "$BASE" && break; sleep $((2**i)); done
BRANCH=$(git rev-parse --abbrev-ref HEAD)
NEW=$(git rev-list --count "HEAD..origin/$BASE")
if [ "$NEW" -eq 0 ]; then echo "$BRANCH ist aktuell mit origin/$BASE."; else
  echo "$NEW neue Commits auf origin/$BASE:"
  git log --no-merges --format='  %h %s' "HEAD..origin/$BASE" | head -15
  if git merge -q --no-edit "origin/$BASE" >/tmp/gemtd-merge.log 2>&1; then
    echo "Gemergt. Geänderte Dateien: $(git diff --stat HEAD@{1} HEAD | tail -n1)"
  else
    FILES=$(git diff --name-only --diff-filter=U)
    if [ -z "$FILES" ]; then cat /tmp/gemtd-merge.log; exit 2; fi
    echo "KONFLIKTE ($(echo "$FILES" | wc -l) Dateien), Merge läuft noch:"
    for f in $FILES; do
      echo "  $f: $(grep -c '^<<<<<<<' "$f") Stellen, Zeilen $(grep -n '^<<<<<<<' "$f" | cut -d: -f1 | tr '\n' ' ')"
    done
    JM=$(grep -A20 '^json_merge' /tmp/gemtd-merge.log | grep -E "^json_merge|^  '")
    [ -z "$JM" ] || { echo "$JM" | sed 's/^/  /'; echo "  (json_merge hat die Datei schon zusammengeführt, nur die genannten Werte prüfen)"; }
    echo "Lösen, dann: git add <dateien> && git commit --no-edit   (abbrechen: git merge --abort)"
    exit 1
  fi
fi
[ "$TESTS" -eq 1 ] && exec tools/run_tests.sh
exit 0
