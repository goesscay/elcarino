"""Regenerates `elcarino-logo.png` from `elcarino-logo-source.png`.

The source is the logo exactly as supplied. The in-app PNG is that same artwork with
two mechanical changes and nothing else — no redrawing, no recolouring:

1. The empty margin is trimmed, so a width-sized `AppLogo` isn't mostly whitespace.
2. The white background is made transparent, so it works on both the light and the dark
   surfaces. Colour-to-alpha against white: each pixel becomes
   `alpha * logo-red + (1 - alpha) * white`, so anti-aliased edges turn into smooth
   partial transparency and the logo's own red is kept exactly.

It also writes the logo in **white** (the same artwork and the same alpha, with the red
replaced by white) for the splash screen, which is white on a solid logo-red background:
`elcarino-logo-white.png`, and the two launch-screen inputs in `mobile/tool/splash/`.

Run from anywhere:  python branding/prepare_logo.py     (needs Pillow)
Then copy `elcarino-logo.png` to mobile/assets/branding/elcarino-logo.png and
`elcarino-logo-white.png` to mobile/assets/branding/elcarino-logo-white.png (byte-for-byte
copies), and regenerate the native launch screens:  cd mobile && dart run flutter_native_splash:create
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

    # White version: identical alpha, colour replaced by white.
    white = Image.new('RGBA', out.size, (255, 255, 255, 0))
    white.putalpha(out.getchannel('A'))
    white.save(os.path.join(HERE, 'elcarino-logo-white.png'), optimize=True)
    print('wrote elcarino-logo-white.png', white.size)

    # Launch-screen inputs for flutter_native_splash. It treats an image as 4x density, so the
    # pixel widths below are 4 x the dp width the logo will have on screen.
    splash = os.path.join(HERE, '..', 'mobile', 'tool', 'splash')
    os.makedirs(splash, exist_ok=True)
    logo_dp = 170
    scaled = white.resize((logo_dp * 4, round(white.size[1] * logo_dp * 4 / white.size[0])), Image.LANCZOS)
    scaled.save(os.path.join(splash, 'splash_logo.png'), optimize=True)
    # Android 12+ draws the splash image inside a circle (192 of 288 dp is visible), so a wide
    # wordmark has to be small enough that its corners stay inside that circle: on a 288 dp
    # canvas the logo is 170 dp wide, which fits with room to spare.
    canvas = Image.new('RGBA', (288 * 4, 288 * 4), (255, 255, 255, 0))
    canvas.alpha_composite(scaled, ((canvas.size[0] - scaled.size[0]) // 2, (canvas.size[1] - scaled.size[1]) // 2))
    canvas.save(os.path.join(splash, 'splash_android12.png'), optimize=True)
    print('wrote mobile/tool/splash/splash_logo.png, splash_android12.png')


if __name__ == '__main__':
    main()
