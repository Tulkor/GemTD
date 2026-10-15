#!/usr/bin/env python3
"""Git-Merge-Treiber für JSON-Dateien, die ein flaches Wörterbuch sind (data/i18n/en.json).

Zwei Branches tragen fast immer verschiedene neue Übersetzungen am Ende ein; Git meldet dann einen
Konflikt, obwohl sich nichts widerspricht. Dieser Treiber führt die Schlüssel zusammen:
neue Schlüssel beider Seiten bleiben (die von main hinter ihrem Vorgänger), gelöschte fallen weg,
geänderte Werte gewinnen gegenüber unveränderten. Nur wenn beide Seiten denselben Schlüssel
verschieden ändern, bleibt ein echter Konflikt: Exit 1, die Datei behält dort unsere Werte und die
Ausgabe nennt die Schlüssel mit beiden Werten.

Eingerichtet über .gitattributes (merge=json_schluessel) und
  git config merge.json_schluessel.driver "python3 tools/git-hooks/json_merge.py %O %A %B %P"
(macht der Session-Start-Hook und tools/main_nachziehen.sh). Aufruf durch Git: basis unsere ihre [pfad]
"""
import json
import sys


def load(path):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    return json.loads(text) if text.strip() else {}


def main():
    base_p, ours_p, theirs_p = sys.argv[1:4]
    name = sys.argv[4] if len(sys.argv) > 4 else ours_p
    try:
        base, ours, theirs = load(base_p), load(ours_p), load(theirs_p)
    except ValueError as e:
        print("json_merge: %s nicht lesbar (%s), normaler Merge nötig" % (name, e), file=sys.stderr)
        return 1
    if not all(isinstance(d, dict) for d in (base, ours, theirs)):
        return 1
    missing = object()
    result = {}
    conflicts = []
    # Reihenfolge: unsere Datei, neue Schlüssel von "ihre" hinter ihrem Vorgänger dort.
    order = list(ours.keys())
    prev = None
    for k in theirs:
        if k not in ours and k not in base:
            pos = order.index(prev) + 1 if prev in order else len(order)
            order.insert(pos, k)
        prev = k
    for k in order + [k for k in theirs if k not in order]:
        b, o, t = base.get(k, missing), ours.get(k, missing), theirs.get(k, missing)
        if o == t:
            v = o
        elif o == b:
            v = t
        elif t == b:
            v = o
        else:
            conflicts.append(k)
            v = o
        if v is not missing and k not in result:
            result[k] = v
    with open(ours_p, "w", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(result, indent="\t", ensure_ascii=False) + "\n")
    if conflicts:
        print("json_merge: %s: %d Schlüssel auf beiden Seiten verschieden geändert, unsere Werte behalten:"
              % (name, len(conflicts)), file=sys.stderr)
        for k in conflicts:
            print("  %r: unsere %r, ihre %r" % (k, ours.get(k), theirs.get(k)), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
