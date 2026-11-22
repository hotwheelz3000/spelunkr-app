#!/usr/bin/env python3
"""Draw the SPELUNKR placeholder icon: a retro TV full of static on the site's purple.

Usage: make-app-icon.py <output.png>   (1024x1024 opaque PNG, needs Pillow)
"""
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

S = 1024
PURPLE = (0x1C, 0x0A, 0x57)
GLOW = (0x6B, 0x3C, 0xFF)
BODY = (0xF2, 0xE9, 0xFF)
ACCENT = (0xFF, 0x4F, 0xA3)

img = Image.new("RGB", (S, S), PURPLE)

# Soft glow behind the TV.
glow = Image.new("RGB", (S, S), PURPLE)
ImageDraw.Draw(glow).ellipse((170, 230, 854, 914), fill=GLOW)
img = Image.blend(img, glow.filter(ImageFilter.GaussianBlur(120)), 0.55)
d = ImageDraw.Draw(img)

# Antennas.
d.line((512, 300, 360, 150), fill=BODY, width=26)
d.line((512, 300, 664, 150), fill=BODY, width=26)
for x in (360, 664):
    d.ellipse((x - 26, 124, x + 26, 176), fill=ACCENT)

# Body.
d.rounded_rectangle((170, 290, 854, 820), radius=90, fill=BODY)
# Feet.
d.rounded_rectangle((260, 800, 340, 870), radius=20, fill=BODY)
d.rounded_rectangle((684, 800, 764, 870), radius=20, fill=BODY)

# Screen full of static.
sx0, sy0, sx1, sy1 = 230, 350, 700, 760
screen = Image.new("RGB", (sx1 - sx0, sy1 - sy0))
rnd = random.Random(1999)
px = screen.load()
for y in range(screen.height):
    band = 18 if (y // 6) % 9 == 0 else 0
    for x in range(screen.width):
        v = rnd.randint(40, 230) + band
        v = min(v, 255)
        px[x, y] = (int(v * 0.55), int(v * 0.45), v)
mask = Image.new("L", screen.size, 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, screen.width - 1, screen.height - 1), radius=60, fill=255)
img.paste(screen, (sx0, sy0), mask)

# Knobs.
d.ellipse((738, 400, 808, 470), fill=ACCENT)
d.ellipse((738, 510, 808, 580), fill=PURPLE)
for y in (630, 670, 710):
    d.rounded_rectangle((738, y, 808, y + 16), radius=8, fill=PURPLE)

img.save(sys.argv[1], "PNG")
