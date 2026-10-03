#!/usr/bin/env python3
"""App icon: Foxy sliding onto its own shadow — the game in one picture.
Renders light, dark and tinted 1024px variants into AppIcon.appiconset.

Usage: python3 make_app_icon.py <Assets.xcassets>
"""
import json, os, re, sys
import cairosvg
from make_shadow_animals import animals

S = 1024
FOX_SCALE = 1.3
# Fox art spans roughly x 102–480, y 70–470 in its 512 viewBox.
FOX_BOX = (102, 70, 480, 470)
SHADOW_OFFSET = (200, 168)


def fox_body():
    """The fox SVG's inner markup (without the <svg> wrapper)."""
    s = animals["fox"]
    return s[s.index(">") + 1 : s.rindex("</svg>")]


def silhouette(body, color):
    """Same shapes, every fill and stroke in one color, with its own clip id."""
    body = re.sub(r'fill="[^"]+"', f'fill="{color}"', body)
    body = re.sub(r'stroke="[^"]+"', f'stroke="{color}"', body)
    return body.replace("foxtail", "foxtailShadow")


def placement():
    """Translate so fox + shadow together sit centered (slightly low, leaving room for sparkles)."""
    x0, y0, x1, y1 = FOX_BOX
    w = (x1 - x0) * FOX_SCALE + SHADOW_OFFSET[0]
    h = (y1 - y0) * FOX_SCALE + SHADOW_OFFSET[1]
    tx = (S - w) / 2 - x0 * FOX_SCALE + 34
    ty = (S - h) / 2 - y0 * FOX_SCALE + 44
    return tx, ty


def sparkle(cx, cy, r, color):
    """Four-point star."""
    k = r * 0.28
    d = (f"M {cx} {cy - r} Q {cx + k} {cy - k} {cx + r} {cy} Q {cx + k} {cy + k} {cx} {cy + r} "
         f"Q {cx - k} {cy + k} {cx - r} {cy} Q {cx - k} {cy - k} {cx} {cy - r} Z")
    return f'<path d="{d}" fill="{color}"/>'


def icon(variant):
    tx, ty = placement()
    sx, sy = tx + SHADOW_OFFSET[0], ty + SHADOW_OFFSET[1]
    body = fox_body()

    if variant == "light":
        background = (
            '<defs>'
            '<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">'
            '<stop offset="0" stop-color="#7FD3FF"/><stop offset="1" stop-color="#6A5CFF"/>'
            '</linearGradient>'
            '<radialGradient id="glow" cx="0.5" cy="0.42" r="0.55">'
            '<stop offset="0" stop-color="#FFFFFF" stop-opacity="0.55"/>'
            '<stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>'
            '</radialGradient>'
            '</defs>'
            f'<rect width="{S}" height="{S}" fill="url(#bg)"/>'
            f'<rect width="{S}" height="{S}" fill="url(#glow)"/>'
        )
        shadow_color, shadow_opacity = "#2B1B5C", 0.88
        star_a, star_b = "#FFE066", "#FFFFFF"
    elif variant == "dark":
        # Dark appearance: transparent background, the system supplies the dark backdrop.
        background = ""
        shadow_color, shadow_opacity = "#8E86C9", 0.55
        star_a, star_b = "#FFE066", "#FFF4C2"
    else:  # tinted: grayscale on transparent; the system applies the user's tint.
        background = ""
        shadow_color, shadow_opacity = "#7A7A7A", 0.75
        star_a, star_b = "#FFFFFF", "#DADADA"

    shadow = (f'<g transform="translate({sx} {sy}) scale({FOX_SCALE})" opacity="{shadow_opacity}">'
              f'{silhouette(body, shadow_color)}</g>')
    # Fox tilted as if being dragged onto its shadow.
    cx, cy = 291, 270  # fox art center in its own coordinates
    fox = (f'<g transform="translate({tx} {ty}) scale({FOX_SCALE}) rotate(-10 {cx} {cy})">{body}</g>')
    stars = sparkle(842, 190, 64, star_a) + sparkle(930, 312, 30, star_b) + sparkle(128, 870, 36, star_b)

    svg = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {S} {S}" width="{S}" height="{S}">{background}{shadow}{fox}{stars}</svg>'

    if variant == "tinted":
        # Tinted icons must be grayscale: desaturate the fox's colors.
        def gray(m):
            h = m.group(1)
            if len(h) == 3:
                h = "".join(c * 2 for c in h)
            r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
            v = round(0.3 * r + 0.59 * g + 0.11 * b)
            return f'#{v:02X}{v:02X}{v:02X}'
        svg = re.sub(r"#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{3})\b", gray, svg)
    return svg


if __name__ == "__main__":
    out = os.path.join(sys.argv[1], "AppIcon.appiconset")
    os.makedirs(out, exist_ok=True)
    files = {"light": "AppIcon.png", "dark": "AppIcon-Dark.png", "tinted": "AppIcon-Tinted.png"}
    for variant, name in files.items():
        cairosvg.svg2png(bytestring=icon(variant).encode(), write_to=os.path.join(out, name),
                         output_width=S, output_height=S)
        print("rendered", name)

    universal = {"idiom": "universal", "platform": "ios", "size": "1024x1024"}
    contents = {
        "images": [
            {**universal, "filename": files["light"]},
            {**universal, "filename": files["dark"],
             "appearances": [{"appearance": "luminosity", "value": "dark"}]},
            {**universal, "filename": files["tinted"],
             "appearances": [{"appearance": "luminosity", "value": "tinted"}]},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    with open(os.path.join(out, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
