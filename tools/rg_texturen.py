"""Bodentexturen für Randgruppen TD, ganz selbst erzeugt (kein Foto, frei wie CC0).

Aufruf: python3 tools/rg_texturen.py
Schreibt nach assets/textures/ground/:
  concrete.jpg (+ _normal): heller, grauer Asphalt/Beton mit wenigen kleinen Steinen (Baufläche)
  gravel.jpg (+ _normal):   etwas dunklerer Splitt mit mehr Steinen (Weg der Gegner)
  cobble.jpg (+ _normal):   Pflastersteine im Läuferverband, Gras in den Fugen (Baufläche, Lukas 2026-10-29)
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


def build_cobble(name: str, seed: int, cols: int = 16) -> None:
    """Pflaster: abgerundete Steine im versetzten Verband, dazwischen Erde und Gras (nahtlos)."""
    rng = np.random.default_rng(seed)
    cell = SIZE // cols
    fine = noise(rng, 3.0)
    mid = noise(rng, 12.0)
    patch = noise(rng, 60.0)
    # Fuge: dunkle Erde, an vielen Stellen grün bewachsen
    green = np.clip((mid - 0.35) * 2.5, 0, 1)[..., None]
    soil = np.array([0.24, 0.21, 0.17]) * (0.8 + 0.4 * fine[..., None])
    grass = np.array([0.24, 0.34, 0.14]) * (0.75 + 0.5 * fine[..., None])
    base = soil * (1 - green) + grass * green
    mask = Image.new("L", (SIZE, SIZE), 0)
    tone = Image.new("L", (SIZE, SIZE), 0)
    dm, dt = ImageDraw.Draw(mask), ImageDraw.Draw(tone)
    for row in range(cols):
        shift = (cell // 2) * (row % 2)
        for col in range(cols):
            x0 = col * cell + shift + rng.uniform(2, 6)
            y0 = row * cell + rng.uniform(2, 6)
            x1 = (col + 1) * cell + shift - rng.uniform(2, 6)
            y1 = (row + 1) * cell - rng.uniform(2, 6)
            shade = int(rng.uniform(0.42, 0.62) * 255)
            for ox in (-SIZE, 0, SIZE):
                for oy in (-SIZE, 0, SIZE):
                    box = [x0 + ox, y0 + oy, x1 + ox, y1 + oy]
                    dm.rounded_rectangle(box, radius=cell * 0.22, fill=255)
                    dt.rounded_rectangle(box, radius=cell * 0.22, fill=shade)
    m = np.asarray(mask.filter(ImageFilter.GaussianBlur(1.0)), dtype=np.float32)[..., None] / 255.0
    t = np.asarray(tone, dtype=np.float32)[..., None] / 255.0
    # Stein: grau, leicht warm, mit Flecken; an manchen Stellen Moos auf den Steinen
    stone = t * np.array([1.0, 0.98, 0.94]) * (0.85 + 0.3 * fine[..., None]) * (0.9 + 0.2 * patch[..., None])
    moss = np.clip((patch - 0.7) * 3.0, 0, 1)[..., None] * 0.35
    stone = stone * (1 - moss) + np.array([0.3, 0.36, 0.2]) * moss
    base = base * (1 - m) + stone * m
    dome = np.asarray(mask.filter(ImageFilter.GaussianBlur(cell * 0.12)), dtype=np.float32) / 255.0
    height = dome * 0.9 + fine * 0.08
    rgb = np.clip(base * 255, 0, 255).astype(np.uint8)
    Image.fromarray(rgb).save(OUT + name + ".jpg", quality=88)
    Image.fromarray(normal_map(height, 7.0).astype(np.uint8)).save(OUT + name + "_normal.jpg", quality=88)


if __name__ == "__main__":
    build("concrete", 11, 0.74, 0.16, 70, 4, 9, (0.45 * 255, 0.62 * 255))
    build("gravel", 23, 0.6, 0.18, 900, 3, 8, (0.38 * 255, 0.72 * 255))
    build_cobble("cobble", 37)
    print("concrete.jpg, gravel.jpg, cobble.jpg (+ _normal) geschrieben")
