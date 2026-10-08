"""Genera el ícono de ZERACK Fit para Android e iOS.

Uso:
    python3 tools/icon/make_icon.py apps/zerack_fit

Dibuja una "Z" con una línea de pulso sobre el verde de la marca. Sin fuentes
externas: solo polígonos, para que el resultado sea idéntico en cualquier
equipo. Requiere Pillow.
"""

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

GREEN = (0, 179, 126)
DARK = (0, 92, 66)
WHITE = (255, 255, 255)
SIZE = 1024


def draw(size: int = SIZE) -> Image.Image:
    s = size / SIZE
    img = Image.new("RGB", (size, size), GREEN)
    d = ImageDraw.Draw(img)
    # Degradado sutil hacia abajo.
    for y in range(size):
        t = y / size
        c = tuple(int(GREEN[i] * (1 - 0.35 * t) + DARK[i] * 0.35 * t) for i in range(3))
        d.line([(0, y), (size, y)], fill=c)

    def p(*pts):
        return [(x * s, y * s) for x, y in pts]

    # "Z": barra superior, diagonal y barra inferior.
    d.polygon(p((240, 230), (784, 230), (784, 340), (240, 340)), fill=WHITE)
    d.polygon(p((784, 340), (784, 400), (380, 684), (240, 684), (240, 624), (644, 340)), fill=WHITE)
    d.polygon(p((240, 684), (784, 684), (784, 794), (240, 794)), fill=WHITE)
    # Línea de pulso que cruza la diagonal.
    pulse = p((150, 512), (380, 512), (440, 420), (520, 620), (580, 470), (620, 512), (874, 512))
    d.line(pulse, fill=DARK, width=int(34 * s), joint="curve")
    return img


ANDROID = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    app = Path(sys.argv[1])
    base = draw()
    res = app / "android/app/src/main/res"
    for density, px in ANDROID.items():
        base.resize((px, px), Image.LANCZOS).save(res / f"mipmap-{density}/ic_launcher.png")

    iconset = app / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((iconset / "Contents.json").read_text())
    for entry in contents["images"]:
        name = entry.get("filename")
        if not name:
            continue
        pt = float(entry["size"].split("x")[0])
        scale = int(entry["scale"].rstrip("x"))
        px = round(pt * scale)
        # iOS exige íconos sin transparencia: la imagen es RGB.
        base.resize((px, px), Image.LANCZOS).save(iconset / name)

    web = app / "web"
    for name, px in [("favicon.png", 32), ("icons/Icon-192.png", 192), ("icons/Icon-512.png", 512),
                     ("icons/Icon-maskable-192.png", 192), ("icons/Icon-maskable-512.png", 512)]:
        if (web / name).exists():
            base.resize((px, px), Image.LANCZOS).save(web / name)
    base.save(app.parent.parent / "docs/icon.png")
    print("Íconos generados")


if __name__ == "__main__":
    main()
