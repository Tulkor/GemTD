#!/usr/bin/env bash
# Alles, was vor einem PR oder Merge geprüft wird, in einem Befehl:
#   1. origin/main nachziehen (tools/main_nachziehen.sh), bei Konflikten Abbruch mit den Stellen
#   2. passende Tests zu den geänderten Dateien (tools/run_tests.sh geaendert, mit --alle: schnell)
#   3. Stil-Hinweise nur für geänderte Oberflächen-Dateien (Farben außerhalb des Themes)
#   4. Kurzfassung der Änderung gegenüber main
# Aufruf: tools/vor_pr.sh [--alle] [--ohne-merge]
# Letzte Zeile: "BEREIT" oder "NICHT BEREIT: <Grund>". Exit 0 nur bei BEREIT.
set -uo pipefail
cd "$(dirname "$0")/.."
TESTS=geaendert; MERGE=1
for a in "$@"; do case $a in --alle) TESTS=schnell ;; --ohne-merge) MERGE=0 ;; *) echo "Unbekannt: $a"; exit 2 ;; esac; done

if [ $MERGE -eq 1 ]; then
  echo "== main nachziehen"
  tools/main_nachziehen.sh; rc=$?
  [ $rc -eq 0 ] || { echo "NICHT BEREIT: main nachziehen (Exit $rc)"; exit 1; }
fi

echo "== Tests ($TESTS)"
tools/run_tests.sh $TESTS; trc=$?

BASE=$(git merge-base HEAD origin/main 2>/dev/null || echo HEAD)
CHANGED=$( { git diff --name-only "$BASE"; git ls-files --others --exclude-standard; } | sort -u)
STYLE=$(python3 tools/pruefe_ui.py --stil 2>/dev/null | grep '^STIL' | grep -F -f <(echo "$CHANGED" | grep '\.gd$' || echo '-nichts-') || true)
if [ -n "$STYLE" ]; then
  echo "== Stil-Hinweise in geänderten Dateien (Farben nicht aus ui_theme.gd; bei 3D-Farben ok)"
  echo "$STYLE" | head -n 15
fi

echo "== Änderung gegenüber main"
git diff --stat "$BASE" | tail -n 1
UNCOMMITTED=$(git status --porcelain --untracked-files=normal | wc -l)
[ "$UNCOMMITTED" -eq 0 ] || echo "$UNCOMMITTED Dateien nicht committet"

if [ $trc -ne 0 ]; then echo "NICHT BEREIT: Tests rot"; exit 1; fi
echo "BEREIT"
