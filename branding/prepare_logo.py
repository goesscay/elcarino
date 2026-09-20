"""Regenerates `elcarino-logo.png` from `elcarino-logo-source.png`.

The source is the logo exactly as supplied. The in-app PNG is that same artwork with
two mechanical changes and nothing else — no redrawing, no recolouring:

1. The empty margin is trimmed, so a width-sized `AppLogo` isn't mostly whitespace.
2. The white background is made transparent, so it works on both the light and the dark
   surfaces. Colour-to-alpha against white: each pixel becomes
   `alpha * logo-red + (1 - alpha) * white`, so anti-aliased edges turn into smooth
   partial transparency and the logo's own red is kept exactly.

Run from anywhere:  python branding/prepare_logo.py     (needs Pillow)
Then copy the result to mobile/assets/branding/elcarino-logo.png (a byte-for-byte copy).
"""
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))

# The logo's red, sampled from a solid interior pixel of the supplied file.
RED = (216, 29, 31)


def main() -> None:
    src = Image.open(os.path.join(HERE, 'elcarino-logo-source.png')).convert('RGB')
    w, h = src.size
    px = src.load()

    out = Image.new('RGBA', (w, h))
    op = out.load()
    for y in range(h):
        for x in range(w):
            alpha = (255 - px[x, y][1]) / (255 - RED[1])
            # The source is lossy: drop near-white speckle, snap near-solid to solid.
            alpha = 0.0 if alpha < 0.03 else 1.0 if alpha > 0.97 else alpha
            op[x, y] = (*RED, round(alpha * 255))

    # Trim, keeping a few pixels so anti-aliasing is never clipped.
    left, top, right, bottom = out.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox()
    pad = 6
    out = out.crop((max(0, left - pad), max(0, top - pad), min(w, right + pad), min(h, bottom + pad)))
    out.save(os.path.join(HERE, 'elcarino-logo.png'), optimize=True)
    print('wrote elcarino-logo.png', out.size)


if __name__ == '__main__':
    main()
