#!/usr/bin/env python3
"""Echte Marken in Shopping Maul leicht umbenennen (Release, Lukas 2026-10-26).

Die Originalkarte nennt Filialen und Tower nach echten Marken (Aldi, Mc Donalds, Porsche …). Im Spiel
stehen stattdessen erkennbare Abwandlungen (Oldi, Mc Donuts, Borsche …). Interne IDs bleiben gleich.

  python3 tools/wc3/maul_namen.py           # data/maul/shops.json und pro.json umbenennen
  python3 tools/wc3/maul_namen.py --pruefe  # nur melden, ob noch alte Namen drinstehen (Exit 1)

maul_daten.py wendet umbenennen() beim Erzeugen von shops.json selbst an.
"""
import json
import os
import re
import sys

# (alt, neu), längere zuerst. Ersetzt wird nur an Wortgrenzen und mit gleicher Groß-/Kleinschreibung.
MARKEN = [
    ("Ronald McDonald", "Ronald Mc Donut"),
    ("Mc Donalds", "Mc Donuts"),
    ("McFlurry", "Mc Slurry"),
    ("Big Mac", "Big Mäc"),
    ("Happy Meal", "Happy Mahl"),
    ("Burger King", "Burger Queen"),
    ("Media Markt", "Medio Markt"),
    ("Obi Baumarkt", "Obo Baumarkt"),
    ("H&M", "H&N"),
    ("Aldi", "Oldi"),
    ("Porsche", "Borsche"),
    ("Cayenne Turbo S", "Kajenne Turbo S"),
    ("Boxster S", "Boxxer S"),
    ("Carrera GT", "Karrera GT"),
    ("Deutsche Bank", "Teutsche Bank"),
    ("Aral", "Arol"),
    ("Beate Uhse", "Beate Muhse"),
    ("CinemaxX", "CineMoxx"),
    ("TUI", "TOI"),
    ("AOK", "AOX"),
    ("IKEA", "IKEO"),
    ("Aibo", "Aibot"),
    ("Hugo Boss", "Hugo Bass"),
    ("Giorgio Armani", "Giorgio Armoni"),
    ("Doc Morris", "Doc Moritz"),
    ("Pippi Langstrumpf", "Pippa Kniestrumpf"),
    ("Pippi Longstocking", "Pippa Kneesock"),
]

# Filmfiguren und echte Personen: Lukas will sie vorerst behalten (2026-10-26), deshalb nicht in PAARE.
FIGUREN = [
    ("Shrek", "Shrok"),
    ("Private Ryan", "Private Brian"),
    ("Jacky Chan", "Jacky Chen"),
    ("Judge Dredd", "Judge Dread"),
    ("Terminator", "Terminater"),
    ("Darth Vader", "Darth Wader"),
    ("Hellboy", "Hellbaby"),
    ("Sauron", "Saurom"),
    ("The Godfather", "The Godfatter"),
    ("Wolverine", "Wolverin"),
    ("John McClane", "John McClean"),
    ("Robocop", "Robocob"),
    ("Tim Taylor And Al Borland", "Tim Tayler And Al Boreland"),
    ("President Bush", "President Busch"),
    ("Ben Johnson", "Ben Jonson"),
    ("Tyler Hamilton", "Tyler Hamiltan"),
    ("Floud Landis", "Floyd Landes"),
    ("Jan Ullrich", "Jan Ulrik"),
]

# Ganze Namen, die als Wort zu allgemein sind (z. B. {"Ent": "Tree Herder"}, falls FIGUREN dazukommen)
GANZE_NAMEN = {}

PAARE = MARKEN
_MUSTER = [(re.compile(r"(?<![\w&])" + re.escape(alt) + r"(?![\w&])"), neu) for alt, neu in PAARE]


def umbenennen(text: str) -> str:
    if text in GANZE_NAMEN:
        return GANZE_NAMEN[text]
    for m, neu in _MUSTER:
        text = m.sub(neu, text)
    return text


def alt_gefunden(text: str) -> list:
    return [alt for (alt, _), (m, _) in zip(PAARE, _MUSTER) if m.search(text)]


def anwenden(x):
    """Alle Texte in einer JSON-Struktur umbenennen (Schlüssel bleiben)."""
    if isinstance(x, str):
        return umbenennen(x)
    if isinstance(x, list):
        return [anwenden(v) for v in x]
    if isinstance(x, dict):
        return {k: anwenden(v) for k, v in x.items()}
    return x


def main():
    repo = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    pruefe = "--pruefe" in sys.argv
    rest = False
    for name in ("shops.json", "pro.json"):
        p = os.path.join(repo, "data", "maul", name)
        roh = open(p, encoding="utf-8").read()
        if pruefe:
            alt = alt_gefunden(roh)
            if alt:
                print("%s: noch %s" % (name, ", ".join(alt)))
                rest = True
            continue
        # als Text ersetzen, damit die Formatierung (pro.json von Hand) bleibt
        neu = roh
        for ganz, ersatz in GANZE_NAMEN.items():
            neu = neu.replace('"%s"' % ganz, '"%s"' % ersatz)
        for m, ersatz in _MUSTER:
            neu = m.sub(ersatz, neu)
        json.loads(neu)
        open(p, "w", encoding="utf-8").write(neu)
        print("%s umbenannt" % name)
    if pruefe:
        print("alte Namen gefunden" if rest else "keine alten Namen mehr")
        sys.exit(1 if rest else 0)


if __name__ == "__main__":
    main()
