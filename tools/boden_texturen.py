"""Macht aus Fotos nahtlos kachelbare Bodentexturen (assets/textures/ground/).

Aufruf: python3 tools/boden_texturen.py GRAS_A.jpg GRAS_B.jpg ERDE.jpg
Schritte je Bild: quadratischen Ausschnitt nehmen, Helligkeitsverlauf (Vignette,
Licht) herausrechnen, auf 1024 px verkleinern und mit einer um eine halbe Breite
verschobenen Kopie überblenden, sodass die Ränder nahtlos aneinander passen.
"""
import sys
import numpy as np
from PIL import Image, ImageFilter

SIZE = 1024
OUT = "assets/textures/ground/"


def flatten(img: Image.Image) -> np.ndarray:
    """Großflächige Helligkeitsunterschiede entfernen, Farbe und Detail behalten."""
    a = np.asarray(img, dtype=np.float32)
    low = np.asarray(img.filter(ImageFilter.GaussianBlur(img.width / 6)), dtype=np.float32)
    mean = a.reshape(-1, 3).mean(axis=0)
    return np.clip(a / np.maximum(low, 1.0) * mean, 0, 255)


def make_seamless(a: np.ndarray) -> np.ndarray:
    n = a.shape[0]
    shifted = np.roll(a, (n // 2, n // 2), axis=(0, 1))
    t = np.linspace(0.0, 1.0, n, endpoint=False) + 0.5 / n
    # Gewicht 1 in der Mitte, 0 an den Rändern; steil, damit die Überblendzone schmal bleibt
    w1 = np.clip((0.5 - np.abs(t - 0.5)) / 0.18, 0.0, 1.0)
    w1 = w1 * w1 * (3 - 2 * w1)
    w = (w1[:, None] * w1[None, :])[..., None]
    mean = a.reshape(-1, 3).mean(axis=0)
    # varianzerhaltende Mischung: kein matter Fleck in der Überblendzone
    mixed = (a - mean) * w + (shifted - mean) * (1 - w)
    mixed /= np.sqrt(w * w + (1 - w) * (1 - w))
    return np.clip(mixed + mean, 0, 255)


def process(src: str, dst: str, crop: tuple) -> None:
    img = Image.open(src).convert("RGB")
    fx, fy, fs = crop  # Mitte x, Mitte y (relativ), Kantenlänge relativ zur kürzeren Seite
    s = int(min(img.size) * fs)
    cx, cy = int(img.width * fx), int(img.height * fy)
    img = img.crop((cx - s // 2, cy - s // 2, cx - s // 2 + s, cy - s // 2 + s))
    img = img.resize((SIZE * 2, SIZE * 2), Image.LANCZOS)
    a = flatten(img)
    a = np.asarray(Image.fromarray(a.astype(np.uint8)).resize((SIZE, SIZE), Image.LANCZOS), dtype=np.float32)
    out = make_seamless(a)
    Image.fromarray(out.astype(np.uint8)).save(OUT + dst, quality=90)
    print(dst)


if __name__ == "__main__":
    grass_a, grass_b, dirt = sys.argv[1:4]
    # Gras A ist schräg fotografiert und oben unscharf: nur den scharfen unteren Teil nehmen
    process(grass_a, "grass_a.jpg", (0.5, 0.66, 0.4))
    process(grass_b, "grass_b.jpg", (0.5, 0.5, 0.95))
    process(dirt, "dirt.jpg", (0.42, 0.5, 0.95))
