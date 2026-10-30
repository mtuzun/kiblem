"""Layout experiments: splits the logo into crescent + mosque layers. Output: logo_layout_variants.png"""
import sys
from collections import deque
from PIL import Image, ImageDraw, ImageFilter, ImageOps

K = 4
exec(open('tools/make_logo_icons.py', encoding='utf-8').read().split('logo = cutout(SRC)')[0].replace('def cutout(path):', 'def _cutout_cropped(path):', 1).replace('return out.crop(out.getbbox())', 'return out'))
full = _cutout_cropped('assets/logo_source.jpg')  # RGBA, 1440x1440, alpha = logo
W = full.width
Ho = (218.02, 151.05, 115.37)   # hole circle (source px)
Ou = (179.46, 188.50, 141.50)   # outer circle

def disk(c, grow=0):
    m = Image.new('L', (W, W), 0)
    cx, cy, r = c
    ImageDraw.Draw(m).ellipse(((cx - r - grow) * K, (cy - r - grow) * K, (cx + r + grow) * K, (cy + r + grow) * K), fill=255)
    return m

alpha = full.split()[3]
inO = disk(Ou, 2)
inH_shrunk = disk(Ho, -1.5)
inH_grown = disk(Ho, 0.5)
# crescent = inside outer, outside hole
cres_m = ImageChops_mul = None
from PIL import ImageChops
cres_m = ImageChops.multiply(inO, ImageOps.invert(inH_grown))
cres = full.copy(); cres.putalpha(ImageChops.multiply(alpha, cres_m))
# mosque = everything else, clipped slightly inside the hole where it is behind the crescent
outside_O = ImageOps.invert(inO)
mosque_m = ImageChops.lighter(inH_shrunk, outside_O)
# above/outside the circles (minaret tips) is also mosque
mos = full.copy(); mos.putalpha(ImageChops.multiply(alpha, mosque_m))
cres.save('scratch_cres.png'); mos.save('scratch_mos.png')

# ---- clean the mosque layer: drop crescent slivers, give it a flat base ----
px = mos.load()
for y in range(W):
    for x in range(W):
        if x < 121 * K or (x < 200 * K and y < 75 * K) or (x < 165 * K and y < 130 * K) or y > 266 * K:
            px[x, y] = (0, 0, 0, 0)
base_y = 258 * K
x0, x1 = 122 * K, 268 * K
for x in range(x0, x1):
    ys = [y for y in range(150 * K, base_y) if px[x, y][3] > 200]
    if not ys:
        continue
    yb = max(ys)
    if yb >= base_y - 2:
        continue
    col = px[x, yb - 6 * K]
    for y in range(yb, base_y):
        px[x, y] = col
d = ImageDraw.Draw(mos)
d.rectangle((x0, base_y, x1, base_y + 7 * K), fill=(22, 116, 62, 255))
mos = mos.crop(mos.getbbox())

def place(canvas, layer, cx, base, scale, flip=False):
    l = layer.resize((round(layer.width * scale), round(layer.height * scale)), Image.LANCZOS)
    if flip: l = ImageOps.mirror(l)
    canvas.alpha_composite(l, (round(cx - l.width / 2), round(base - l.height)))

C = 1200
def blank(): return Image.new('RGBA', (C, C), (0, 0, 0, 0))

variants = {}

# 1. mirrored: crescent on the right, mosque inside, nothing else changes
v = blank(); logo_full = full.crop(full.getbbox())
v.alpha_composite(ImageOps.mirror(logo_full).resize((1000, round(1000 * logo_full.height / logo_full.width)), Image.LANCZOS), (100, 100))
variants['1 ayna'] = v

# 2/3. roof: crescent opens downwards over the mosque (mosque in front)
cr = cres.rotate(-134, resample=Image.BICUBIC, center=(Ou[0] * K, Ou[1] * K))
cr = cr.crop(cr.getbbox())
for name, cw, top, m_h, base in (('2 çatı', 1000, 60, 640, 1110), ('3 çatı (büyük cami)', 900, 60, 760, 1130)):
    s_ = cw / cr.width
    c2 = cr.resize((cw, round(cr.height * s_)), Image.LANCZOS)
    v = blank(); v.alpha_composite(c2, ((C - cw) // 2, top))
    place(v, mos, C / 2, base, m_h / mos.height)
    variants[name] = v

names = list(variants)
sheet = Image.new('RGB', (3 * 620, 640), (240, 240, 244))
dd = ImageDraw.Draw(sheet)
for i, n in enumerate(names):
    t = variants[n].resize((600, 600), Image.LANCZOS)
    bg = Image.new('RGBA', (600, 600), (255, 255, 255, 255)); bg.alpha_composite(t)
    sheet.paste(bg.convert('RGB'), (10 + i * 620, 10))
    dd.text((10 + i * 620, 612), n, fill=(0, 0, 0))
sheet.save('logo_layout_variants.png')
import pickle
