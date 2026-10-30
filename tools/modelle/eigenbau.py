#!/usr/bin/env python3
"""Selbst gebaute Low-Poly-Modelle für Tower ohne freies Modell (eigene Arbeit, CC0).

Jedes Modell ist eine Funktion aus einfachen Formen (Quader, Zylinder, Kegel, Kugel, Ring) mit Grundfarben,
gebaut mit Z nach oben und beim Speichern auf Y nach oben gedreht. Ziel: assets/models/pakete/eigen/<name>.glb,
danach wie alle Bibliotheksmodelle über data/tower_models.json und tools/modelle/tower_modelle.py ins Spiel.

    python3 -I tools/modelle/eigenbau.py [--nur=waage,rakete]

Braucht trimesh und scipy (pip install trimesh scipy).
"""
import math
import os
import sys
import tempfile

import numpy as np
import trimesh
from trimesh import creation as cr
from trimesh import transformations as tf

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from umwandeln import ROOT, pack_gltf  # noqa: E402

ZIEL = os.path.join(ROOT, "assets", "models", "pakete", "eigen")

FARBEN = {
    "messing": (0.78, 0.58, 0.22), "messing_dunkel": (0.45, 0.32, 0.12), "holz": (0.45, 0.28, 0.14),
    "holz_hell": (0.68, 0.48, 0.28), "stein": (0.42, 0.40, 0.38), "metall": (0.55, 0.57, 0.60),
    "metall_dunkel": (0.22, 0.23, 0.26), "rot": (0.80, 0.12, 0.10), "weiss": (0.92, 0.92, 0.90),
    "gelb": (0.95, 0.75, 0.10), "schwarz": (0.06, 0.06, 0.07), "lila": (0.20, 0.06, 0.28),
    "lila_hell": (0.45, 0.18, 0.60), "auge": (1.0, 0.85, 0.20), "wasser": (0.20, 0.45, 0.75),
    "nebel": (0.85, 0.88, 0.92), "seil": (0.80, 0.70, 0.50), "gummi": (0.55, 0.10, 0.10),
    "kupfer": (0.72, 0.40, 0.20), "haut": (0.85, 0.60, 0.45), "haar": (0.35, 0.18, 0.08),
    "trikot": (0.85, 0.15, 0.55), "trikot_rock": (0.95, 0.75, 0.90), "blitz": (0.55, 0.85, 1.00), "gruen": (0.15, 0.55, 0.25),
}
EMISSION = {"auge": 1.0, "blitz": 1.2}
ALPHA = {"wasser": 0.75, "nebel": 0.6}


class Bau:
    def __init__(self):
        self.teile = []

    def add(self, mesh, farbe, at=(0, 0, 0)):
        mesh = mesh.copy()
        mesh.apply_translation(at)
        self.teile.append((mesh, farbe))
        return mesh

    def box(self, size, farbe, at=(0, 0, 0), rot=None):
        m = cr.box(extents=size)
        if rot is not None:
            m.apply_transform(rot)
        return self.add(m, farbe, at)

    def zyl(self, r, h, farbe, at=(0, 0, 0), seiten=8, rot=None):
        m = cr.cylinder(radius=r, height=h, sections=seiten)
        if rot is not None:
            m.apply_transform(rot)
        return self.add(m, farbe, at)

    def kegel(self, r, h, farbe, at=(0, 0, 0), seiten=8, rot=None):
        m = cr.cone(radius=r, height=h, sections=seiten)
        if rot is not None:
            m.apply_transform(rot)
        return self.add(m, farbe, at)

    def kugel(self, r, farbe, at=(0, 0, 0), stufe=1, skal=(1, 1, 1)):
        m = cr.icosphere(subdivisions=stufe, radius=r)
        m.apply_scale(skal)
        return self.add(m, farbe, at)

    def stab(self, a, b, r, farbe, seiten=6):
        """Zylinder von Punkt a nach Punkt b."""
        a, b = np.array(a, float), np.array(b, float)
        m = cr.cylinder(radius=r, segment=[a, b], sections=seiten)
        return self.add(m, farbe)

    def ring(self, r, dicke, farbe, at=(0, 0, 0), rot=None):
        m = cr.torus(major_radius=r, minor_radius=dicke, major_sections=12, minor_sections=6)
        if rot is not None:
            m.apply_transform(rot)
        return self.add(m, farbe, at)

    def speichern(self, name):
        scene = trimesh.Scene()
        hoch = tf.rotation_matrix(-math.pi / 2, [1, 0, 0])
        for i, (m, farbe) in enumerate(self.teile):
            m = m.copy()
            m.apply_transform(hoch)
            m.unmerge_vertices()  # flache Flächen, kantiger Low-Poly-Look
            c = FARBEN[farbe]
            mat = trimesh.visual.material.PBRMaterial(
                name=farbe, baseColorFactor=[c[0], c[1], c[2], ALPHA.get(farbe, 1.0)], metallicFactor=0.0,
                roughnessFactor=0.8, emissiveFactor=[x * EMISSION[farbe] for x in c] if farbe in EMISSION else None,
                alphaMode="BLEND" if farbe in ALPHA else None)
            m.visual = trimesh.visual.TextureVisuals(material=mat)
            scene.add_geometry(m, node_name="%s_%d" % (farbe, i))
        with tempfile.NamedTemporaryFile(suffix=".glb", delete=False) as f:
            tmp = f.name
        scene.export(tmp, include_normals=True)
        dst = os.path.join(ZIEL, name + ".glb")
        pack_gltf(tmp, dst, 256)
        os.unlink(tmp)
        return dst


def waage(b):  # YouTD Scales
    b.zyl(0.32, 0.08, "stein", (0, 0, 0.04))
    b.zyl(0.05, 1.0, "messing", (0, 0, 0.55))
    b.kugel(0.07, "messing", (0, 0, 1.08))
    b.box((1.0, 0.05, 0.05), "messing", (0, 0, 1.0), rot=tf.rotation_matrix(0.12, [0, 1, 0]))
    for x, z in ((-0.48, 1.06), (0.48, 0.94)):
        for dx, dy in ((0.12, 0), (-0.06, 0.1), (-0.06, -0.1)):
            b.stab((x, 0, z), (x + dx, dy, z - 0.45), 0.008, "messing_dunkel", 4)
        b.zyl(0.17, 0.03, "messing", (x, 0, z - 0.46), seiten=10)


def it(b):  # YouTD „It“: Anspielung auf den Clown aus Stephen Kings Roman, nur Gully und roter Ballon
    b.zyl(0.42, 0.06, "stein", (0, 0, 0.03), seiten=10)
    b.zyl(0.3, 0.03, "metall_dunkel", (0, 0, 0.075), seiten=12)
    b.zyl(0.27, 0.031, "schwarz", (0, 0, 0.076), seiten=12)
    for x in (-0.18, -0.09, 0.0, 0.09, 0.18):
        b.box((0.04, 0.5 - abs(x) * 1.2, 0.035), "metall_dunkel", (x, 0, 0.08))
    b.kugel(0.03, "auge", (-0.05, -0.04, 0.1))
    b.kugel(0.03, "auge", (0.05, -0.04, 0.1))
    b.stab((0.02, 0.06, 0.09), (0.06, 0.04, 0.95), 0.006, "weiss", 4)
    b.kugel(0.2, "rot", (0.06, 0.04, 1.14), stufe=2, skal=(1, 1, 1.18))
    b.kegel(0.035, 0.05, "rot", (0.06, 0.04, 0.9), seiten=6)


def rakete(b):  # YouTD Pocket Rocket
    b.zyl(0.36, 0.06, "metall_dunkel", (0, 0, 0.03), seiten=6)
    b.zyl(0.16, 0.9, "weiss", (0, 0, 0.6), seiten=10)
    b.zyl(0.165, 0.12, "rot", (0, 0, 0.75), seiten=10)
    b.kegel(0.16, 0.36, "rot", (0, 0, 1.05), seiten=10)
    b.zyl(0.05, 0.03, "blitz", (0, -0.155, 0.85), seiten=8, rot=tf.rotation_matrix(math.pi / 2, [1, 0, 0]))
    for i in range(3):
        w = i * 2 * math.pi / 3
        rot = tf.rotation_matrix(w, [0, 0, 1])
        fin = cr.box(extents=(0.2, 0.03, 0.3))
        fin.apply_transform(tf.rotation_matrix(-0.4, [0, 1, 0]))
        fin.apply_translation((0.22, 0, 0.3))
        fin.apply_transform(rot)
        b.add(fin, "rot")
    b.kegel(0.11, 0.12, "metall", (0, 0, 0.09), seiten=8, rot=tf.rotation_matrix(math.pi, [1, 0, 0]))


def pfuetze(b):  # eeveTD Bremspfütze
    rng = np.random.default_rng(3)
    for i in range(5):
        w = i * 2 * math.pi / 5
        r = 0.22 + rng.random() * 0.12
        b.zyl(r, 0.02, "wasser", (math.cos(w) * 0.2, math.sin(w) * 0.2, 0.01), seiten=10)
    b.zyl(0.3, 0.025, "wasser", (0, 0, 0.012), seiten=12)
    for i in range(4):
        w = i * 1.7
        b.kugel(0.05, "stein", (math.cos(w) * 0.55, math.sin(w) * 0.5, 0.02), skal=(1.2, 1, 0.6))


def blitzfalle(b):  # eeveTD Blitzfalle: Spule auf Bodenplatte
    b.box((0.8, 0.8, 0.06), "metall_dunkel", (0, 0, 0.03))
    b.zyl(0.1, 0.55, "metall", (0, 0, 0.33))
    for z in (0.16, 0.26, 0.36, 0.46):
        b.ring(0.13, 0.025, "kupfer", (0, 0, z))
    b.ring(0.2, 0.05, "metall", (0, 0, 0.66))
    b.kugel(0.09, "blitz", (0, 0, 0.66))
    for x, y in ((0.32, 0.32), (-0.32, 0.32), (0.32, -0.32), (-0.32, -0.32)):
        b.zyl(0.04, 0.12, "kupfer", (x, y, 0.12))


def zapfsaeule(b):  # Shopping Maul Gas Pump
    b.box((0.7, 0.45, 0.08), "stein", (0, 0, 0.04))
    b.box((0.5, 0.32, 0.95), "rot", (0, 0, 0.55))
    b.box((0.52, 0.34, 0.14), "weiss", (0, 0, 1.08))
    b.box((0.34, 0.02, 0.22), "schwarz", (0, -0.17, 0.78))
    b.box((0.26, 0.01, 0.06), "gelb", (0, -0.181, 0.84))
    b.box((0.08, 0.1, 0.16), "metall_dunkel", (0.29, 0, 0.55))
    b.stab((0.3, 0, 0.47), (0.36, -0.1, 0.12), 0.02, "schwarz", 5)
    b.stab((0.36, -0.1, 0.12), (0.3, -0.2, 0.45), 0.02, "schwarz", 5)


def bohrturm(b):  # Shopping Maul Oil Well
    b.box((0.9, 0.9, 0.06), "metall_dunkel", (0, 0, 0.03))
    unten, oben, h = 0.38, 0.08, 1.5
    ecken = [(1, 1), (-1, 1), (-1, -1), (1, -1)]
    for sx, sy in ecken:
        b.stab((sx * unten, sy * unten, 0.06), (sx * oben, sy * oben, h), 0.025, "gelb", 5)
    for k in range(1, 6):
        z0, z1 = 0.06 + (k - 1) * h / 5, 0.06 + k * h / 5
        r0 = unten + (oben - unten) * (k - 1) / 5
        r1 = unten + (oben - unten) * k / 5
        for i in range(4):
            (ax, ay), (bx, by) = ecken[i], ecken[(i + 1) % 4]
            b.stab((ax * r1, ay * r1, z1), (bx * r1, by * r1, z1), 0.012, "gelb", 4)
            b.stab((ax * r0, ay * r0, z0), (bx * r1, by * r1, z1), 0.01, "gelb", 4)
    b.box((0.24, 0.24, 0.08), "metall_dunkel", (0, 0, h + 0.04))
    b.zyl(0.1, 0.3, "metall", (0.25, 0.25, 0.15))
    b.box((0.3, 0.2, 0.2), "schwarz", (-0.25, 0.25, 0.16))


def trapez(b):  # Randgruppen Trapezkünstlerin: Gestell mit Artistin, die an der Stange hängt
    top, bar = 1.75, 1.08
    for x in (-0.55, 0.55):
        b.stab((x - 0.15, 0.2, 0), (x, 0, top), 0.03, "rot", 6)
        b.stab((x - 0.15, -0.2, 0), (x, 0, top), 0.03, "rot", 6)
    b.stab((-0.62, 0, top), (0.62, 0, top), 0.035, "gelb", 6)
    b.stab((-0.22, 0, top), (-0.22, 0, bar), 0.008, "seil", 4)
    b.stab((0.22, 0, top), (0.22, 0, bar), 0.008, "seil", 4)
    b.stab((-0.25, 0, bar), (0.25, 0, bar), 0.022, "holz_hell", 6)
    b.zyl(0.7, 0.03, "rot", (0, 0, 0.015), seiten=12)
    b.zyl(0.5, 0.032, "gelb", (0, 0, 0.017), seiten=12)
    # Artistin: Hände an der Stange, Arme nach oben, Trikot, Beine geschlossen mit gestreckten Füßen
    sh, hip = 0.86, 0.6
    for x in (-0.07, 0.07):
        b.stab((x * 1.3, 0, bar), (x, 0, sh), 0.022, "haut", 5)
        b.kugel(0.025, "haut", (x * 1.3, 0, bar))
    b.kugel(0.085, "haut", (0, 0, sh + 0.05), stufe=2, skal=(0.9, 0.95, 1.05))
    b.kugel(0.09, "haar", (0, 0.025, sh + 0.08), stufe=2, skal=(0.95, 0.9, 1.0))
    b.kugel(0.045, "haar", (0, 0.09, sh + 0.13))
    torso = cr.cylinder(radius=0.075, height=sh - hip, sections=8)
    torso.apply_scale((1.0, 0.7, 1.0))
    b.add(torso, "trikot", (0, 0, (sh + hip) / 2))
    b.kugel(0.08, "trikot", (0, 0, hip), skal=(1.0, 0.75, 0.6))
    b.zyl(0.11, 0.035, "trikot_rock", (0, 0, hip - 0.01), seiten=10)
    for x in (-0.035, 0.035):
        b.stab((x, 0, hip), (x * 0.8, 0.02, hip - 0.28), 0.028, "haut", 5)
        b.stab((x * 0.8, 0.02, hip - 0.28), (x * 0.6, -0.01, hip - 0.52), 0.022, "haut", 5)
        b.kegel(0.022, 0.06, "trikot", (x * 0.6, -0.01, hip - 0.58), seiten=5, rot=tf.rotation_matrix(math.pi, [1, 0, 0]))


def steinschleuder(b):  # Randgruppen Steinschleuder
    b.zyl(0.05, 0.45, "holz", (0, 0, 0.225))
    b.stab((0, 0, 0.44), (-0.18, 0, 0.75), 0.04, "holz", 6)
    b.stab((0, 0, 0.44), (0.18, 0, 0.75), 0.04, "holz", 6)
    b.stab((-0.18, 0, 0.72), (0, 0.25, 0.62), 0.012, "gummi", 4)
    b.stab((0.18, 0, 0.72), (0, 0.25, 0.62), 0.012, "gummi", 4)
    b.box((0.09, 0.05, 0.06), "holz_hell", (0, 0.26, 0.62))
    b.kugel(0.05, "stein", (0, 0.29, 0.64))
    b.zyl(0.2, 0.05, "stein", (0, 0, 0.025), seiten=7)
    for x, y in ((0.22, 0.1), (0.15, -0.2), (-0.2, 0.15)):
        b.kugel(0.05, "stein", (x, y, 0.07))


MODELLE = {
    "waage": waage, "it": it, "rakete": rakete, "pfuetze": pfuetze, "blitzfalle": blitzfalle,
    "zapfsaeule": zapfsaeule, "bohrturm": bohrturm, "trapez": trapez, "steinschleuder": steinschleuder,
}


def main():
    nur = []
    for a in sys.argv[1:]:
        if a.startswith("--nur="):
            nur = a[6:].split(",")
    for name, fn in MODELLE.items():
        if nur and name not in nur:
            continue
        b = Bau()
        fn(b)
        dst = b.speichern(name)
        print("OK", name, os.path.getsize(dst) // 1024, "KB")
    namen = sorted(f[:-4] for f in os.listdir(ZIEL) if f.endswith(".glb"))
    open(os.path.join(ZIEL, "LISTE.txt"), "w").write("\n".join(namen) + "\n")


if __name__ == "__main__":
    main()
