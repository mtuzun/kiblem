"""Builds all app icons from assets/logo_source_flat.png (round badge on an off-white page).

The badge's own off-white disc becomes the icon background, so the artwork is used as designed.
Older sources are kept for reference: assets/logo_source.jpg (cutout(), navy background) and
assets/logo_source_badge.png (cutout_badge()).

Run from the project root:  py tools/make_logo_icons.py
"""
import glob
import os
from collections import deque

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

SRC = 'assets/logo_source.jpg'
BADGE = 'assets/logo_source_badge.png'
# Badge circle in source pixels (gold ring centre / radius).
BADGE_C = (128, 137, 114)
FLAT = 'assets/logo_source_flat.png'
FLAT_C = (482, 538, 440)  # disc centre / usable radius in source pixels
RES = 'android/app/src/main/res'
IOS = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'


NAVY_TOP = NAVY_BOTTOM = (255, 253, 252)  # background colour (solid; kept as a gradient for navy variants)


def cutout(path):
    """White background -> transparent (only white connected to the border)."""
    big = Image.open(path).convert('RGB')
    big = big.resize((big.width * 4, big.height * 4), Image.LANCZOS)
    w, h = big.size
    px = big.load()
    near_white = lambda p: min(p) >= 240
    seen = bytearray(w * h)
    q = deque()
    for x in range(w):
        q.append((x, 0)); q.append((x, h - 1))
    for y in range(h):
        q.append((0, y)); q.append((w - 1, y))
    while q:
        x, y = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h or seen[y * w + x]:
            continue
        if not near_white(px[x, y]):
            continue
        seen[y * w + x] = 1
        q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    bg = Image.frombytes('L', (w, h), bytes(255 if s else 0 for s in seen))
    # Grow the background a few px so no white fringe survives on dark backgrounds.
    bg = bg.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(2))
    alpha = bg.point(lambda v: 255 - v)
    out = big.convert('RGBA')
    out.putalpha(alpha)
    return out.crop(out.getbbox())


def cutout_badge(path):
    """Round badge -> transparent logo: drops the page background and the badge's white disc,
    and the gold ring."""
    K = 4
    src = Image.open(path).convert('RGB')
    big = src.resize((src.width * K, src.height * K), Image.LANCZOS)
    cx, cy, r = (v * K for v in BADGE_C)
    inner = Image.new('L', big.size, 0)
    ImageDraw.Draw(inner).ellipse((cx - r + 4 * K, cy - r + 4 * K, cx + r - 4 * K, cy + r - 4 * K), fill=255)
    px = big.load()
    white = Image.new('L', big.size, 0)
    wp = white.load()
    for y in range(big.height):
        for x in range(big.width):
            p = px[x, y]
            if min(p) >= 236 and max(p) - min(p) <= 14:
                wp[x, y] = 255
    white = white.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(1.5))
    alpha = ImageChops.multiply(inner, ImageOps.invert(white))
    logo = big.convert('RGBA')
    logo.putalpha(alpha)
    # The badge's gold ring is dropped on purpose: only the crescent and mosque remain.
    return logo.crop(logo.getbbox())



def cutout_flat(path):
    """Keep the badge's disc (feathered edge) and drop the page background around it.

    The result is cropped around the artwork's own centre (not the disc's), so the crescent and
    mosque sit optically centred in every icon.
    """
    src = Image.open(path).convert('RGBA')
    cx, cy, r = FLAT_C
    m = Image.new('L', src.size, 0)
    ImageDraw.Draw(m).ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    ink = src.convert('RGB').point(lambda v: 255 if v < 215 else 0).split()
    ink = ImageChops.lighter(ImageChops.lighter(ink[0], ink[1]), ink[2])  # any channel clearly non-white
    x0, y0, x1, y1 = ImageChops.multiply(ink, m).getbbox()
    mx, my = (x0 + x1) // 2, (y0 + y1) // 2
    src.putalpha(m.filter(ImageFilter.GaussianBlur(6)))
    half = r + 8
    padded = Image.new('RGBA', (src.width + 2 * half, src.height + 2 * half), (0, 0, 0, 0))
    padded.alpha_composite(src, (half, half))
    return padded.crop((mx, my, mx + 2 * half, my + 2 * half))


def gradient(size):
    g = Image.new('RGB', (size, size))
    d = ImageDraw.Draw(g)
    for y in range(size):
        t = y / (size - 1)
        d.line((0, y, size, y), fill=tuple(round(a + (b - a) * t) for a, b in zip(NAVY_TOP, NAVY_BOTTOM)))
    return g.convert('RGBA')


def canvas(logo, size, fill, bg=None, shadow=False):
    """Logo scaled so its larger side is `fill` * size, centered."""
    scale = size * fill / max(logo.size)
    l = logo.resize((max(1, round(logo.width * scale)), max(1, round(logo.height * scale))), Image.LANCZOS)
    c = bg.copy() if bg else Image.new('RGBA', (size, size), (0, 0, 0, 0))
    pos = ((size - l.width) // 2, (size - l.height) // 2)
    if shadow:
        sh = Image.new('RGBA', l.size, (0, 0, 0, 255))
        sh.putalpha(l.split()[3].point(lambda v: round(v * 0.45)))
        layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        layer.alpha_composite(sh, (pos[0], pos[1] + max(1, size // 70)))
        c.alpha_composite(layer.filter(ImageFilter.GaussianBlur(max(1, size // 100))))
    c.alpha_composite(l, pos)
    return c


def rounded(img, radius_frac=0.22):
    m = Image.new('L', img.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, img.width - 1, img.height - 1), radius=round(img.width * radius_frac), fill=255)
    out = img.copy(); out.putalpha(m)
    return out


logo = cutout_flat(FLAT)

# Transparent master (also read by flutter_launcher_icons).
canvas(logo, 1024, 0.92).save('assets/icon.png')

# Android adaptive icon: gradient background + foreground inside the 66% safe zone.
for d, px in {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432}.items():
    canvas(logo, px, 0.66).save(f'{RES}/mipmap-{d}/ic_launcher_foreground.png')
os.makedirs(f'{RES}/mipmap-anydpi-v26', exist_ok=True)
ADAPTIVE_XML = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""
BACKGROUND_XML = """<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <gradient android:angle="270" android:startColor="#%02X%02X%02X" android:endColor="#%02X%02X%02X"/>
</shape>
""" % (NAVY_TOP + NAVY_BOTTOM)
with open(f'{RES}/mipmap-anydpi-v26/ic_launcher.xml', 'w') as f:
    f.write(ADAPTIVE_XML)
with open(f'{RES}/drawable/ic_launcher_background.xml', 'w') as f:
    f.write(BACKGROUND_XML)
old = f'{RES}/values/ic_launcher_background.xml'
if os.path.exists(old):
    os.remove(old)

# Legacy (pre-Android 8) icons: rounded navy square.
for d, px in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
    rounded(canvas(logo, px, 0.92, gradient(px))).save(f'{RES}/mipmap-{d}/ic_launcher.png')

# Play Store + iOS: opaque full-bleed square (stores/OS apply their own rounding).
canvas(logo, 512, 0.92, gradient(512)).convert('RGB').save('assets/icon_playstore_512.png')
big = canvas(logo, 1024, 0.92, gradient(1024)).convert('RGB')
big.save('assets/icon_square.png')
for p in glob.glob(f'{IOS}/*.png'):
    n = Image.open(p).size[0]
    big.resize((n, n), Image.LANCZOS).save(p)
print('done')
