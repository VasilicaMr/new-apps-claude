#!/usr/bin/env python3
"""
Draws the FleetCheck app icon (1024x1024) into the asset catalog:
a white map pin with a car inside, over tracking-radius rings on a navy→teal gradient.
Also writes dark and tinted variants for iOS 18+ home screens.

    python3 Scripts/generate_icon.py
"""

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
SCALE = 4  # draw big, downsample for clean anti-aliasing
OUT = Path(__file__).resolve().parent.parent / "FleetCheck" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset"

NAVY = (14, 34, 82)
TEAL = (18, 170, 160)


def gradient(size, top, bottom):
    img = Image.new("RGB", (size, size))
    draw = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1)
        color = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        draw.line([(0, y), (size, y)], fill=color)
    return img


def draw_icon(background, ring_color, pin_color, car_color, shadow=True):
    s = SIZE * SCALE
    img = background(s).convert("RGBA")
    cx, cy = s // 2, int(s * 0.80)  # rings radiate from the pin tip

    rings = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rings)
    for i, radius in enumerate([0.16, 0.30, 0.44, 0.58]):
        r = int(s * radius)
        alpha = int(ring_color[3] * (1 - i * 0.2))
        rd.ellipse([cx - r, cy - int(r * 0.42), cx + r, cy + int(r * 0.42)],
                   outline=ring_color[:3] + (alpha,), width=int(s * 0.012))
    img = Image.alpha_composite(img, rings)

    # Map pin: circle head + triangle tail.
    pin = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    pd = ImageDraw.Draw(pin)
    head_r = int(s * 0.27)
    head_c = (s // 2, int(s * 0.41))
    pd.ellipse([head_c[0] - head_r, head_c[1] - head_r, head_c[0] + head_r, head_c[1] + head_r], fill=pin_color)
    pd.polygon([(head_c[0] - int(head_r * 0.80), head_c[1] + int(head_r * 0.60)),
                (head_c[0] + int(head_r * 0.80), head_c[1] + int(head_r * 0.60)),
                (cx, cy)], fill=pin_color)

    if shadow:
        sh = pin.split()[3].filter(ImageFilter.GaussianBlur(s * 0.02))
        shadow_layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        shadow_layer.putalpha(sh.point(lambda a: int(a * 0.35)))
        img = Image.alpha_composite(img, shadow_layer.transform((s, s), Image.AFFINE, (1, 0, 0, 0, 1, -int(s * 0.015))))
    img = Image.alpha_composite(img, pin)

    # Car (front-three-quarter silhouette) inside the pin head.
    car = ImageDraw.Draw(img)
    w = head_r * 1.25
    left, right = head_c[0] - w / 2, head_c[0] + w / 2
    body_top, body_bottom = head_c[1] - head_r * 0.02, head_c[1] + head_r * 0.36
    car.rounded_rectangle([left, body_top, right, body_bottom], radius=int(head_r * 0.14), fill=car_color)
    cabin = [(left + w * 0.16, body_top + 2), (left + w * 0.30, head_c[1] - head_r * 0.36),
             (right - w * 0.30, head_c[1] - head_r * 0.36), (right - w * 0.16, body_top + 2)]
    car.polygon(cabin, fill=car_color)
    # windows
    win_inset = w * 0.06
    car.polygon([(left + w * 0.24, body_top - head_r * 0.02), (left + w * 0.33, head_c[1] - head_r * 0.28),
                 (head_c[0] - win_inset / 2, head_c[1] - head_r * 0.28), (head_c[0] - win_inset / 2, body_top - head_r * 0.02)],
                fill=pin_color)
    car.polygon([(head_c[0] + win_inset / 2, body_top - head_r * 0.02), (head_c[0] + win_inset / 2, head_c[1] - head_r * 0.28),
                 (right - w * 0.33, head_c[1] - head_r * 0.28), (right - w * 0.24, body_top - head_r * 0.02)],
                fill=pin_color)
    # wheels
    wheel_r = head_r * 0.13
    for wx in (left + w * 0.24, right - w * 0.24):
        car.ellipse([wx - wheel_r, body_bottom - wheel_r * 0.6, wx + wheel_r, body_bottom + wheel_r * 1.4], fill=car_color)
        car.ellipse([wx - wheel_r * 0.45, body_bottom - wheel_r * 0.05, wx + wheel_r * 0.45, body_bottom + wheel_r * 0.85], fill=pin_color)
    # headlights
    light_r = head_r * 0.06
    for lx in (left + w * 0.11, right - w * 0.11):
        car.ellipse([lx - light_r, body_top + head_r * 0.10, lx + light_r, body_top + head_r * 0.10 + light_r * 2], fill=pin_color)

    return img.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    light = draw_icon(lambda s: gradient(s, NAVY, TEAL), (255, 255, 255, 110), (255, 255, 255, 255), NAVY + (255,))
    dark = draw_icon(lambda s: gradient(s, (8, 12, 24), (10, 40, 44)), (40, 210, 190, 120), (40, 210, 190, 255), (8, 14, 26, 255))
    tinted = draw_icon(lambda s: Image.new("RGB", (s, s), (0, 0, 0)), (255, 255, 255, 90), (255, 255, 255, 255), (0, 0, 0, 255),
                       shadow=False).convert("L")

    light.convert("RGB").save(OUT / "AppIcon.png")
    dark.convert("RGB").save(OUT / "AppIcon-Dark.png")
    tinted.save(OUT / "AppIcon-Tinted.png")

    contents = {
        "images": [
            {"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"},
            {"appearances": [{"appearance": "luminosity", "value": "dark"}], "filename": "AppIcon-Dark.png",
             "idiom": "universal", "platform": "ios", "size": "1024x1024"},
            {"appearances": [{"appearance": "luminosity", "value": "tinted"}], "filename": "AppIcon-Tinted.png",
             "idiom": "universal", "platform": "ios", "size": "1024x1024"},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (OUT / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
    print(f"Icons written to {OUT}")


if __name__ == "__main__":
    main()
