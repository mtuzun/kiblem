from PIL import Image, ImageDraw, ImageFilter

W = H = 1024
img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

# Background glow circle (golden yellow)
for radius in (430, 410, 390):
    x0 = W // 2 - radius
    y0 = H // 2 - radius
    x1 = W // 2 + radius
    y1 = H // 2 + radius
    if radius == 430:
        d.ellipse((x0, y0, x1, y1), fill=(243, 210, 94, 255))
    else:
        d.ellipse((x0, y0, x1, y1), outline=(240, 214, 118, 200), width=8)

# Crescent green shape
crescent = Image.new('RGBA', (W, H), (0, 0, 0, 0))
cd = ImageDraw.Draw(crescent)
cd.ellipse((0, 20, 930, 1020), fill=(16, 158, 70, 255))
# carve a black hole on right side to create crescent
cd.ellipse((300, 44, 930, 1000), fill=(0, 0, 0, 255))
# soften border
crescent = crescent.filter(ImageFilter.GaussianBlur(2))
img = Image.alpha_composite(img, crescent)

# Book pages (open Quran-like book)
book = Image.new('RGBA', (W, H), (0, 0, 0, 0))
bd = ImageDraw.Draw(book)

# page polygons
bd.polygon([(190, 430), (470, 430), (820, 610), (560, 610)], fill=(245, 238, 220, 255))
bd.polygon([(420, 430), (860, 430), (600, 610), (560, 610)], fill=(236, 230, 220, 255))

# page edges
bd.rounded_rectangle((190, 405, 825, 445), radius=16, fill=(118, 93, 71, 255))
bd.rounded_rectangle((270, 395, 785, 430), radius=12, fill=(245, 238, 220, 255))

# page lines
for i in range(1, 11):
    y = 460 + i * 12
    bd.line((230, y, 470, y), fill=(200, 190, 175, 255), width=3)
    bd.line((470, y, 620, y), fill=(200, 190, 175, 255), width=3)
    bd.line((580, y, 780, y), fill=(200, 190, 175, 255), width=3)

# stand base
stand = Image.new('RGBA', (W, H), (0, 0, 0, 0))
sd = ImageDraw.Draw(stand)
sd.rounded_rectangle((160, 610, 860, 675), radius=18, fill=(146, 90, 50, 255))
sd.polygon([(170, 610), (440, 610), (500, 740), (160, 740)], fill=(119, 82, 42, 255))
sd.polygon([(660, 610), (850, 610), (860, 740), (540, 740)], fill=(119, 82, 42, 255))

# center stand details
sd.polygon([(485, 700), (550, 700), (560, 790), (500, 790)], fill=(120, 82, 42, 255))
sd.polygon([(485, 700), (550, 700), (660, 790), (600, 790)], fill=(120, 82, 42, 255))

# soft shadow under object
shadow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
shd = ImageDraw.Draw(shadow)
shd.ellipse((60, 780, 960, 980), fill=(150, 176, 194, 130))

img = Image.alpha_composite(img, book)
img = Image.alpha_composite(img, stand)
img = Image.alpha_composite(img, shadow)

# Save as project asset
asset_path = 'assets/icon.png'
img.save(asset_path)
print(f'Saved {asset_path}')
