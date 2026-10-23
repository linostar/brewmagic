#!/usr/bin/env python3
"""Renders the Android launcher icons and the Google Play store graphics from the game's own
pixel art (brewmagic/art/*.png atlases), each drawn at pixel scale and upscaled by an integer
factor with nearest-neighbour, so they stay crisp and on palette.

    python3 tools/store_art.py           # write the files
    python3 tools/store_art.py --check   # fail if a written file is stale (validate.sh)

Writes (res:// files are used by the Android export preset and project.godot):
    brewmagic/icons/icon_192.png                  launcher icon (legacy, square)
    brewmagic/icons/adaptive_foreground_432.png   adaptive icon layers (Android 8+): the
    brewmagic/icons/adaptive_background_432.png   cauldron inside the 66dp-of-108dp safe circle,
    brewmagic/icons/adaptive_monochrome_432.png   the starry wall, and a white silhouette
    brewmagic/icons/icon_512.png                  project icon (window, web) = Play hi-res icon
    store/play/icon_512.png                       Play Console hi-res icon (opaque 512x512)
    store/play/feature_graphic.png                Play Console feature graphic (1024x500, no alpha)
    brewmagic/icons/icon_1024.png                 iOS app icon = App Store icon (opaque 1024x1024)
"""
import io
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "brewmagic" / "art"
FONT = ROOT / "brewmagic" / "fonts" / "Silkscreen-Regular.ttf"

NIGHT = (0x2A, 0x1A, 0x48)   # gloom 1, night sky
WALL = (0x4A, 0x34, 0x40)    # wall plum-brown
SHADOW = (0x3A, 0x28, 0x30)  # deep shadow
CREAM = (0xFB, 0xED, 0xCD)
LILAC = (0xD0, 0xA0, 0xE8)
GOLD = (0xFF, 0xC9, 0x5C)
LIQUID = (0x7C, 0xC4, 0x4C)  # bloom 3: the green the hero cauldron shows between tints

_atlases = {}


def sprite(atlas, name):
    if atlas not in _atlases:
        meta = json.loads((ART / f"{atlas}.json").read_text())
        _atlases[atlas] = (Image.open(ART / meta["texture"]).convert("RGBA"), meta["sprites"])
    image, sprites = _atlases[atlas]
    s = sprites[name]
    return image.crop((s["x"], s["y"], s["x"] + s["w"], s["y"] + s["h"]))


def tint(image, color):
    """Multiplies RGB by `color`, as Godot's modulate does."""
    r, g, b, a = image.split()
    r = r.point(lambda v: v * color[0] // 255)
    g = g.point(lambda v: v * color[1] // 255)
    b = b.point(lambda v: v * color[2] // 255)
    return Image.merge("RGBA", (r, g, b, a))


def lighten(color, amount):
    return tuple(round(c + (255 - c) * amount) for c in color)


def paste(canvas, image, x, y):
    canvas.alpha_composite(image, (x, y))


def hero(liquid=LIQUID):
    """The title cauldron (scenes/cauldron_hero.tscn): flames under the pot, tinted liquid,
    a few bubbles and a steam puff over the surface. 112 x 88, transparent."""
    canvas = Image.new("RGBA", (112, 88), (0, 0, 0, 0))
    paste(canvas, sprite("title", "title_fire_0"), 14, 62)
    paste(canvas, sprite("title", "title_cauldron"), 0, 0)
    paste(canvas, tint(sprite("title", "title_liquid_0"), liquid), 0, 0)
    bubble_big = tint(sprite("title", "bubble_big"), lighten(liquid, 0.3))
    bubble_small = tint(sprite("title", "bubble_small"), lighten(liquid, 0.45))
    for x, y, big in [(44, 2, True), (63, 6, False), (55, 0, False), (70, 1, True)]:
        paste(canvas, bubble_big if big else bubble_small, x, y)
    return canvas


def shop_cauldron(liquid=LIQUID):
    """The shop's cauldron (scenes/shop.tscn): pot 64 x 56 with its fire 20 px below the
    centre. 64 x 56, transparent."""
    canvas = Image.new("RGBA", (64, 56), (0, 0, 0, 0))
    paste(canvas, sprite("brewing", "fire_0"), 16, 40)
    paste(canvas, sprite("brewing", "cauldron"), 0, 0)
    paste(canvas, tint(sprite("brewing", "cauldron_liquid_0"), liquid), 0, 0)
    return canvas


def starry(width, height, seed_stars):
    """The night wall: NIGHT above, WALL below a third of the way down, a few fixed stars."""
    canvas = Image.new("RGBA", (width, height), NIGHT + (255,))
    draw = ImageDraw.Draw(canvas)
    draw.rectangle((0, height * 2 // 3, width, height), fill=WALL + (255,))
    draw.rectangle((0, height * 2 // 3, width, height * 2 // 3), fill=SHADOW + (255,))
    for x, y, color in seed_stars:
        draw.point((x * width // 100, y * height // 100), fill=color + (255,))
    return canvas


STARS = [(8, 10, CREAM), (22, 30, LILAC), (37, 6, CREAM), (63, 14, LILAC), (80, 8, CREAM),
         (92, 26, LILAC), (14, 52, CREAM), (88, 50, CREAM), (50, 22, GOLD)]


def scaled(image, factor):
    return image.resize((image.width * factor, image.height * factor), Image.NEAREST)


def icon_512():
    canvas = starry(128, 128, STARS)
    paste(canvas, hero(), 8, 24)
    return scaled(canvas, 4)


def icon_1024():
    # iOS masks the corners itself and rejects an alpha channel.
    canvas = starry(128, 128, STARS)
    paste(canvas, hero(), 8, 24)
    return scaled(canvas, 8).convert("RGB")


def icon_192():
    canvas = starry(96, 96, STARS)
    paste(canvas, shop_cauldron(), 16, 24)
    return scaled(canvas, 2)


def adaptive_foreground():
    # 432 px = 108 dp; launchers show at least the 66 dp circle in the centre (264 px, 132 px
    # at the 216 px canvas). The hero's rim and flames stay inside it.
    canvas = Image.new("RGBA", (216, 216), (0, 0, 0, 0))
    paste(canvas, hero(), 52, 64)
    return scaled(canvas, 2)


def adaptive_background():
    return scaled(starry(216, 216, STARS), 2)


def adaptive_monochrome():
    alpha = adaptive_foreground().getchannel("A")
    white = Image.new("RGBA", alpha.size, (255, 255, 255, 0))
    white.putalpha(alpha)
    return white


def feature_graphic():
    canvas = starry(256, 125, STARS)
    paste(canvas, sprite("title", "logo"), 8, 8)
    font = ImageFont.truetype(str(FONT), 8)
    draw = ImageDraw.Draw(canvas)
    for i, line in enumerate(["A cosy potion shop", "for one thumb"]):
        draw.text((10, 52 + i * 11), line, font=font, fill=CREAM + (255,))
    for i, name in enumerate(["ember_pepper", "frost_mint", "sunpetal", "nightshade_cap"]):
        paste(canvas, sprite("ingredients", name), 10 + i * 28, 88)
    paste(canvas, hero(), 140, 37)
    return scaled(canvas, 4).convert("RGB")


OUTPUTS = {
    "brewmagic/icons/icon_192.png": icon_192,
    "brewmagic/icons/adaptive_foreground_432.png": adaptive_foreground,
    "brewmagic/icons/adaptive_background_432.png": adaptive_background,
    "brewmagic/icons/adaptive_monochrome_432.png": adaptive_monochrome,
    "brewmagic/icons/icon_512.png": icon_512,
    "store/play/icon_512.png": lambda: icon_512().convert("RGB"),
    "store/play/feature_graphic.png": feature_graphic,
    "brewmagic/icons/icon_1024.png": icon_1024,
}


def render(make):
    out = io.BytesIO()
    make().save(out, "PNG", optimize=True)
    return out.getvalue()


def main():
    check = "--check" in sys.argv[1:]
    stale = []
    for path, make in OUTPUTS.items():
        target = ROOT / path
        data = render(make)
        if check:
            if not target.exists() or target.read_bytes() != data:
                stale.append(path)
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        print(f"store_art: wrote {path}")
    if check:
        if stale:
            print("store_art: STALE " + ", ".join(stale) + " (run python3 tools/store_art.py)", file=sys.stderr)
            sys.exit(1)
        print(f"store_art: OK ({len(OUTPUTS)} files)")


if __name__ == "__main__":
    main()
