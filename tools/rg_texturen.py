"""Bodentexturen für Randgruppen TD, ganz selbst erzeugt (kein Foto, frei wie CC0).

Aufruf: python3 tools/rg_texturen.py
Schreibt nach assets/textures/ground/:
  concrete.jpg (+ _normal): heller, grauer Asphalt/Beton mit wenigen kleinen Steinen (Baufläche)
  gravel.jpg (+ _normal):   etwas dunklerer Splitt mit mehr Steinen (Weg der Gegner)
Das Rauschen ist periodisch (über FFT gefiltert), die Steine werden über den Rand gespiegelt, so kacheln beide nahtlos.
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
OUT = "assets/textures/ground/"


def noise(rng, scale: float) -> np.ndarray:
    """Periodisches Rauschen: weißes Rauschen im Frequenzraum tiefpassgefiltert, Werte 0..1."""
    f = np.fft.fftfreq(SIZE)
    r = np.sqrt(f[:, None] ** 2 + f[None, :] ** 2)
    spec = np.fft.fft2(rng.standard_normal((SIZE, SIZE))) * np.exp(-(r * scale) ** 2)
    a = np.real(np.fft.ifft2(spec))
    return (a - a.min()) / (a.max() - a.min())


def stones(rng, base: np.ndarray, height: np.ndarray, count: int, rmin: int, rmax: int, tone: tuple) -> None:
    """Kleine Steine als unregelmäßige Ellipsen in base (Farbe) und height (Relief) zeichnen, nahtlos."""
    col = Image.new("L", (SIZE, SIZE), 0)
    hgt = Image.new("L", (SIZE, SIZE), 0)
    dc = ImageDraw.Draw(col)
    dh = ImageDraw.Draw(hgt)
    for _ in range(count):
        x, y = rng.uniform(0, SIZE, 2)
        rx, ry = rng.uniform(rmin, rmax), rng.uniform(rmin, rmax) * rng.uniform(0.6, 1.0)
        shade = int(rng.uniform(*tone))
        for ox in (-SIZE, 0, SIZE):
            for oy in (-SIZE, 0, SIZE):
                box = [x + ox - rx, y + oy - ry, x + ox + rx, y + oy + ry]
                dc.ellipse(box, fill=shade)
                dh.ellipse(box, fill=255)
    c = np.asarray(col, dtype=np.float32) / 255.0
    m = np.asarray(hgt, dtype=np.float32) / 255.0
    # runde Kuppen statt Stufen fürs Relief
    dome = np.asarray(hgt.filter(ImageFilter.GaussianBlur(2.5)), dtype=np.float32) / 255.0
    base[:] = np.where(m[..., None] > 0, c[..., None] * np.array([1.0, 0.99, 0.97]), base)
    height[:] = np.maximum(height, dome * 0.9)


def normal_map(h: np.ndarray, strength: float) -> np.ndarray:
    gx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * strength
    gy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * strength
    n = np.stack([-gx, gy, np.ones_like(h)], axis=-1)  # wie tools/boden_texturen.py
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return (n * 0.5 + 0.5) * 255


def build(name: str, seed: int, grey: float, spread: float, count: int, rmin: int, rmax: int, tone: tuple) -> None:
    rng = np.random.default_rng(seed)
    coarse = noise(rng, 40.0)
    fine = noise(rng, 3.0)
    v = grey + (coarse - 0.5) * spread + (fine - 0.5) * spread * 0.6
    base = np.repeat(v[..., None], 3, axis=2) * np.array([1.0, 1.0, 1.02])
    height = fine * 0.15
    stones(rng, base, height, count, rmin, rmax, tone)
    rgb = np.clip(base * 255, 0, 255).astype(np.uint8)
    Image.fromarray(rgb).save(OUT + name + ".jpg", quality=88)
    Image.fromarray(normal_map(height, 6.0).astype(np.uint8)).save(OUT + name + "_normal.jpg", quality=88)


if __name__ == "__main__":
    build("concrete", 11, 0.74, 0.16, 70, 4, 9, (0.45 * 255, 0.62 * 255))
    build("gravel", 23, 0.6, 0.18, 900, 3, 8, (0.38 * 255, 0.72 * 255))
    print("concrete.jpg, gravel.jpg (+ _normal) geschrieben")
