"""Realto app icon (Monteo-inspired): blue→peach canvas, white house, gradient play.

Usage: python3 Scripts/generate-app-icon.py <out-dir>
Writes ios-1024.png (→ AppIcon-1024.png) and mac-<px>.png (→ AppIcon-mac-<px>.png).
Needs Pillow and numpy."""
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageChops

S = 4096  # draw large, downsample for smooth edges
OUT = sys.argv[1]

def lerp(a, b, t): return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))

import numpy as np

def diagonal_gradient(size, *stops):
    """Top-left → bottom-right gradient through evenly spaced colour stops."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    t = (x + y) / (2 * (size - 1))
    c = np.array(stops, dtype=np.float32)
    pos = np.linspace(0, 1, len(stops))
    rgb = np.stack([np.interp(t, pos, c[:, i]) for i in range(3)], axis=-1)
    return Image.fromarray(rgb.round().astype(np.uint8), "RGB")

def rounded_polygon_mask(size, pts, radius):
    """Polygon with softened corners: blur + threshold rounds corners, edges stay put."""
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    m = m.filter(ImageFilter.GaussianBlur(radius)).point(lambda v: 255 if v >= 128 else 0)
    return m.filter(ImageFilter.GaussianBlur(1.5))

BLUE = (107, 158, 235); PEACH = (250, 199, 140)
PRIMARY_A = (97, 140, 250); PRIMARY_B = (128, 102, 242)

# Canvas
img = diagonal_gradient(S, (90, 135, 242), (155, 150, 238), (252, 192, 148))
glow = Image.new("RGB", (S, S), (255, 255, 255))
gm = Image.new("L", (S, S), 0)
ImageDraw.Draw(gm).ellipse((-S * 0.25, -S * 0.3, S * 0.75, S * 0.55), fill=70)
img = Image.composite(glow, img, gm.filter(ImageFilter.GaussianBlur(S * 0.12)))

# House silhouette (roof + body), rounded
u = S / 1024
house = [(512 * u, 210 * u), (812 * u, 470 * u), (742 * u, 470 * u), (742 * u, 800 * u),
         (282 * u, 800 * u), (282 * u, 470 * u), (212 * u, 470 * u)]
r = int(16 * u)
hmask = rounded_polygon_mask(S, house, r)

# Soft drop shadow
shadow = hmask.filter(ImageFilter.GaussianBlur(40 * u)).point(lambda v: v * 0.35)
shadow = ImageChops.offset(shadow, 0, int(28 * u))
img = Image.composite(Image.new("RGB", (S, S), (40, 52, 110)), img, shadow)
img = Image.composite(Image.new("RGB", (S, S), (255, 255, 255)), img, hmask)

# Play triangle with primary gradient
tri = [(452 * u, 530 * u), (452 * u, 740 * u), (630 * u, 635 * u)]
tr = int(11 * u)
tmask = rounded_polygon_mask(S, tri, tr)
img = Image.composite(diagonal_gradient(S, PRIMARY_A, PRIMARY_B), img, tmask)

base = img.resize((1024, 1024), Image.LANCZOS)
base.save(f"{OUT}/ios-1024.png")

# macOS: rounded-rect tile with transparent margin (Big Sur grid: 824pt body, ~185pt radius)
def mac_icon(px):
    body = int(px * 824 / 1024); off = (px - body) // 2
    big = 4
    m = Image.new("L", (px * big, px * big), 0)
    ImageDraw.Draw(m).rounded_rectangle(
        (off * big, off * big, (off + body) * big, (off + body) * big), radius=int(body * 0.225 * big), fill=255)
    m = m.resize((px, px), Image.LANCZOS)
    shadow = m.filter(ImageFilter.GaussianBlur(max(1, px * 0.012)))
    shadow = ImageChops.offset(shadow, 0, max(1, int(px * 0.01))).point(lambda v: v * 0.3)
    out = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    out.paste(Image.new("RGBA", (px, px), (0, 0, 0, 255)), (0, 0), shadow)
    art = base.resize((body, body), Image.LANCZOS).convert("RGBA")
    layer = Image.new("RGBA", (px, px), (0, 0, 0, 0)); layer.paste(art, (off, off))
    out = Image.composite(layer, out, m)
    return out

for px in (16, 32, 64, 128, 256, 512, 1024):
    mac_icon(px).save(f"{OUT}/mac-{px}.png")
print("done")
