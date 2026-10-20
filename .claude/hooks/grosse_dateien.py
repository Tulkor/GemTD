#!/usr/bin/env python3
"""PreToolUse-Hook: hält Claude davon ab, große Dateien ganz zu lesen.

Eine ganz gelesene Datei mit 300+ Zeilen bleibt für den Rest des Threads im Kontext und wird bei
jedem weiteren Schritt erneut mitbezahlt. Blockiert werden:
  - Read ohne offset/limit auf Text-Dateien über GRENZE Zeilen,
  - Bash `cat [-n] <datei>` und `git show <ref>:<datei>` ohne Pipe dahinter auf solche Dateien.
Wer die ganze Datei wirklich braucht, hängt `# ganz` an den Bash-Befehl an.
Exit 2 = blockieren, die Meldung auf stderr bekommt Claude zu sehen.
"""
import json
import os
import re
import shlex
import sys

GRENZE = 300
TEXT = (".gd", ".py", ".json", ".sh", ".md", ".tscn", ".tres", ".gdshader", ".html", ".cfg", ".txt")


def zeilen(pfad):
    try:
        if not pfad.endswith(TEXT) or not os.path.isfile(pfad) or os.path.getsize(pfad) > 20_000_000:
            return 0
        with open(pfad, "rb") as f:
            return sum(1 for _ in f)
    except OSError:
        return 0


def hinweis(pfad, n):
    tipp = "python3 tools/gliederung.py %s (dann --funktion=name oder sed -n a,bp)" % pfad
    if pfad.endswith(".json"):
        tipp = "python3 tools/daten.py %s [pfad] oder --suche=text" % pfad
    elif not pfad.endswith((".gd", ".py")):
        tipp = "grep -n, sed -n a,bp oder Read mit offset/limit"
    return ("%s hat %d Zeilen; ganz gelesen bleibt sie im Kontext und kostet bei jedem weiteren Schritt "
            "Tokens. Stattdessen: %s. Wenn wirklich alles nötig ist: Bash-Befehl mit `# ganz` am Ende oder Read mit limit." % (pfad, n, tipp))


def bash_dateien(cmd):
    """Dateien, die ein Befehl ganz ausgibt (cat oder git show ref:pfad am Ende einer Kette)."""
    treffer = []
    # Abschnitte an ; && || trennen, Pipes innerhalb eines Abschnitts erkennen
    for abschnitt in re.split(r";|&&|\|\||\n", cmd):
        teile = abschnitt.split("|")
        erster = teile[0].strip()
        if len(teile) > 1:
            continue  # gefiltert (head, grep, wc …)
        try:
            w = shlex.split(erster)
        except ValueError:
            continue
        if not w:
            continue
        if w[0] == "cat":
            treffer += [a for a in w[1:] if not a.startswith("-") and not a.startswith(">")]
        elif w[:2] == ["git", "show"]:
            treffer += [a.split(":", 1)[1] for a in w[2:] if ":" in a and not a.startswith("-")]
    return treffer


def main():
    try:
        d = json.load(sys.stdin)
    except ValueError:
        return 0
    tool, inp = d.get("tool_name", ""), d.get("tool_input", {}) or {}
    cwd = d.get("cwd") or os.getcwd()
    kandidaten = []
    if tool == "Read" and not inp.get("offset") and not inp.get("limit"):
        kandidaten = [inp.get("file_path", "")]
    elif tool == "Bash":
        cmd = inp.get("command", "")
        if "# ganz" in cmd or "<<" in cmd:
            return 0
        kandidaten = bash_dateien(cmd)
    for k in kandidaten:
        p = k if os.path.isabs(k) else os.path.join(cwd, k)
        n = zeilen(p)
        if n > GRENZE:
            print(hinweis(k, n), file=sys.stderr)
            return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
