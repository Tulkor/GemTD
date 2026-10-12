#!/usr/bin/env python3
"""Balance-Bericht: Endstufen aller Tower gegen Boden, Masse, Boss und Luft, optional mit Vorher/Nachher.

Aufruf: python3 tools/balance_bericht.py [--welle=45] [--luft=44] [--laeufe=1] [--tower=ruby:5,opal:5]
                                         [--sortieren=boss|normal|masse|luft] [--vergleich=<git-ref>]
                                         [--aus=/mnt/project-files/balance] [--name=bericht]
Misst mit tests/late_balance_test.tscn (je Tower allein an der ersten Ecke der klassischen Map):
  Normal = Welle wie in der Datei, Masse = gleiche HP auf 30 Gegner, Boss = gleiche HP in einem Gegner,
  Luft = Flugwelle. Platten (Fallen): Mittel aus 3 und 5 Überquerungen (Bodengegner), wie im Balance-Thread.
Werte: Schaden in Tausend, in Klammern der Platz. Mit --vergleich=main wird derselbe Lauf auf diesem
Git-Stand wiederholt (eigener Worktree) und die Änderung in % daneben geschrieben.
Schreibt <name>.md und <name>.html (Arcade-Stil, zum Verschicken) und gibt die Pfade aus.
"""
import html
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
GODOT = os.environ.get("GODOT", str(pathlib.Path.home() / ".local/bin/godot"))
COLS = [("boss", "Boss"), ("normal", "Normal"), ("masse", "Masse"), ("luft", "Luft")]
UTILITY = {"slow": "Slow", "slow_aura": "Slow", "stun": "Stun", "armor_reduce": "Rüstung", "armor_aura": "Rüstung",
           "gold_on_hit": "Gold", "damage_aura": "Schadens-Aura", "speed_aura": "Tempo-Aura"}


def opts():
    o = {"welle": "45", "luft": "44", "laeufe": "1", "sortieren": "boss", "aus": "/mnt/project-files/balance",
         "name": "bericht"}
    for a in sys.argv[1:]:
        if a.startswith("--") and "=" in a:
            k, v = a[2:].split("=", 1)
            o[k] = v
    return o


def towers(root):
    out = {}
    for f in sorted((root / "data" / "towers").glob("*.json")):
        d = json.loads(f.read_text(encoding="utf-8"))
        out[d["id"]] = d
    return out


def run(root, args):
    """late_balance_test ausführen, Zeilen 'id:stufe w1 w2 ...' als Dict zurückgeben."""
    if not (root / ".godot" / "imported").is_dir():
        subprocess.run([GODOT, "--headless", "--import", "--path", str(root)], capture_output=True)
    r = subprocess.run([GODOT, "--headless", "--fixed-fps", "60", "--path", str(root),
                        "res://tests/late_balance_test.tscn", "--", "--absolute"] + args,
                       capture_output=True, text=True, timeout=7200)
    res = {}
    for line in r.stdout.splitlines():
        m = re.match(r"^(\w+:\d+)\s+([-\d.\s]+)$", line.strip())
        if m:
            res[m.group(1)] = [float(x) for x in m.group(2).split()]
    if not res:
        sys.exit("Keine Messwerte, Ausgabe:\n" + (r.stdout + r.stderr)[-2000:])
    return res


def measure(root, o):
    tw = towers(root)
    if "tower" in o:
        configs = o["tower"].split(",")
    else:
        configs = ["%s:%d" % (i, len(t["tiers"]) - 1) for i, t in tw.items()]
    traps = [c for c in configs if tw.get(c.split(":")[0], {}).get("kind") == "trap"]
    normal = [c for c in configs if c not in traps]
    w, air, n = o["welle"], o["luft"], int(o["laeufe"])
    data = {c: {k: 0.0 for k, _ in COLS} for c in configs}

    def add(cfgs, extra, passes_list):
        if not cfgs:
            return
        weight = 1.0 / (n * len(passes_list))
        for _ in range(n):
            for passes in passes_list:
                tower_args = ["--tower=" + c for c in cfgs]
                g = run(root, tower_args + ["--waves=" + w, "--scenarios=normal,mass,boss", "--trap-passes=%d" % passes] + extra)
                a = run(root, tower_args + ["--waves=" + air, "--scenarios=normal", "--trap-passes=1"] + extra)
                for c in cfgs:
                    vals = g.get(c, [0, 0, 0])
                    data[c]["normal"] += vals[0] * weight
                    data[c]["masse"] += vals[1] * weight
                    data[c]["boss"] += vals[2] * weight
                    data[c]["luft"] += a.get(c, [0])[0] * weight

    add(normal, [], [1])
    add(traps, [], [3, 5])
    return data, tw


def name_of(tw, cfg):
    tid, tier = cfg.split(":")
    t = tw.get(tid, {})
    tiers = t.get("tiers", [])
    tier = int(tier)
    base = t.get("name", tid)
    if t.get("category", "gem") == "gem":
        return "%s (%s)" % (base, ["Splitter", "Fehlerhaft", "Normal", "Makellos", "Perfekt", "Groß"][tier])
    label = tiers[tier].get("name", base) if tier < len(tiers) else base
    return label + (" (Falle)" if t.get("kind") == "trap" else "")


def utility(tw, cfg):
    tid, tier = cfg.split(":")
    tiers = tw.get(tid, {}).get("tiers", [])
    abil = tiers[int(tier)].get("abilities", []) if int(tier) < len(tiers) else []
    return ", ".join(sorted({UTILITY[a["type"]] for a in abil if a.get("type") in UTILITY})) or "–"


def fmt(x):
    return ("%.2f" % x if x < 2 else "%.1f" % x).replace(".", ",")


def main():
    o = opts()
    data, tw = measure(ROOT, o)
    before = None
    if "vergleich" in o:
        tmp = pathlib.Path(tempfile.mkdtemp(prefix="gemtd-vergleich-"))
        subprocess.run(["git", "-C", str(ROOT), "worktree", "add", "--detach", str(tmp), o["vergleich"]],
                       check=True, capture_output=True)
        try:
            before, _ = measure(tmp, o)
        finally:
            subprocess.run(["git", "-C", str(ROOT), "worktree", "remove", "--force", str(tmp)], capture_output=True)
    ranks = {}
    for k, _ in COLS:
        order = sorted(data, key=lambda c: -data[c][k])
        ranks[k] = {c: i + 1 for i, c in enumerate(order)}
    key = {"boss": "boss", "normal": "normal", "masse": "masse", "luft": "luft"}.get(o["sortieren"], "boss")
    rows = sorted(data, key=lambda c: -data[c][key])

    def cell(c, k):
        s = "%s (%d)" % (fmt(data[c][k]), ranks[k][c])
        if before and c in before and before[c][k] > 0:
            d = 100.0 * (data[c][k] / before[c][k] - 1)
            if abs(d) >= 0.5:
                s += " %+.0f %%" % d
        return s

    head = ["Tower"] + [t for _, t in COLS] + ["Utility"]
    md = ["# Balance-Bericht: Endstufen", "",
          "Welle %s (Normal, Masse, Boss) und Welle %s (Luft). Schaden in Tausend, in Klammern der Platz, "
          "sortiert nach %s. Mittel aus %s Lauf/Läufen; Platten aus 3 und 5 Überquerungen."
          % (o["welle"], o["luft"], dict(COLS)[key], o["laeufe"]),
          "" if not before else "Änderung in %% gegenüber `%s` hinter dem Wert (ab 0,5 %%)." % o["vergleich"], "",
          "| " + " | ".join(head) + " |", "|---|" + "---:|" * len(COLS) + "---|"]
    for c in rows:
        md.append("| %s | %s | %s |" % (name_of(tw, c), " | ".join(cell(c, k) for k, _ in COLS), utility(tw, c)))
    out = pathlib.Path(o["aus"])
    out.mkdir(parents=True, exist_ok=True)
    (out / (o["name"] + ".md")).write_text("\n".join(md) + "\n", encoding="utf-8")
    # HTML im Arcade-Stil zum Verschicken
    trs = "".join("<tr><td>%s</td>%s<td class=u>%s</td></tr>" % (
        html.escape(name_of(tw, c)), "".join("<td class=n>%s</td>" % html.escape(cell(c, k)) for k, _ in COLS),
        html.escape(utility(tw, c))) for c in rows)
    page = """<!doctype html><meta charset=utf-8><title>GemTD Balance</title>
<!-- Farben aus scripts/ui/ui_theme.gd (BG, PANEL, TEXT, MUTED, GOLD, CYAN, COIN) -->
<style>body{background:#07040e;color:#f2eaff;font:14px 'DejaVu Sans Mono',monospace;margin:24px}
h1{color:#ff4fd8;text-shadow:3px 3px 0 #22c4ee;text-transform:uppercase}
.p{border:3px solid #ff4fd8;box-shadow:6px 6px 0 #22c4ee;background:#0d0618;padding:12px;display:inline-block;max-width:100%%;overflow-x:auto}
table{border-collapse:collapse}td,th{padding:4px 10px;border-bottom:1px solid #160b28;text-align:left}
th{color:#22c4ee;text-transform:uppercase}.n{text-align:right;color:#ffd166}.u{color:#a99cc8}p{color:#a99cc8}</style>
<h1>Balance: Endstufen</h1><p>%s</p><div class=p><table><tr>%s</tr>%s</table></div>""" % (
        html.escape(md[2] + " " + md[3]), "".join("<th>%s</th>" % h for h in head), trs)
    (out / (o["name"] + ".html")).write_text(page, encoding="utf-8")
    print("BERICHT", out / (o["name"] + ".md"), out / (o["name"] + ".html"), "(%d Tower)" % len(rows))


if __name__ == "__main__":
    main()
