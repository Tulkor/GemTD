"""Tower-Modelle aller Modi: holt die in data/tower_models.json gewählten Modelle aus der Bibliothek
(assets/models/pakete/) nach assets/models/towers/<paket>/ und zeigt, welche Tower noch kein passendes Modell haben.

    python3 -I tools/modelle/tower_modelle.py [--bericht=/mnt/project-files/modelle/tower_ohne_modell.md] [--pruefen]

--pruefen wandelt nichts um, prüft nur Verweise und Abdeckung (Exitcode 1 bei Fehlern).
Danach eeveTD und Randgruppen neu erzeugen (eeve_daten.py, rg_daten.py backen die Modelle in data/towers/);
Shopping Maul und YouTD lesen data/tower_models.json zur Laufzeit.
"""
import glob
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools", "modelle"))
from umwandeln import pack_gltf  # noqa: E402

DATEI = os.path.join(ROOT, "data", "tower_models.json")
PAKETE = os.path.join(ROOT, "assets", "models", "pakete")
ZIEL = os.path.join(ROOT, "assets", "models", "towers")
MODI = {"eeve": "eeveTD", "randgruppen": "Randgruppen TD", "maul": "Shopping Maul", "youtd": "YouTD"}


# Hauttöne für die Quaternius-Figuren (im glTF des Pakets ist "Skin" fast schwarz), linear
HAUT = [[0.80, 0.52, 0.38], [0.62, 0.38, 0.24], [0.36, 0.20, 0.12], [0.86, 0.64, 0.50]]


def fix_for(ref):
    """Farbkorrektur je Paket oder None."""
    paket, name = ref.split("/", 1)
    if paket == "q_figuren":
        def haut(js):
            ton = HAUT[sum(map(ord, name)) % len(HAUT)]
            for m in js.get("materials", []):
                if m.get("name") == "Skin":
                    m.setdefault("pbrMetallicRoughness", {})["baseColorFactor"] = ton + [1.0]
        return haut
    if paket == "q_feldfruechte":
        def heller(js):
            # Farben aus dem OBJ zweimal linearisiert: im Spiel fast schwarz
            for m in js.get("materials", []):
                pbr = m.setdefault("pbrMetallicRoughness", {})
                c = pbr.get("baseColorFactor", [1, 1, 1, 1])
                pbr["baseColorFactor"] = [x ** 0.5 for x in c[:3]] + c[3:]
        return heller
    if paket == "q_fantasy_props":
        def ohne_farben(js):
            # Vertex-Farben sind dort Masken (Unreal-Trim), mit ihnen multipliziert wird alles schwarz
            for m in js.get("meshes", []):
                for p in m["primitives"]:
                    p["attributes"].pop("COLOR_0", None)
        return ohne_farben
    return None


def ref_of(v):
    """Modellverweis eines Eintrags oder None (fehlt, haus, kristall)."""
    if isinstance(v, dict):
        return v.get("m")
    if v in ("haus", "kristall"):
        return None
    return v


def status(v):
    if v is None:
        return "ohne Eintrag"
    if isinstance(v, dict):
        if "fehlt" in v:
            return "fehlt"
        if "not" in v:
            return "Notlösung"
    return {"haus": "Haus", "kristall": "Kristall"}.get(v, "passend") if isinstance(v, str) else "passend"


def res_path(ref):
    """res://-Pfad, unter dem das Spiel das Modell lädt."""
    if ref.startswith("res://"):
        return ref
    return "res://assets/models/towers/%s.glb" % ref


def towers():
    """Alle Tower je Modus: {modus: [(schlüssel, name)]}."""
    out = {"gemtd": [], "eeve": [], "randgruppen": [], "maul": [], "youtd": []}
    for f in sorted(glob.glob(os.path.join(ROOT, "data", "towers", "*.json"))):
        tid = os.path.basename(f)[:-5]
        d = json.load(open(f))
        if tid.startswith("eeve_"):
            out["eeve"].append((tid[5:], d.get("name", tid), d))
        elif tid.startswith("rg_"):
            out["randgruppen"].append((tid[3:], d.get("name", tid), d))
        else:
            out["gemtd"].append((tid, d.get("name", tid), d))
    shops = json.load(open(os.path.join(ROOT, "data", "maul", "shops.json")))
    for s in shops["shops"] + [shops["xpert"]]:
        for t in s["towers"]:
            out["maul"].append((t["id"], "%s (%s)" % (t["name"], s["name"]), t))
    yt = os.path.join(ROOT, "data", "youtd", "towers.json")
    if os.path.exists(yt):
        fam = {}
        for t in json.load(open(yt)).values():
            fam.setdefault(str(t["family"]), []).append(t)
        for k, lst in sorted(fam.items(), key=lambda x: int(x[0])):
            lst.sort(key=lambda t: t.get("tier", 0))
            out["youtd"].append((k, " / ".join(t["name"] for t in lst), {"element": lst[0]["element"], "n": len(lst)}))
    return out


def main():
    pruefen = "--pruefen" in sys.argv
    bericht = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--bericht=")), None)
    cfg = json.load(open(DATEI))
    fehler = []
    gebraucht = set()
    for modus in MODI:
        for k, v in cfg.get(modus, {}).items():
            ref = ref_of(v)
            if not ref:
                continue
            if ref.startswith("res://"):
                if not os.path.exists(os.path.join(ROOT, ref[6:])):
                    fehler.append("%s %s: %s fehlt" % (modus, k, ref))
            elif not os.path.exists(os.path.join(PAKETE, ref + ".glb")):
                fehler.append("%s %s: %s nicht in der Bibliothek" % (modus, k, ref))
            else:
                gebraucht.add(ref)
    neu = 0
    if not pruefen:
        for ref in sorted(gebraucht):
            dst = os.path.join(ZIEL, ref + ".glb")
            if not os.path.exists(dst):
                pack_gltf(os.path.join(PAKETE, ref + ".glb"), dst, 256, anim="idle", fix=fix_for(ref))
                neu += 1
        for f in glob.glob(os.path.join(ZIEL, "*", "*.glb")):
            if os.path.relpath(f, ZIEL)[:-4].replace(os.sep, "/") not in gebraucht:
                for rest in glob.glob(f[:-4] + "_*.png*") + glob.glob(f + ".import"):
                    os.remove(rest)  # beim Godot-Import erzeugte Texturen
                os.remove(f)
                print("entfernt", os.path.relpath(f, ROOT))
    alle = towers()
    zeilen = []
    zahl = {}
    for modus, titel in MODI.items():
        eintraege = cfg.get(modus, {})
        offen = []
        z = {}
        for k, name, d in alle[modus]:
            v = eintraege.get(k)
            st = status(v)
            if modus == "eeve" and v is None and str(d.get("model", "")).find("/crystals/") < 0:
                st = "passend"  # Modell aus LOOK in eeve_daten.py
            z[st] = z.get(st, 0) + 1
            if st in ("fehlt", "Notlösung", "ohne Eintrag", "Kristall", "Haus"):
                grund = v.get("fehlt", v.get("not", "")) if isinstance(v, dict) else ""
                if modus == "youtd":
                    name = "%s (%s, %d Tower)" % (name, d["element"], d["n"])
                offen.append((st, name, grund, k))
        zahl[modus] = z
        zeilen.append("\n## %s\n" % titel)
        zeilen.append(", ".join("%s %d" % kv for kv in sorted(z.items())))
        for st in ("fehlt", "ohne Eintrag", "Notlösung"):
            liste = [o for o in offen if o[0] == st]
            if not liste:
                continue
            zeilen.append("\n**%s** (%d)\n" % (st, len(liste)))
            for _, name, grund, k in liste:
                zeilen.append("- %s%s" % (name, ": " + grund if grund else ""))
        for st, was in (("Kristall", "Kristall in Elementfarbe passt"), ("Haus", "Gebäude passt")):
            liste = [o[1] for o in offen if o[0] == st]
            if liste:
                zeilen.append("\n%s (%d): %s\n" % (was, len(liste), ", ".join(liste)))
    gem = len(alle["gemtd"])
    kopf = ["# Tower ohne passendes Modell", "",
            "Erzeugt von `tools/modelle/tower_modelle.py` aus `data/tower_models.json`. "
            "GemTD: alle %d Tower haben ein Modell (Gems aus dem Crystal Pack, Spezial-Tower eigene)." % gem,
            "**fehlt** = Platzhalter bleibt (Kristall, Haus oder Element-Modell), **Notlösung** = ähnliches Modell statt des richtigen."]
    text = "\n".join(kopf + zeilen) + "\n"
    if bericht:
        os.makedirs(os.path.dirname(bericht), exist_ok=True)
        open(bericht, "w").write(text)
        print("Bericht:", bericht)
    for m, z in zahl.items():
        print("%-12s %s" % (m, ", ".join("%s %d" % kv for kv in sorted(z.items()))))
    print("%d Modelle aus der Bibliothek, %d neu umgewandelt" % (len(gebraucht), neu))
    for f in fehler:
        print("FEHLER", f)
    return 1 if fehler else 0


if __name__ == "__main__":
    sys.exit(main())
