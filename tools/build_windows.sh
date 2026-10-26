#!/usr/bin/env bash
# Baut die Windows-Version und legt sie als nächste Nummer GemTD_V0_<N>.zip ab.
# Nur bauen, wenn Lukas ausdrücklich nach einem Build fragt (Projektregel).
# Aufruf: tools/build_windows.sh [--ziel <ordner>] [--ohne-tests] [--ohne-tag] [--nummer <N>]
#   --ziel       Ablageort (Standard /mnt/project-files/builds). Zum Ausprobieren einen Testordner angeben.
#   --ohne-tests Tests überspringen (Standard: tools/run_tests.sh schnell vorher, Abbruch bei Fehlern)
#   --ohne-tag   kein Git-Tag v0.<N> setzen (Standard: Tag setzen und pushen, nur bei Ablage in builds/)
#   --nummer     feste Nummer statt der nächsten freien (GitHub-Release, .github/workflows/release.yml)
# Letzte Ausgabezeile: BUILD GemTD_V0_<N>.zip <Größe> <Commit>
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.local/bin:$PATH"

ZIEL=/mnt/project-files/builds
TESTS=1
TAG=1
NUMMER=
while [ $# -gt 0 ]; do
  case $1 in
    --ziel) ZIEL=$2; shift 2 ;;
    --ohne-tests) TESTS=0; shift ;;
    --ohne-tag) TAG=0; shift ;;
    --nummer) NUMMER=$2; shift 2 ;;
    *) echo "Unbekannte Option: $1"; exit 2 ;;
  esac
done
[ "$ZIEL" = /mnt/project-files/builds ] || TAG=0

tools/setup_godot.sh >/dev/null

if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  echo "Achtung: ungespeicherte Änderungen, der Build enthält sie, der Commit-Name nicht."
fi

if [ $TESTS -eq 1 ]; then
  tools/run_tests.sh schnell || { echo "Tests rot, kein Build."; exit 1; }
fi

# Höchste vorhandene Nummer suchen, nichts überschreiben.
mkdir -p "$ZIEL"
N=$(ls "$ZIEL" 2>/dev/null | sed -nE 's/^GemTD_V0_([0-9]+)\.zip$/\1/p' | sort -n | tail -n1)
N=$(( ${N:-0} + 1 ))
[ -n "$NUMMER" ] && N=$NUMMER
NAME="GemTD_V0_${N}.zip"
[ -e "$ZIEL/$NAME" ] && { echo "$NAME existiert schon"; exit 1; }

# Tower-Tabelle aktuell halten (Projektregel).
python3 tools/tower_tabelle.py --kopieren >/dev/null

TMP=$(mktemp -d)
# Versionsnummer nur für den Export eintragen (Hub und Mitwirkende zeigen sie), danach zurücksetzen.
cp project.godot "$TMP/project.godot.orig"
trap 'cp "$TMP/project.godot.orig" project.godot; rm -rf "$TMP"' EXIT
python3 - "0.${N}" <<'PY'
import re, sys
s = open("project.godot", encoding="utf-8").read()
s = re.sub(r'\nconfig/version="[^"]*"', "", s)
s = s.replace('config/name="TD Hub"', 'config/name="TD Hub"\nconfig/version="%s"' % sys.argv[1], 1)
open("project.godot", "w", encoding="utf-8").write(s)
PY
mkdir -p export/windows "$TMP/GemTD"
tools/godot_import.sh
godot --headless --path . --export-release "Windows" "$TMP/GemTD/GemTD.exe" >"$TMP/export.log" 2>&1 || {
  echo "Export fehlgeschlagen:"; grep -E "ERROR|error" "$TMP/export.log" | grep -v 'Parameter "m"' | head -20; exit 1; }
[ -s "$TMP/GemTD/GemTD.exe" ] || { echo "Export hat keine GemTD.exe erzeugt"; tail -20 "$TMP/export.log"; exit 1; }

python3 - "$TMP" "$TMP/$NAME" <<'PY'
import sys, zipfile, pathlib
root = pathlib.Path(sys.argv[1])
with zipfile.ZipFile(sys.argv[2], "w", zipfile.ZIP_DEFLATED) as z:
    for f in sorted((root / "GemTD").rglob("*")):
        z.write(f, f.relative_to(root).as_posix())
PY
cp "$TMP/$NAME" "$ZIEL/$NAME"

COMMIT=$(git rev-parse --short HEAD)
if [ $TAG -eq 1 ]; then
  git tag -f "v0.${N}" HEAD >/dev/null
  git push -q origin "v0.${N}" 2>/dev/null || echo "Hinweis: Tag v0.${N} nur lokal (Push fehlgeschlagen)"
fi
echo "BUILD $NAME $(du -h "$ZIEL/$NAME" | cut -f1) $COMMIT"
