#!/usr/bin/env python3
"""Schneidet die Spiel-Sounds aus den Quelldateien und legt sie unter assets/sounds/ ab.

Aufruf: python3 -I tools/sfx/schneiden.py [quellordner]
Standard-Quellordner: /mnt/project-files/sounds/quellen/ (Lukas' Uploads, unverändert).
Welche Datei woraus entsteht, steht in SCHNITTE: Quelle, Start, Ende (Sekunden), Ein-/Ausblenden,
Lautstärke-Ziel (Spitze in dB) und ob die Datei als Schleife (Ambiente) gebaut wird.
Kurze Sounds werden .wav (kein Dekodieren beim Abspielen), lange .ogg.
Braucht ffmpeg und numpy.
"""
import os
import subprocess
import sys

import numpy as np

QUELLEN = "/mnt/project-files/sounds/quellen"
ZIEL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "sounds")
RATE = 44100

PIXA = "freesound_community-"
# name: (quelle, start, ende, einblenden, ausblenden, spitze_db, schleife)
SCHNITTE = {
	# Schüsse (eigene Sounds von Lukas)
	"shot_pew.wav": ("sound2.wav", 0.0, None, 0.0, 0.08, -3.0, False),
	"shot_blip.wav": ("sound1.wav", 0.0, None, 0.0, 0.05, -3.0, False),
	"shot_zap.wav": ("sound3.wav", 0.0, None, 0.0, 0.05, -3.0, False),
	"shot_blast.wav": ("sound.wav", 0.0, 0.45, 0.0, 0.2, -3.0, False),
	"leak.wav": ("sound.wav", 0.0, None, 0.0, 0.3, -2.0, False),
	"wave_start.ogg": ("sound4.wav", 1.6, 5.0, 0.8, 0.5, -4.0, False),
	# Pixabay (freesound_community), siehe QUELLEN.md
	"thud.wav": (PIXA + "vibrating-thud-39536.mp3", 0.03, 0.6, 0.0, 0.12, -3.0, False),
	"error.wav": (PIXA + "teleport-error-39936.mp3", 0.30, 0.95, 0.02, 0.2, -4.0, False),
	"crumble.wav": (PIXA + "random-sound-1-80941.mp3", 0.0, 0.95, 0.0, 0.3, -4.0, False),
	"boss.ogg": (PIXA + "ghost-wails-20457.mp3", 53.0, 58.5, 0.3, 1.5, -2.0, False),
	"amb_forest.ogg": (PIXA + "fx_bird_water_whistle-25554.mp3", 13.0, 38.0, 0.0, 0.0, -6.0, True),
	"amb_night.ogg": (PIXA + "ghost-wails-20457.mp3", 3.0, 33.0, 0.0, 0.0, -6.0, True),
}
UEBERBLENDEN = 2.0  # Sekunden, mit denen sich Schleifen-Ende und -Anfang überlappen


def lesen(pfad: str) -> np.ndarray:
	roh = subprocess.run(["ffmpeg", "-v", "error", "-i", pfad, "-ac", "1", "-ar", str(RATE), "-f", "f32le", "-"],
		check=True, capture_output=True).stdout
	return np.frombuffer(roh, dtype=np.float32).copy()


def schneiden(x: np.ndarray, start: float, ende, ein: float, aus: float, spitze: float, schleife: bool) -> np.ndarray:
	a = int(start * RATE)
	b = len(x) if ende is None else min(len(x), int(ende * RATE))
	if schleife:
		# Das Stück nach dem Ende wird über den Anfang geblendet, so läuft die Schleife ohne Knacks
		ueb = int(UEBERBLENDEN * RATE)
		y = x[a:b].copy()
		rest = x[b:b + ueb]
		k = np.linspace(0.0, 1.0, len(rest))
		y[:len(rest)] = y[:len(rest)] * k + rest * (1.0 - k)
	else:
		y = x[a:b].copy()
		n = int(ein * RATE)
		if n > 0:
			y[:n] *= np.linspace(0.0, 1.0, n)
		n = min(int(aus * RATE), len(y))
		if n > 0:
			y[-n:] *= np.linspace(1.0, 0.0, n)
	y -= y.mean()
	return y * (10 ** (spitze / 20) / max(np.abs(y).max(), 1e-6))


def schreiben(y: np.ndarray, pfad: str) -> None:
	opts = ["-c:a", "libvorbis", "-q:a", "3"] if pfad.endswith(".ogg") else ["-c:a", "pcm_s16le"]
	subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(RATE), "-ac", "1", "-i", "-", *opts, pfad],
		check=True, input=y.astype(np.float32).tobytes())


def main() -> None:
	quellen = sys.argv[1] if len(sys.argv) > 1 else QUELLEN
	os.makedirs(ZIEL, exist_ok=True)
	for name, (quelle, start, ende, ein, aus, spitze, schleife) in SCHNITTE.items():
		pfad = os.path.join(quellen, quelle)
		if not os.path.exists(pfad):
			print(f"FEHLT {quelle}")
			continue
		y = schneiden(lesen(pfad), start, ende, ein, aus, spitze, schleife)
		ziel = os.path.join(ZIEL, name)
		schreiben(y, ziel)
		print(f"{name:16} {len(y) / RATE:5.2f} s  {os.path.getsize(ziel) // 1024:4d} KB  <- {quelle}")


if __name__ == "__main__":
	main()
