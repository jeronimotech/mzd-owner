# Original app icon for "Mi Mazda" (mzd-owner): gauge arc + needle + motion swoosh.
# Not Mazda's logo: no winged "M", no oval emblem.
import math, sys
from PIL import Image, ImageDraw, ImageFilter

S = 4096  # supersampled canvas, downscaled to 1024 for anti-aliasing
out = sys.argv[1]

img = Image.new("RGB", (S, S))
px = img.load()
# Background: diagonal gradient deep charcoal -> near black with a red glow bottom-left
for y in range(S):
    for x in range(S):
        t = (x + y) / (2 * S)
        r = int(34 * (1 - t) + 8 * t)
        g = int(14 * (1 - t) + 9 * t)
        b = int(20 * (1 - t) + 12 * t)
        px[x, y] = (r, g, b)
glow = Image.new("L", (S, S), 0)
ImageDraw.Draw(glow).ellipse([-S * 0.25, S * 0.35, S * 0.75, S * 1.35], fill=150)
glow = glow.filter(ImageFilter.GaussianBlur(S * 0.12))
red = Image.new("RGB", (S, S), (200, 16, 46))
img = Image.composite(red, img, glow)

d = ImageDraw.Draw(img)
cx, cy, R = S * 0.5, S * 0.47, S * 0.29
W = int(S * 0.075)
box = [cx - R, cy - R, cx + R, cy + R]
start, end = 135, 405  # 270° gauge, opening at the bottom
# track
d.arc(box, start, end, fill=(58, 60, 68), width=W)
# progress (Soul Red -> bright red), drawn in small steps for a gradient
steps = 180
prog_end = start + 270 * 0.72
for i in range(steps):
    a0 = start + (prog_end - start) * i / steps
    a1 = start + (prog_end - start) * (i + 1.2) / steps
    t = i / steps
    col = (int(170 + 85 * t), int(10 + 40 * t), int(40 + 25 * t))
    d.arc(box, a0, a1, fill=col, width=W)
# rounded caps
for a, col in ((start, (170, 10, 40)), (prog_end, (255, 50, 65))):
    rad = math.radians(a)
    x, y = cx + R * math.cos(rad), cy + R * math.sin(rad)
    d.ellipse([x - W / 2, y - W / 2, x + W / 2, y + W / 2], fill=col)
# needle pointing at the progress end
rad = math.radians(prog_end)
tip = (cx + (R - W * 1.1) * math.cos(rad), cy + (R - W * 1.1) * math.sin(rad))
perp = rad + math.pi / 2
base_w = S * 0.03
p1 = (cx + base_w * math.cos(perp), cy + base_w * math.sin(perp))
p2 = (cx - base_w * math.cos(perp), cy - base_w * math.sin(perp))
d.polygon([p1, tip, p2], fill=(245, 245, 247))
hub = S * 0.065
d.ellipse([cx - hub, cy - hub, cx + hub, cy + hub], fill=(245, 245, 247))
d.ellipse([cx - hub * 0.45, cy - hub * 0.45, cx + hub * 0.45, cy + hub * 0.45], fill=(200, 16, 46))
# motion swoosh under the gauge (two tapered strokes)
for k, (off, alpha_w) in enumerate(((0.0, 1.0), (0.055, 0.6))):
    pts = []
    for i in range(101):
        t = i / 100
        x = S * (0.24 + 0.52 * t)
        y = S * (0.815 + off) - math.sin(t * math.pi) * S * 0.035
        pts.append((x, y))
    for i in range(100):
        t = i / 100
        w = max(1, int(S * 0.018 * alpha_w * math.sin(t * math.pi) + 2))
        shade = 235 if k == 0 else 150
        d.line([pts[i], pts[i + 1]], fill=(shade, shade, shade + 4), width=w)

img = img.resize((1024, 1024), Image.LANCZOS)
img.save(out)
print("saved", out)
