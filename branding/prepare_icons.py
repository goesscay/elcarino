"""Builds every launcher icon from `app-icon-source.png` (the icon exactly as supplied).

The supplied artwork is a white puffy tile (with a soft shadow and glow) holding the red
"e" mark. A phone draws its own rounded tile and shadow, so shipping the tile itself would
put a tile inside a tile. Instead this takes the **mark** from the artwork, exactly as
drawn (its gradients and shading are kept), and places it on white, so the system supplies
the tile. Nothing is redrawn or recoloured.

How the mark is separated from the white tile: the mark is strongly red and the tile is
near-white, so "redness" (R minus the mean of G and B) is ~0 on the tile and 150+ on the
mark. That gives a soft alpha at the edges, and the mark's own colours are un-mixed from
the white so the edge has no pale fringe.

Outputs (from anywhere: `python branding/prepare_icons.py`, needs Pillow):
  - Android legacy `mipmap-*/ic_launcher.png` (rounded white tile, transparent corners)
  - Android adaptive: `mipmap-*/ic_launcher_foreground.png` (the mark, transparent),
    `values/ic_launcher_background.xml` (white), `mipmap-anydpi-v26/ic_launcher.xml`
  - iOS `AppIcon.appiconset/*` (opaque square; iOS rounds it, and rejects an alpha channel)
  - Web `icons/Icon-{192,512}.png`, maskable variants, `favicon.png`
"""
import json
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
MOBILE = os.path.join(HERE, '..', 'mobile')
SOURCE = os.path.join(HERE, 'app-icon-source.png')

WHITE = (255, 255, 255)

# How large the mark is, as a fraction of the icon's width.
FULL_BLEED = 0.75   # matches the mark's share of the supplied tile (864 of ~1155 px)
ADAPTIVE = 0.56     # inside Android's 66/108 adaptive safe zone, with breathing room
MASKABLE = 0.56     # inside the web maskable safe zone (central 80% circle)


def extract_mark() -> Image.Image:
    """The red mark as RGBA, cropped tight."""
    src = Image.open(SOURCE).convert('RGB')
    w, h = src.size
    px = src.load()

    def redness(x, y):
        r, g, b = px[x, y]
        return r - (g + b) / 2

    # Where the mark is: the strongly red pixels. Everything outside that box (plus a small
    # margin for the anti-aliased edge) is tile, shadow or glow and is ignored, so the
    # tile's pink shadow rim can't leak in as specks.
    strong = [(x, y) for y in range(0, h, 2) for x in range(0, w, 2) if redness(x, y) > 100]
    xs, ys = [p[0] for p in strong], [p[1] for p in strong]
    margin = 14
    left, right = max(0, min(xs) - margin), min(w, max(xs) + margin)
    top, bottom = max(0, min(ys) - margin), min(h, max(ys) + margin)

    out = Image.new('RGBA', (w, h))
    op = out.load()
    for y in range(top, bottom):
        for x in range(left, right):
            r, g, b = px[x, y]
            t = min(1.0, max(0.0, (redness(x, y) - 36) / (120 - 36)))
            a = t * t * (3 - 2 * t)  # smoothstep
            if a < 0.004:
                continue
            # Un-mix from white so an edge pixel isn't a pale red at partial alpha.
            e = [max(0, min(255, round((c - (1 - a) * 255) / a))) for c in (r, g, b)]
            op[x, y] = (e[0], e[1], e[2], round(a * 255))
    return out.crop(out.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox())


def place(mark: Image.Image, size: int, fraction: float, background=None) -> Image.Image:
    """The mark centred on a [size]-square canvas at [fraction] of its width."""
    target = round(size * fraction)
    scale = target / max(mark.size)
    scaled = mark.resize((round(mark.size[0] * scale), round(mark.size[1] * scale)), Image.LANCZOS)
    canvas = Image.new('RGBA', (size, size), (*background, 255) if background else (0, 0, 0, 0))
    canvas.alpha_composite(scaled, ((size - scaled.size[0]) // 2, (size - scaled.size[1]) // 2))
    return canvas


def opaque(mark, size, fraction):
    return place(mark, size, fraction, WHITE).convert('RGB')


def rounded_tile(mark, size, fraction):
    """White rounded tile with transparent corners, for pre-Android-8 launchers."""
    tile = place(mark, size, fraction, WHITE)
    mask = Image.new('L', (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size * 4 - 1, size * 4 - 1), radius=size * 4 * 0.22, fill=255)
    tile.putalpha(mask.resize((size, size), Image.LANCZOS))
    return tile


def save(img: Image.Image, *path: str) -> None:
    dest = os.path.join(MOBILE, *path)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    img.save(dest, optimize=True)


def main() -> None:
    mark = extract_mark()
    print('mark', mark.size)

    res = ('android', 'app', 'src', 'main', 'res')
    # Android: legacy launcher icon (dp * density) and adaptive foreground (108dp * density).
    for folder, density in (('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2), ('xxhdpi', 3), ('xxxhdpi', 4)):
        save(rounded_tile(mark, round(48 * density), FULL_BLEED), *res, f'mipmap-{folder}', 'ic_launcher.png')
        save(place(mark, round(108 * density), ADAPTIVE), *res, f'mipmap-{folder}', 'ic_launcher_foreground.png')

    def write(rel, text):
        dest = os.path.join(MOBILE, *rel)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        open(dest, 'w', encoding='utf-8', newline='\n').write(text)

    write((*res, 'values', 'ic_launcher_background.xml'),
          '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
          '    <color name="ic_launcher_background">#FFFFFF</color>\n</resources>\n')
    write((*res, 'mipmap-anydpi-v26', 'ic_launcher.xml'),
          '<?xml version="1.0" encoding="utf-8"?>\n'
          '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
          '    <background android:drawable="@color/ic_launcher_background"/>\n'
          '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
          '</adaptive-icon>\n')

    # iOS: every size the icon set lists, opaque (no alpha channel), square (iOS rounds it).
    ios = os.path.join(MOBILE, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    contents = json.load(open(os.path.join(ios, 'Contents.json'), encoding='utf-8'))
    for entry in contents['images']:
        points = float(entry['size'].split('x')[0])
        px = round(points * int(entry['scale'].rstrip('x')))
        opaque(mark, px, FULL_BLEED).save(os.path.join(ios, entry['filename']), optimize=True)

    # Web: 192/512, maskable variants (inside the safe zone), and the favicon.
    for size in (192, 512):
        save(opaque(mark, size, FULL_BLEED), 'web', 'icons', f'Icon-{size}.png')
        save(opaque(mark, size, MASKABLE), 'web', 'icons', f'Icon-maskable-{size}.png')
    save(opaque(mark, 32, FULL_BLEED), 'web', 'favicon.png')

    # A preview sheet for eyeballing (not committed).
    sheet = Image.new('RGB', (1500, 520), (180, 190, 200))
    x = 30
    for label, img in (
        ('ios', opaque(mark, 400, FULL_BLEED)),
        ('legacy', rounded_tile(mark, 400, FULL_BLEED).convert('RGBA')),
    ):
        sheet.paste(img, (x, 60), img if img.mode == 'RGBA' else None)
        x += 440
    # Adaptive icon under a circle mask, the harshest common launcher shape.
    adaptive = place(mark, 432, ADAPTIVE, WHITE)
    circle = Image.new('L', (432, 432), 0)
    ImageDraw.Draw(circle).ellipse((432 * 0.1667, 432 * 0.1667, 432 * 0.8333, 432 * 0.8333), fill=255)
    visible = Image.new('RGBA', (432, 432), (0, 0, 0, 0))
    visible.paste(adaptive, mask=circle)
    sheet.paste(visible, (x + 20, 50), visible)
    # Only when asked (ICON_PREVIEW_DIR=...): never drops a stray file into the repo.
    if os.environ.get('ICON_PREVIEW_DIR'):
        sheet.save(os.path.join(os.environ['ICON_PREVIEW_DIR'], 'icon_preview.png'))
    print('done')


if __name__ == '__main__':
    main()
