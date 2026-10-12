#!/usr/bin/env python3
"""Entwurf für Release-Notes aus den Commit-Titeln seit dem letzten Build.

Aufruf: python3 tools/release_notes.py <neue Nummer> [--seit=<git-ref>] [--aus=/mnt/project-files/notes]
  <neue Nummer>: z. B. 63 für GemTD_V0_63.zip
  Startpunkt: --seit=<ref>, sonst Tag v0.<N-1> (setzt tools/build_windows.sh), sonst der letzte
  main-Commit vor dem Zeitstempel von builds/GemTD_V0_<N-1>.zip (Näherung für Builds ohne Tag).
Schreibt notes/release_V0.<N>.md als Entwurf, nach Themen gruppiert. Claude glättet danach nur die Sätze.
"""
import datetime
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
BUILDS = pathlib.Path("/mnt/project-files/builds")
GROUPS = [
    ("Mehrspieler und Koop", ["koop", "mehrspieler", "lobby", "netz", "host", "sitzung", "client", "upnp"]),
    ("Balance", ["balance", "schaden", "leben", "rüstung", "gold", "crit", "gift", "nerf", "buff", "kosten", "welle"]),
    ("Grafik", ["grafik", "textur", "licht", "shader", "neon", "modell", "sockel", "grid", "raster", "boden", "skybox"]),
    ("Oberfläche", ["ui", "tooltip", "fenster", "menü", "anzeige", "panel", "liste", "button", "knopf", "leiste", "symbol"]),
    ("Maps und Editor", ["map", "editor", "checkpoint", "wegpunkt", "zone", "bahn"]),
    ("Werkzeuge und Tests", ["test", "tools/", "skript", "build", "claude.md", "readme"]),
]


def git(*args):
    return subprocess.run(["git", "-C", str(ROOT)] + list(args), capture_output=True, text=True).stdout.strip()


def start_ref(n, given):
    if given:
        return given
    tag = "v0.%d" % (n - 1)
    if git("tag", "-l", tag):
        return tag
    zip_ = BUILDS / ("GemTD_V0_%d.zip" % (n - 1))
    if zip_.exists():
        when = datetime.datetime.fromtimestamp(zip_.stat().st_mtime).isoformat()
        ref = git("rev-list", "-1", "--before=" + when, "origin/main") or git("rev-list", "-1", "--before=" + when, "HEAD")
        if ref:
            return ref
    sys.exit("Kein Startpunkt gefunden, bitte --seit=<ref> angeben")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    if not args:
        sys.exit(__doc__)
    n = int(args[0])
    since = start_ref(n, opts.get("seit"))
    subjects = git("log", "--no-merges", "--format=%s", "%s..HEAD" % since).splitlines()
    subjects = [s for s in subjects if s and not s.lower().startswith("merge")]
    buckets = {g: [] for g, _ in GROUPS}
    other = []
    for s in reversed(subjects):
        low = s.lower()
        for g, words in GROUPS:
            if any(w in low for w in words):
                buckets[g].append(s)
                break
        else:
            other.append(s)
    lines = ["Windows-Version: `GemTD_V0_%d.zip` entpacken und `GemTD.exe` starten." % n, "",
             "## Neu seit V0.%d" % (n - 1), "",
             "<!-- Entwurf aus %d Commits (%s..HEAD), bitte in ganze Sätze für Spieler umformulieren -->"
             % (len(subjects), since[:10]), ""]
    for g, _ in GROUPS + [("Sonstiges", [])]:
        items = buckets.get(g, other if g == "Sonstiges" else [])
        if items:
            lines += ["**%s**" % g] + ["- " + i for i in items] + [""]
    out = pathlib.Path(opts.get("aus", "/mnt/project-files/notes"))
    out.mkdir(parents=True, exist_ok=True)
    f = out / ("release_V0.%d.md" % n)
    f.write_text("\n".join(lines), encoding="utf-8")
    print("NOTES", f, "(%d Commits)" % len(subjects))


if __name__ == "__main__":
    main()
