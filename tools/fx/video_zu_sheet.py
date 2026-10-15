"""Macht aus Effekt-Videos mit Alphakanal (z. B. ProRes 4444 von FootageCrate) Sprite-Sheets für Godot.

  python3 -I tools/fx/video_zu_sheet.py <id> <video.mov> <art> [hoehe]

art: "line"       (Strahl/Blitz, wird zwischen Tower und Ziel gespannt; das Video läuft von links nach rechts)
     "projectile" (Geschoss, fliegt in eigener Länge zum Ziel; Video ebenfalls von links nach rechts)
     "nova"       (Kreis von vorne, wird flach auf den Boden gelegt)
Schneidet alle Bilder auf den gemeinsamen sichtbaren Bereich zu, verkleinert sie auf [hoehe] Pixel
(Standard 64 für line, 192 für nova) und legt sie in ein Raster. Ergebnis: assets/fx/shot/<id>.png und
der Eintrag in data/fx/shots.json (bestehende Einträge bleiben, Wiedergabe-Werte werden nicht überschrieben).
"""
import colorsys
import json
import math
import os
import re
import subprocess
import sys
import tempfile

from PIL import Image

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MAX_BREITE = 2048


def bilder(video):
	tmp = tempfile.mkdtemp(prefix="fxsheet_")
	subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", video, "-map", "0:v", "-pix_fmt", "rgba", os.path.join(tmp, "f%03d.png")], check=True)
	namen = sorted(n for n in os.listdir(tmp) if n.endswith(".png"))
	fps = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=r_frame_rate", "-of", "csv=p=0", video],
		capture_output=True, text=True, check=True).stdout.strip()
	a, b = fps.split("/")
	return [Image.open(os.path.join(tmp, n)).convert("RGBA") for n in namen], float(a) / float(b)


def main(fid, video, art, hoehe=None):
	frames, fps = bilder(video)
	# leere Bilder am Anfang/Ende weglassen
	frames = [f for f in frames if f.getchannel("A").getbbox()] or frames
	box = None
	for f in frames:
		bb = f.getchannel("A").point(lambda v: 255 if v > 6 else 0).getbbox()
		if bb:
			box = bb if box is None else (min(box[0], bb[0]), min(box[1], bb[1]), max(box[2], bb[2]), max(box[3], bb[3]))
	if art == "nova":
		# quadratisch um die Mitte, damit der Kreis rund bleibt
		cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
		r = max(box[2] - box[0], box[3] - box[1]) / 2 + 2
		box = (int(cx - r), int(cy - r), int(cx + r), int(cy + r))
	else:
		box = (box[0], max(0, box[1] - 2), box[2], box[3] + 2)
	frames = [f.crop(box) for f in frames]
	hoehe = int(hoehe or (192 if art == "nova" else 64))
	breite = max(1, round(frames[0].width * hoehe / frames[0].height))
	if art != "nova":
		breite = min(breite, 512)
	frames = [f.resize((breite, hoehe), Image.LANCZOS) for f in frames]
	cols = max(1, min(len(frames), MAX_BREITE // breite))
	rows = math.ceil(len(frames) / cols)
	sheet = Image.new("RGBA", (cols * breite, rows * hoehe), (0, 0, 0, 0))
	for i, f in enumerate(frames):
		sheet.paste(f, ((i % cols) * breite, (i // cols) * hoehe))
	ziel = os.path.join(REPO, "assets", "fx", "shot", fid + ".png")
	os.makedirs(os.path.dirname(ziel), exist_ok=True)
	sheet.save(ziel, optimize=True)
	# Grundfarbe: Mittel der deckenden Pixel, gewichtet nach Deckkraft
	r = g = b = w = 0.0
	for f in frames:
		for pr, pg, pb, pa in f.resize((32, max(1, 32 * f.height // f.width))).get_flattened_data():
			r, g, b, w = r + pr * pa, g + pg * pa, b + pb * pa, w + pa
	m = max(r, g, b, 1e-6)
	h, s, _ = colorsys.rgb_to_hsv(r / m, g / m, b / m)
	datei = os.path.join(REPO, "data", "fx", "shots.json")
	daten = {"effects": {}}
	if os.path.isfile(datei):
		with open(datei, encoding="utf-8") as fh:
			daten = json.load(fh)
	alt = daten["effects"].get(fid, {})
	name = re.sub(r"^[0-9a-f]{8}-", "", os.path.splitext(os.path.basename(video))[0]).replace("FootageCrate-", "FootageCrate ").removesuffix("-LQ")
	eintrag = {"name": name, "kind": art,
		"sheet": "res://assets/fx/shot/%s.png" % fid, "cols": cols, "rows": rows, "frames": len(frames),
		"aspect": round(breite / hoehe, 3), "color": "#%02x%02x%02x" % (round(r / m * 255), round(g / m * 255), round(b / m * 255)),
		"hue": round(h, 3), "saturation": round(s, 3), "video_length": round(len(frames) / fps, 3)}
	# Wiedergabe-Werte (Länge, Breite, Größe) von Hand in shots.json, hier nur Startwerte
	eintrag["length"] = alt.get("length", min(0.35, eintrag["video_length"]))
	key = "size" if art == "nova" else "width"
	eintrag[key] = alt.get(key, 1.0 if art == "nova" else 0.45)
	eintrag["add"] = alt.get("add", True)
	daten["effects"][fid] = {**alt, **eintrag}
	with open(datei, "w", encoding="utf-8") as fh:
		json.dump(daten, fh, ensure_ascii=False, indent="\t")
	print("%s: %d Bilder %dx%d in %dx%d, %s Farbton %.2f -> %s" % (fid, len(frames), breite, hoehe, cols, rows, eintrag["color"], h, ziel))


if __name__ == "__main__":
	if len(sys.argv) < 4 or sys.argv[3] not in ("line", "projectile", "nova"):
		sys.exit(__doc__)
	main(*sys.argv[1:])
