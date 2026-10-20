#!/usr/bin/env bash
# Kurzer Lagebericht zum Thread-Start statt git status/log/branch -r/ls einzeln (spart Schritte und Ausgabe).
# tools/lage.sh: Branch, Abstand zu main, offene Änderungen, neue main-Commits, ungemergte Branches, neue Uploads.
set -uo pipefail
cd "$(dirname "$0")/.."
git fetch -q origin 2>/dev/null || echo "(fetch fehlgeschlagen, Stand lokal)"
B=$(git branch --show-current)
read -r HINTER VOR < <(git rev-list --left-right --count origin/main...HEAD 2>/dev/null || echo "? ?")
echo "Branch $B: $VOR eigene Commits, $HINTER hinter main"
N=$(git status --porcelain | wc -l)
[ "$N" -gt 0 ] && { echo "Offene Änderungen ($N):"; git status --porcelain | head -8; }
echo "main zuletzt:"; git log --format='  %h %ad %s' --date=format:'%m-%d %H:%M' -5 origin/main
OFFEN=$(git branch -r --no-merged origin/main 2>/dev/null | grep -v HEAD | sed 's#^ *origin/##' | head -10 | tr '\n' ' ')
[ -n "$OFFEN" ] && echo "Nicht in main: $OFFEN"
U=/mnt/project-files/uploads/hearth
if [ -d "$U" ]; then
  echo "Neueste Uploads:"
  ls -t "$U" | head -3 | while read -r f; do echo "  $U/$f: $(file -b "$U/$f" | cut -c1-60)"; done
fi
