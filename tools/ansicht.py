"""Verkleinerte Ansicht von Bildern zum Ansehen durch Claude (spart Tokens).

Ein Bild kostet beim Lesen etwa Breite x Höhe / 750 Tokens: ein 1920x1080-Screenshot rund 2800,
dieselbe Ansicht mit 1024 px Breite rund 800. Mehrere Bilder kommen als Raster in eine Datei,
damit ein Read statt vieler reicht. Die Originale bleiben für Lukas unverändert liegen.

Aufruf: python3 tools/ansicht.py [--breite=1024] [--aus=datei.jpg] a.png [b.png …]
Ausgabe: ANSICHT <pfad> (<b>x<h>, ca. <n> Tokens)
Von tools/screenshot.sh und tools/fx/vorschau.sh automatisch aufgerufen.
"""
import os
import sys

from PIL import Image, ImageDraw


def main(argv):
    width, out, files = 1024, "", []
    for a in argv:
        if a.startswith("--breite="):
            width = int(a.split("=", 1)[1])
        elif a.startswith("--aus="):
            out = a.split("=", 1)[1]
        else:
            files.append(a)
    if not files:
        print(__doc__)
        return 1
    imgs = [Image.open(f).convert("RGB") for f in files]
    cols = 1 if len(imgs) <= 2 else 2
    rows = (len(imgs) + cols - 1) // cols
    cell_w = width // cols
    # Zellhöhe nach dem höchsten Bild im Seitenverhältnis
    cell_h = max(int(im.height * cell_w / im.width) for im in imgs)
    label = 14 if len(imgs) > 1 else 0
    sheet = Image.new("RGB", (cell_w * cols, rows * (cell_h + label)), (20, 20, 28))
    draw = ImageDraw.Draw(sheet)
    for i, im in enumerate(imgs):
        im.thumbnail((cell_w, cell_h))
        x, y = (i % cols) * cell_w, (i // cols) * (cell_h + label)
        sheet.paste(im, (x, y + label))
        if label:
            draw.text((x + 3, y + 1), os.path.basename(files[i]), fill=(255, 255, 255))
    if not out:
        base = os.path.splitext(files[0])[0]
        out = base + ("_ansicht.jpg" if len(files) == 1 else "_bogen.jpg")
    sheet.save(out, quality=85)
    w, h = sheet.size
    print("ANSICHT %s (%dx%d, ca. %d Tokens)" % (out, w, h, w * h // 750))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
