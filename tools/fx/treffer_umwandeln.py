"""Wandelt die Unity-Treffer-Effekte (FX_Hit_Collection.unitypackage) in Daten für Godot um.

  tar xzf FX_Hit_Collection.unitypackage -C <leerer_ordner>
  python3 -I tools/fx/treffer_umwandeln.py <leerer_ordner>

Schreibt data/fx/hits.json (ein Eintrag pro Prefab, Ebenen = Unity-Partikelsysteme) und kopiert die
benutzten Texturen nach assets/fx/hit/ (TGA wird PNG). Gespielt werden die Daten von
scripts/game/fx_player.gd. Nicht übernommen: Rauschen, Kraftfelder, Unterbemitter, Trails.

Unity schaut in der Vorschau-Szene von vorne (Kamera bei z = -10, Blick nach +z). Die Positionen
bleiben in diesem Kamera-Raum (x rechts, y oben, z vom Betrachter weg); das Spiel legt den Effekt
später in den Raum der Spielkamera, damit er so aussieht wie in der Vorlage.
"""
import colorsys
import json
import math
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import unity_lesen as ul  # noqa: E402

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TEX_ZIEL = "assets/fx/hit"
SAMPLES = 12

# Unity-Standard-Shader (fileID im Built-in-Paket) -> additiv?
ADDITIV = {200: True, 201: True, 202: True, 203: False, 10720: True, 10721: False}
SHADER_DATEI_ADDITIV = {"Particle AddSmooth.shader": True, "ParticleBlend.shader": False,
	"Mobile-Particle-Alpha.shader": False, "FX_Diffuse.shader": False}
SHAPE = {0: "sphere", 1: "sphere", 2: "sphere", 3: "sphere", 4: "cone", 7: "cone", 8: "cone", 9: "cone", 10: "circle", 11: "circle"}


# --- Kurven -----------------------------------------------------------------

def _hermite(k0, k1, t):
	dt = k1["time"] - k0["time"]
	if dt <= 0:
		return k1["value"]
	s = (t - k0["time"]) / dt
	m0, m1 = k0.get("outSlope", 0), k1.get("inSlope", 0)
	if not (math.isfinite(m0) and math.isfinite(m1)):
		return k0["value"]
	m0 *= dt
	m1 *= dt
	s2, s3 = s * s, s * s * s
	return (2 * s3 - 3 * s2 + 1) * k0["value"] + (s3 - 2 * s2 + s) * m0 + (-2 * s3 + 3 * s2) * k1["value"] + (s3 - s2) * m1


def kurve(c, t):
	keys = c.get("m_Curve") or []
	if not keys:
		return 0.0
	if t <= keys[0]["time"]:
		return keys[0]["value"]
	for k0, k1 in zip(keys, keys[1:]):
		if t <= k1["time"]:
			return _hermite(k0, k1, t)
	return keys[-1]["value"]


def minmax_bereich(mm, t=0.0):
	"""[min, max] eines MinMaxCurve-Werts zum Zeitpunkt t (0..1)."""
	st, s = mm.get("minMaxState", 0), float(mm.get("scalar", 0))
	lo = float(mm.get("minScalar", s))
	if st == 0:
		return [s, s]
	if st == 1:
		v = s * kurve(mm["maxCurve"], t)
		return [v, v]
	if st == 2:
		a, b = lo * kurve(mm["minCurve"], t), s * kurve(mm["maxCurve"], t)
		return [min(a, b), max(a, b)]
	return [min(lo, s), max(lo, s)]


def minmax_kurve(mm):
	"""SAMPLES Werte über die Lebenszeit (Mittel aus min und max)."""
	return [round(sum(minmax_bereich(mm, i / (SAMPLES - 1))) / 2, 4) for i in range(SAMPLES)]


def farbe(c):
	return [float(c["r"]), float(c["g"]), float(c["b"]), float(c["a"])]


def gradient(g, t):
	nc, na = int(g.get("m_NumColorKeys", 2)), int(g.get("m_NumAlphaKeys", 2))
	ck = [(g["ctime%d" % i] / 65535.0, farbe(g["key%d" % i])[:3]) for i in range(nc)]
	ak = [(g["atime%d" % i] / 65535.0, float(g["key%d" % i]["a"])) for i in range(na)]
	fix = int(g.get("m_Mode", 0)) == 1

	def stelle(keys, t):
		if t <= keys[0][0]:
			return keys[0][1]
		for (t0, v0), (t1, v1) in zip(keys, keys[1:]):
			if t <= t1:
				if fix:
					return v1
				s = (t - t0) / (t1 - t0) if t1 > t0 else 1.0
				if isinstance(v0, list):
					return [a + (b - a) * s for a, b in zip(v0, v1)]
				return v0 + (v1 - v0) * s
		return keys[-1][1]

	return stelle(ck, t) + [stelle(ak, t)]


def minmax_farbe(mg):
	st = mg.get("minMaxState", 0)
	if st == 0:
		c = farbe(mg["maxColor"])
		return [c, c]
	if st == 2:
		return [farbe(mg["minColor"]), farbe(mg["maxColor"])]
	if st in (1, 4):
		c = gradient(mg["maxGradient"], 0.5)
		return [c, c]
	return [gradient(mg["minGradient"], 0.0), gradient(mg["maxGradient"], 0.0)]


def farbkurve(mg):
	st = mg.get("minMaxState", 0)
	if st == 0:
		return None
	g = mg["maxGradient"]
	return [[round(v, 4) for v in gradient(g, i / (SAMPLES - 1))] for i in range(SAMPLES)]


# --- Transformationen (Unity: linkshändig; hier wird z gespiegelt) ---------

def q_mul(a, b):
	ax, ay, az, aw = a
	bx, by, bz, bw = b
	return [aw * bx + ax * bw + ay * bz - az * by, aw * by - ax * bz + ay * bw + az * bx,
		aw * bz + ax * by - ay * bx + az * bw, aw * bw - ax * bx - ay * by - az * bz]


def q_rot(q, v):
	x, y, z, w = q
	u = [x, y, z]
	uv = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]]
	uuv = [u[1] * uv[2] - u[2] * uv[1], u[2] * uv[0] - u[0] * uv[2], u[0] * uv[1] - u[1] * uv[0]]
	return [v[i] + 2 * (w * uv[i] + uuv[i]) for i in range(3)]


def welt_transform(objekte, tid):
	"""(Position, Drehung, Skalierung) eines Transforms in der Wurzel des Prefabs (Unity-Koordinaten)."""
	kette = []
	while tid and tid != "0":
		_, t = objekte[tid]
		kette.append(t)
		tid = str(t.get("m_Father", {}).get("fileID", 0))
	kette.reverse()
	pos, rot, sca = [0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 1.0], [1.0, 1.0, 1.0]
	for i, t in enumerate(kette):
		lp = [float(t["m_LocalPosition"][k]) for k in "xyz"]
		lr = [float(t["m_LocalRotation"][k]) for k in "xyzw"]
		ls = [float(t["m_LocalScale"][k]) for k in "xyz"]
		if i == 0:
			# die Wurzel selbst bleibt am Ursprung (Position im Prefab ist egal)
			lp = [0.0, 0.0, 0.0]
		pos = [pos[j] + v for j, v in enumerate(q_rot(rot, [lp[k] * sca[k] for k in range(3)]))]
		rot = q_mul(rot, lr)
		sca = [sca[k] * ls[k] for k in range(3)]
	return pos, rot, sca


def nach_godot(pos, rot):
	return [pos[0], pos[1], -pos[2]], [-rot[0], -rot[1], rot[2], rot[3]]


# --- Material und Textur ----------------------------------------------------

def _tex_env(mat, name):
	for e in mat["m_SavedProperties"].get("m_TexEnvs", []):
		if name in e:
			return e[name]
	return None


def _farbe_prop(mat, *namen):
	for e in mat["m_SavedProperties"].get("m_Colors", []):
		for n in namen:
			if n in e:
				return farbe(e[n])
	return None


def material(paket, nach_guid, guid, texturen):
	pfad = nach_guid.get(guid)
	if pfad is None:
		return None
	_, mat = next(iter(ul.lade_yaml(paket[pfad]["datei"]).values()))
	sh = mat.get("m_Shader", {})
	if sh.get("guid", "").startswith("0000000000000000"):
		add = ADDITIV.get(int(sh.get("fileID", 200)), True)
		legacy = int(sh.get("fileID", 0)) in (200, 201, 202, 203)
	else:
		add = SHADER_DATEI_ADDITIV.get(os.path.basename(nach_guid.get(sh.get("guid"), "")), True)
		legacy = True
	env = _tex_env(mat, "_MainTex")
	if env is None or not env["m_Texture"].get("guid"):
		return None
	tex = textur(paket, nach_guid, env["m_Texture"]["guid"], texturen)
	if tex is None:
		return None
	tint = _farbe_prop(mat, "_TintColor", "_Color") or [0.5, 0.5, 0.5, 0.5]
	if legacy:
		tint = [v * 2 for v in tint]
	else:
		tint = [1.0, 1.0, 1.0, 1.0]
	return {"tex": tex, "add": add, "tint": [round(min(v, 4.0), 4) for v in tint],
		"uv_scale": [env["m_Scale"]["x"], env["m_Scale"]["y"]], "uv_offset": [env["m_Offset"]["x"], env["m_Offset"]["y"]]}


def textur(paket, nach_guid, guid, texturen):
	if guid in texturen:
		return texturen[guid]["res"]
	pfad = nach_guid.get(guid)
	if pfad is None:
		return None
	name = os.path.splitext(os.path.basename(pfad))[0].replace(" ", "_").lower() + ".png"
	meta = paket[pfad]["datei"] + ".meta"
	alpha_aus_grau = False
	if os.path.isfile(meta):
		with open(meta, encoding="utf-8", errors="replace") as f:
			alpha_aus_grau = "alphaSource: 2" in f.read() or False
	im = Image.open(paket[pfad]["datei"]).convert("RGBA")
	if alpha_aus_grau:
		im.putalpha(im.convert("L"))
	ziel = os.path.join(REPO, TEX_ZIEL, name)
	os.makedirs(os.path.dirname(ziel), exist_ok=True)
	# größer als 256 bringt bei Treffern, die ein paar Dutzend Pixel groß sind, nichts
	if max(im.size) > 256:
		f = 256 / max(im.size)
		im = im.resize((max(1, round(im.width * f)), max(1, round(im.height * f))), Image.LANCZOS)
	im.save(ziel, optimize=True)
	texturen[guid] = {"res": "res://" + TEX_ZIEL + "/" + name, "bild": im}
	return texturen[guid]["res"]


# --- Partikelsysteme --------------------------------------------------------

def ebene(paket, nach_guid, objekte, ps, renderer, go, tr_id, texturen):
	if not renderer.get("m_Enabled", 1) or not go.get("m_IsActive", 1):
		return None
	mats = [m for m in renderer.get("m_Materials", []) if m.get("guid")]
	if not mats:
		return None
	mat = material(paket, nach_guid, mats[0]["guid"], texturen)
	if mat is None:
		return None
	im = ps["InitialModule"]
	em = ps["EmissionModule"]
	if not em.get("enabled", 1):
		return None
	pos, rot, sca = welt_transform(objekte, tr_id)
	gpos, grot = nach_godot(pos, rot)
	modus = int(renderer.get("m_RenderMode", 0))
	mesh = ""
	if modus == 4:
		mesh_guid = renderer.get("m_Mesh", {}).get("guid", "")
		mesh = "plane_left" if "Eric_Plane" in nach_guid.get(mesh_guid, "") else "plane"
	l = {
		"name": go.get("m_Name", ""),
		"pos": [round(v, 4) for v in gpos], "rot": [round(v, 5) for v in grot], "scale": [round(v, 4) for v in sca],
		"mode": {0: "billboard", 1: "stretch", 2: "flat", 3: "billboard", 4: mesh}.get(modus, "billboard"),
		"align": "view" if int(renderer.get("m_RenderAlignment", 0)) in (0, 3) and modus != 4 else "local",
		"length_scale": float(renderer.get("m_LengthScale", 2)), "velocity_scale": float(renderer.get("m_VelocityScale", 0)),
		"delay": minmax_bereich(ps.get("startDelay", {}))[1],
		"duration": float(ps.get("lengthInSec", 1)), "loop": bool(ps.get("looping", 0)),
		"bursts": [[float(b["time"]), max(1, round(minmax_bereich(b["countCurve"])[1])), int(b.get("cycleCount", 1)), float(b.get("repeatInterval", 0.01))] for b in em.get("m_Bursts", [])],
		"rate": minmax_bereich(em.get("rateOverTime", {}))[1],
		"max": int(im.get("maxNumParticles", 1000)),
		"life": minmax_bereich(im["startLifetime"]), "speed": minmax_bereich(im["startSpeed"]),
		"size": minmax_bereich(im["startSize"]),
		"rotation": minmax_bereich(im["startRotation"]),
		"color": minmax_farbe(im["startColor"]),
		"gravity": minmax_bereich(im.get("gravityModifier", {}))[1],
	}
	if im.get("size3D"):
		l["size3d"] = [minmax_bereich(im["startSize"])[1], minmax_bereich(im["startSizeY"])[1], minmax_bereich(im["startSizeZ"])[1]]
	if im.get("rotation3D"):
		l["rotation3d"] = [minmax_bereich(im["startRotationX"])[1], minmax_bereich(im["startRotationY"])[1], minmax_bereich(im["startRotation"])[1]]
	l.update(mat)
	sh = ps["ShapeModule"]
	if sh.get("enabled"):
		r = sh.get("radius", 1)
		r = float(r["value"]) if isinstance(r, dict) else float(r)
		l["shape"] = {"type": SHAPE.get(int(sh.get("type", 0)), "sphere"), "radius": r, "angle": float(sh.get("angle", 25)),
			"thickness": float(sh.get("radiusThickness", 1)), "arc": float(sh.get("arc", 360) if not isinstance(sh.get("arc"), dict) else sh["arc"].get("value", 360))}
	if ps["SizeModule"].get("enabled"):
		l["size_curve"] = minmax_kurve(ps["SizeModule"]["curve"])
		if ps["SizeModule"].get("separateAxes"):
			l["size_curve_y"] = minmax_kurve(ps["SizeModule"]["y"])
	if ps["ColorModule"].get("enabled"):
		fk = farbkurve(ps["ColorModule"]["gradient"])
		if fk:
			l["color_curve"] = fk
	if ps["RotationModule"].get("enabled"):
		l["spin"] = minmax_bereich(ps["RotationModule"]["curve"])
	uv = ps["UVModule"]
	if uv.get("enabled"):
		l["tiles"] = [int(uv.get("tilesX", 1)), int(uv.get("tilesY", 1))]
		if int(uv.get("animationType", 0)) == 1:
			l["row"] = int(uv.get("rowIndex", 0))
		l["frames"] = minmax_kurve(uv["frameOverTime"])
		l["cycles"] = float(uv.get("cycles", 1))
		l["start_frame"] = minmax_bereich(uv.get("startFrame", {}))
	cv = ps.get("ClampVelocityModule", {})
	if cv.get("enabled"):
		l["drag"] = float(cv.get("dampen", 0))
		l["max_speed"] = minmax_bereich(cv.get("magnitude", {}))[1]
	return l


def grundfarbe(layers, texturen_nach_res):
	"""Mittlere Farbe des Effekts (gewichtet nach Helligkeit und Größe) und daraus der Farbton."""
	r = g = b = w = 0.0
	for l in layers:
		info = texturen_nach_res.get(l["tex"])
		if info is None:
			continue
		klein = info.convert("RGBA").resize((16, 16))
		px = list(klein.get_flattened_data())
		tr = sum(p[0] * p[3] for p in px) / 255 / 255
		tg = sum(p[1] * p[3] for p in px) / 255 / 255
		tb = sum(p[2] * p[3] for p in px) / 255 / 255
		c = [(a + bb) / 2 for a, bb in zip(*l["color"])]
		groesse = max(l["size"][1], 0.05)
		for k, v in enumerate((tr, tg, tb)):
			v *= c[k] * l["tint"][k] * c[3] * groesse
			if k == 0:
				r += v
			elif k == 1:
				g += v
			else:
				b += v
		w += groesse
	if w <= 0:
		return "#ffffff", 0.0
	m = max(r, g, b, 1e-6)
	r, g, b = r / m, g / m, b / m
	h, s, v = colorsys.rgb_to_hsv(r, g, b)
	return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255)), round(h, 3), round(s, 3)


def main(ordner):
	random.seed(1)
	paket = ul.lade_paket(ordner)
	nach_guid = {v["guid"]: k for k, v in paket.items()}
	texturen = {}
	effekte = {}
	for pfad in sorted(paket):
		if not pfad.endswith(".prefab"):
			continue
		objekte = ul.lade_yaml(paket[pfad]["datei"])
		gos = {k: d for k, (c, d) in objekte.items() if c == 1}
		renderer = {str(d["m_GameObject"]["fileID"]): d for k, (c, d) in objekte.items() if c == 199}
		trans = {str(d["m_GameObject"]["fileID"]): k for k, (c, d) in objekte.items() if c == 4}
		layers = []
		for k, (c, d) in objekte.items():
			if c != 198:
				continue
			go_id = str(d["m_GameObject"]["fileID"])
			l = ebene(paket, nach_guid, objekte, d, renderer.get(go_id, {}), gos.get(go_id, {}), trans.get(go_id), texturen)
			if l:
				layers.append(l)
		name = os.path.splitext(os.path.basename(pfad))[0]
		fid = name.lower().removeprefix("fx_")
		nach_res = {t["res"]: t["bild"] for t in texturen.values()}
		hexf, hue, sat = grundfarbe(layers, nach_res)
		ende = max((l["delay"] + l["duration"] + l["life"][1] for l in layers if not l["loop"]), default=1.0)
		effekte[fid] = {"name": name, "color": hexf, "hue": hue, "saturation": sat, "length": round(min(ende, 2.0), 3), "layers": layers}
	ziel = os.path.join(REPO, "data", "fx", "hits.json")
	os.makedirs(os.path.dirname(ziel), exist_ok=True)
	with open(ziel, "w", encoding="utf-8") as f:
		json.dump({"_quelle": "FX_Hit_Collection (Unity Asset Store), umgewandelt mit tools/fx/treffer_umwandeln.py",
			"effects": effekte}, f, ensure_ascii=False, indent="\t")
	print("%d Effekte, %d Texturen -> %s" % (len(effekte), len(texturen), ziel))
	for fid, e in effekte.items():
		print("  %-14s %s  Farbton %.2f  Sätt. %.2f  %d Ebenen" % (fid, e["color"], e["hue"], e["saturation"], len(e["layers"])))


if __name__ == "__main__":
	main(sys.argv[1])
