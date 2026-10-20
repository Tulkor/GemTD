"""Zusätzliche Effekte aus dem Brackeys VFX Bundle und dem Kronbits Particle Pack (beide CC0).

Aufruf (Bilder neu aus den entpackten Paketen holen):
  python3 tools/fx/zusatz_effekte.py --brackeys=/pfad/brackeys_vfx_bundle --kronbits=/pfad/Particles
Ohne Pfade werden nur die Effekt-Einträge aus den Bildern im Repo neu geschrieben (läuft auch am Ende
von tools/fx/kenney_effekte.py, damit die Einträge dort nicht verloren gehen).
Schreibt:
  assets/fx/brackeys/*.png  Sprite-Sheets (Explosion, Feuer, Flamme für FlameFx), verkleinert
  assets/fx/kronbits/*.png  einzelne Partikelbilder, verkleinert
  data/fx/hits.json         Treffer bk_* und kb_* (ersetzt nur diese, alle anderen bleiben)
Die Treffer stehen auf "auto": false, die Farbwahl der GemTD-Tower bleibt also gleich. Gewählt werden sie
über "hit_fx" in den Tower-Daten oder über die Regel "hit_ability" in data/fx/shots.json (Splash = Explosion).
"""
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from kenney_effekte import burst, fade, hex_rgb, hue_sat, layer, ramp, rgba, TURN  # noqa: E402

REPO = os.path.dirname(os.path.dirname(HERE))
BK = os.path.join(REPO, "assets", "fx", "brackeys")
KB = os.path.join(REPO, "assets", "fx", "kronbits")
QUELLE = "Brackeys VFX Bundle (Flipbooks von Thomas Iché) und Kronbits Particle Pack, beide CC0; tools/fx/zusatz_effekte.py"

# Ziel -> (Datei im Paket, Breite, Höhe)
BRACKEYS = {
	"flame_01": ("flipbooks/flame_01_16x4.tga", 768, 384),
	"explosion_01": ("flipbooks/explosion_01_8x8.tga", 448, 448),
	"fire_02": ("flipbooks/fire_02_8x8.tga", 384, 384),
}
KRONBITS = {
	"impact_14": "Complex/impacts/impact_14.png",
	"impact_2": "Complex/impacts/impact_2.png",
	"flare_24": "Complex/flare/flare_24.png",
	"flare_13": "Complex/flare/flare_13.png",
	"lightrays_1": "Complex/others/lightrays_1.png",
}


def find(root, rel):
	for d, _, files in os.walk(root):
		if "__MACOSX" in d:
			continue
		p = os.path.join(d, os.path.basename(rel))
		if os.path.basename(rel) in files and d.replace("\\", "/").endswith(os.path.dirname(rel)):
			return p
	raise SystemExit("nicht gefunden: " + rel)


def copy_brackeys(root):
	os.makedirs(BK, exist_ok=True)
	for name, (rel, w, h) in BRACKEYS.items():
		im = Image.open(find(root, rel))
		if im.mode != "RGBA":
			# Feuer ohne Alphakanal: Helligkeit als Deckkraft (wird ohnehin addiert)
			rgb = np.asarray(im.convert("RGB")).astype(np.float32)
			a = rgb.max(axis=2)
			out = np.dstack([rgb, a]).astype(np.uint8)
			im = Image.fromarray(out, "RGBA")
		im = im.resize((w, h), Image.LANCZOS)
		im.save(os.path.join(BK, name + ".png"), optimize=True)
		print("Brackeys", name, os.path.getsize(os.path.join(BK, name + ".png")) // 1024, "KB")


def copy_kronbits(root):
	os.makedirs(KB, exist_ok=True)
	for name, rel in KRONBITS.items():
		im = Image.open(find(root, rel)).convert("RGBA").resize((256, 256), Image.LANCZOS)
		im.save(os.path.join(KB, name + ".png"), optimize=True)
		print("Kronbits", name)


BK_TEX = "res://assets/fx/brackeys/%s.png"
KB_TEX = "res://assets/fx/kronbits/%s.png"
def lay(name, tex, col, **kw):
	"""Ebene mit eigenem Bild (voller res://-Pfad) statt eines Kenney-Bildes."""
	l = layer(name, "", col, **kw)
	l["tex"] = tex
	return l


FLIP = {"tiles": [8, 8], "frames": ramp(0.0, 1.0, n=2)}
# explosion_01 heißt im Paket „8x8“, das Bild hat aber 5×5 Bilder. Nur bis zum Rauch (knapp die Hälfte) abspielen:
# der dunkle Qualm wirkt auf dem dunklen Spielfeld wie ein Loch.
FLIP_EXPLOSION = {"tiles": [5, 5], "frames": ramp(0.0, 0.45, n=2)}


def t_explosion(c):
	return [
		lay("blitz", KB_TEX % "flare_24", rgba(c, 1, 0.5), life=[0.14, 0.14], size=[2.2, 2.2],
			rotation=TURN, size_curve=ramp(0.6, 1.2)),
		lay("feuerball", BK_TEX % "explosion_01", [1.0, 1.0, 1.0, 1.0], add=False, tint=[1.0, 1.0, 1.0, 1.0],
			life=[0.5, 0.5], size=[2.2, 2.2], rotation=TURN, color_curve=fade(hold=0.45), **FLIP_EXPLOSION),
		lay("ring", KB_TEX % "impact_2", rgba(c, 0.8, 0.2), life=[0.3, 0.3], size=[2.4, 2.4],
			size_curve=ramp(0.2, 1.0, ease=0.5), color_curve=fade(hold=0.05)),
	]


def t_fire(c):
	return [
		lay("feuer", BK_TEX % "fire_02", [1.0, 1.0, 1.0, 1.0], tint=[1.4, 1.4, 1.4, 1.0], bursts=burst(2),
			life=[0.45, 0.55], size=[1.6, 2.0], rotation=[-0.3, 0.3], size_curve=ramp(0.6, 1.2, ease=0.6),
			color_curve=fade(hold=0.4), start_frame=[0.0, 20.0], **FLIP),
		layer("glut", "star_04", rgba(c, 1, 0.3), bursts=burst(6), life=[0.35, 0.55], speed=[1.5, 3.0],
			size=[0.22, 0.35], gravity=-0.2, size_curve=ramp(1.0, 0.0),
			shape={"type": "sphere", "radius": 0.2, "thickness": 1.0}, drag=0.2, max_speed=0.8),
	]


def t_shock_ring(c):
	return [
		lay("ring", KB_TEX % "impact_14", rgba(c, 1, 0.2), life=[0.32, 0.32], size=[2.2, 2.2],
			rotation=TURN, spin=[2.0, 2.0], size_curve=ramp(0.3, 1.1, ease=0.5), color_curve=fade(hold=0.1)),
		lay("blitz", KB_TEX % "flare_13", rgba(c, 1, 0.6), life=[0.18, 0.18], size=[1.8, 1.8],
			rotation=TURN, size_curve=ramp(1.2, 0.5)),
	]


def t_splash(c):
	"""Splash ohne Feuer: Druckwelle, heller Kern, Tropfen fliegen weg und fallen (Wasser; gedreht auch Magie usw.)."""
	return [
		lay("welle", KB_TEX % "impact_2", rgba(c, 0.9, 0.2), life=[0.34, 0.34], size=[2.2, 2.2],
			size_curve=ramp(0.2, 1.0, ease=0.5), color_curve=fade(hold=0.05)),
		lay("kern", KB_TEX % "flare_13", rgba(c, 1, 0.6), life=[0.16, 0.16], size=[1.5, 1.5],
			rotation=TURN, size_curve=ramp(1.1, 0.5)),
		layer("tropfen", "circle_05", rgba(c, 1, 0.4), mode="stretch", length_scale=1.6, velocity_scale=0.04,
			bursts=burst(12), life=[0.3, 0.45], speed=[2.5, 4.5], size=[0.22, 0.32], gravity=0.9,
			size_curve=ramp(1.0, 0.4), shape={"type": "sphere", "radius": 0.2, "thickness": 1.0}, drag=0.1),
		layer("gischt", "light_01", rgba(c, 0.6, 0.3), life=[0.3, 0.3], size=[1.6, 1.6],
			size_curve=ramp(0.6, 1.2, ease=0.5), color_curve=fade(hold=0.1)),
	]


def t_rays(c):
	return [
		lay("strahlen", KB_TEX % "lightrays_1", rgba(c, 1, 0.3), life=[0.4, 0.4], size=[2.4, 2.4],
			rotation=TURN, spin=[1.2, 1.2], size_curve=ramp(0.5, 1.1, ease=0.5), color_curve=fade(hold=0.2)),
		lay("kern", KB_TEX % "flare_24", rgba(c, 1, 0.6), life=[0.22, 0.22], size=[1.4, 1.4],
			size_curve=ramp(1.2, 0.4)),
	]


# (id, Vorlage, Farbe)
HITS = [
	("bk_explosion", t_explosion, "#ff8a2a"),
	("bk_fire", t_fire, "#ff6a1e"),
	("kb_shock_ring", t_shock_ring, "#7fb2ff"),
	("kb_nature_rays", t_rays, "#7aff5a"),
	("kb_magic_ring", t_shock_ring, "#c46bff"),
	("kb_splash", t_splash, "#3ab8ff"),
]


def build():
	effects = {}
	for fid, tmpl, col in HITS:
		layers = tmpl(hex_rgb(col))
		hue, sat = hue_sat(col)
		length = max(l["delay"] + l["duration"] + l["life"][1] for l in layers)
		effects[fid] = {"name": fid, "color": col, "hue": hue, "saturation": sat, "auto": False,
			"length": round(length, 2), "quelle": QUELLE, "layers": layers}
	return effects


def main(argv):
	for a in argv:
		if a.startswith("--brackeys="):
			copy_brackeys(a.split("=", 1)[1])
		elif a.startswith("--kronbits="):
			copy_kronbits(a.split("=", 1)[1])
	path = os.path.join(REPO, "data", "fx", "hits.json")
	with open(path, encoding="utf-8") as f:
		hits = json.load(f)
	eff = {k: v for k, v in hits["effects"].items() if not k.startswith(("bk_", "kb_"))}
	eff.update(build())
	hits["effects"] = eff
	with open(path, "w", encoding="utf-8") as f:
		json.dump(hits, f, ensure_ascii=False, indent="\t")
		f.write("\n")
	print("Zusatz-Treffer:", ", ".join(k for k in eff if k.startswith(("bk_", "kb_"))))


if __name__ == "__main__":
	main(sys.argv[1:])
