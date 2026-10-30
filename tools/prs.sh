#!/usr/bin/env bash
# PRs ohne GitHub-API: liest die PR-Stände direkt aus git (refs/pull/N/head), statt list_pull_requests
# und pull_request_read mit großen JSON-Antworten (PR-Texte, Kommentare) in den Kontext zu holen.
#   tools/prs.sh offen [--tage=14] [--kurz]  ungemergte PRs: Nummer, Alter, Commits, Titel, Bereiche; Dateien, die
#                                    mehrere PRs ändern (= wahrscheinliche Konflikte beim Sammeln)
#   tools/prs.sh sammeln 72 73 …     PR-Stände nacheinander in den aktuellen Branch mergen (Sammel-PR);
#                                    hält beim ersten Konflikt mit Datei und Zeilen an
#   tools/prs.sh weiter              nach dem Lösen (git add + git commit) mit den restlichen PRs weitermachen
#   tools/prs.sh text [--basis=main] PR-Text-Entwurf aus den Commits und dem letzten Testlauf
# "Offen" heißt hier: Stand nicht in origin/main. Geschlossene, nie gemergte PRs zählen mit; --tage blendet alte aus.
set -uo pipefail
cd "$(dirname "$0")/.."
REST=$(git rev-parse --git-dir)/gemtd-sammeln  # in Worktrees ist .git eine Datei

holen() {  # alle PR-Köpfe nach refs/pr/N (nicht unter remotes, damit git branch -r sauber bleibt)
  for i in 1 2 3; do git fetch -q origin '+refs/pull/*/head:refs/pr/*' main 2>/dev/null && return 0; sleep $((2**i)); done
  echo "fetch der PR-Stände fehlgeschlagen"; exit 2
}

bereiche() {  # Dateiliste -> kurze Bereichsangabe (scripts/youtd, data/maul …)
  awk -F/ '{ k = (NF > 2) ? $1"/"$2 : $1; n[k]++ } END { for (k in n) printf "%s(%d) ", k, n[k] }'
}

offen() {
  local tage=14 kurz=0 now cut n ref ts ahead files
  for a in "$@"; do case $a in --tage=*) tage=${a#--tage=} ;; --kurz) kurz=1 ;; esac; done
  holen
  now=$(date +%s); cut=$((now - tage * 86400))
  : >/tmp/gemtd-prs-dateien
  for ref in $(git for-each-ref --format='%(refname:short)' refs/pr/ | sort -t/ -k2 -n); do
    n=${ref#pr/}
    git merge-base --is-ancestor "$ref" origin/main 2>/dev/null && continue
    ts=$(git log -1 --format=%ct "$ref")
    [ "$ts" -lt "$cut" ] && continue
    ahead=$(git rev-list --count --no-merges "origin/main..$ref")
    [ "$ahead" -eq 0 ] && continue
    [ $kurz -eq 1 ] && { printf '#%s ' "$n"; echo "#$n" >>/tmp/gemtd-prs-dateien; continue; }
    files=$(git diff --name-only "origin/main...$ref")
    echo "$files" | sed "s|^|#$n |" >>/tmp/gemtd-prs-dateien
    printf '#%s  %s  %d Commits  %s\n      %s\n' "$n" "$(git log -1 --format='%ad' --date=format:'%m-%d %H:%M' "$ref")" \
      "$ahead" "$(git log -1 --no-merges --format=%s "$ref" | cut -c1-80)" "$(echo "$files" | bereiche)"
  done
  [ $kurz -eq 1 ] && { [ -s /tmp/gemtd-prs-dateien ] && echo || echo "keine"; return; }
  local doppelt
  doppelt=$(awk '{ prs[$2] = prs[$2] " " $1; c[$2]++ } END { for (f in c) if (c[f] > 1) print "  " f ":" prs[f] }' /tmp/gemtd-prs-dateien | sort | head -20)
  [ -n "$doppelt" ] && { echo "Von mehreren PRs geändert (Konfliktgefahr):"; echo "$doppelt"; }
  [ -s /tmp/gemtd-prs-dateien ] || echo "Keine offenen PRs der letzten $tage Tage."
}

konflikt_stellen() {
  local f
  for f in $(git diff --name-only --diff-filter=U); do
    echo "  $f: $(grep -c '^<<<<<<<' "$f") Stellen, Zeilen $(grep -n '^<<<<<<<' "$f" | cut -d: -f1 | tr '\n' ' ')"
  done
}

sammeln() {
  local n ref subj
  [ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "Ungespeicherte Änderungen, erst committen."; exit 2; }
  git config merge.json_schluessel.driver "python3 tools/git-hooks/json_merge.py %O %A %B %P"
  [ -n "${SCHON_GEHOLT:-}" ] || holen
  while [ $# -gt 0 ]; do
    n=${1#\#}; shift; ref=pr/$n
    git rev-parse -q --verify "$ref" >/dev/null || { echo "#$n: kein PR-Stand gefunden"; continue; }
    if git merge-base --is-ancestor "$ref" HEAD; then echo "#$n: schon enthalten"; continue; fi
    subj=$(git log -1 --no-merges --format=%s "$ref" | cut -c1-60)
    if git merge -q --no-edit -m "Merge #$n ($subj) in Sammelstand" "$ref" >/tmp/gemtd-merge.log 2>&1; then
      echo "#$n: gemergt ($(git diff --shortstat HEAD^1 HEAD | sed 's/^ //'))"
    else
      [ -n "$(git diff --name-only --diff-filter=U)" ] || { cat /tmp/gemtd-merge.log; exit 2; }
      echo "#$n: KONFLIKT, Merge läuft noch:"; konflikt_stellen
      grep -E "^json_merge|^  '" /tmp/gemtd-merge.log | head -10 | sed 's/^/  /'
      echo "$*" >"$REST"
      echo "Lösen, dann: git add <dateien> && git commit --no-edit && tools/prs.sh weiter${*:+   (danach noch: $*)}"
      exit 1
    fi
  done
  rm -f "$REST"
  echo "Fertig. Stand gegenüber main: $(git diff --shortstat origin/main HEAD | sed 's/^ //')"
  echo "Nächster Schritt: tools/run_tests.sh (oder tools/vor_pr.sh --alle)"
}

text() {
  local base=main log
  for a in "$@"; do case $a in --basis=*) base=${a#--basis=} ;; esac; done
  git fetch -q origin "$base" 2>/dev/null
  local mb; mb=$(git merge-base HEAD "origin/$base")
  echo "## Änderungen"
  git log --no-merges --reverse --format='- %s' "$mb..HEAD"
  echo
  echo "Bereiche: $(git diff --name-only "$mb" HEAD | bereiche)"
  echo "$(git diff --shortstat "$mb" HEAD | sed 's/^ //')"
  log=/tmp/gemtd-tests
  if [ -d "$log" ] && ls "$log"/*.log >/dev/null 2>&1; then
    echo; echo "## Tests"
    echo "Letzter Lauf ($(date -r "$(ls -t "$log"/*.log | head -1)" '+%d.%m. %H:%M')): $(ls "$log"/*.log | wc -l) Logs in $log"
  fi
}

case "${1:-}" in
  offen) shift; offen "$@" ;;
  sammeln) shift; sammeln "$@" ;;
  weiter)
    [ -f "$REST" ] || { echo "Nichts zum Weitermachen."; exit 0; }
    [ -z "$(git diff --name-only --diff-filter=U)" ] || { echo "Noch Konflikte offen:"; konflikt_stellen; exit 1; }
    # shellcheck disable=SC2046
    SCHON_GEHOLT=1 sammeln $(cat "$REST") ;;
  text) shift; text "$@" ;;
  *) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
