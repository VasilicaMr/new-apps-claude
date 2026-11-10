#!/usr/bin/env python3
"""App icon: a ball rolling down a ramp under a bright orbit — "physics you can play with".
Renders one 1024px universal icon into AppIcon.appiconset.

Usage: python3 tools/make_app_icon.py LittlePhysicsTrail/Resources/Assets.xcassets
"""
import json, os, sys
import cairosvg

S = 1024

SVG = f"""<svg xmlns="http://www.w3.org/2000/svg" width="{S}" height="{S}" viewBox="0 0 {S} {S}">
  <defs>
    <linearGradient id="sky" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#7A5CF5"/>
      <stop offset="1" stop-color="#4D9EFF"/>
    </linearGradient>
    <radialGradient id="ball" cx="0.35" cy="0.3" r="0.75">
      <stop offset="0" stop-color="#FFE38A"/>
      <stop offset="1" stop-color="#FF8A2B"/>
    </radialGradient>
  </defs>
  <rect width="{S}" height="{S}" fill="url(#sky)"/>
  <circle cx="190" cy="180" r="10" fill="#fff" opacity="0.8"/>
  <circle cx="860" cy="150" r="14" fill="#fff" opacity="0.7"/>
  <circle cx="900" cy="420" r="8" fill="#fff" opacity="0.6"/>
  <g transform="translate(512 360)" fill="none" stroke="#fff" stroke-width="22" opacity="0.9">
    <ellipse rx="300" ry="104"/>
    <ellipse rx="300" ry="104" transform="rotate(60)"/>
    <ellipse rx="300" ry="104" transform="rotate(-60)"/>
  </g>
  <circle cx="512" cy="360" r="62" fill="#FFD23A"/>
  <path d="M90 930 L934 930 L934 640 Z" fill="#35CC8F"/>
  <path d="M90 930 L934 640" stroke="#fff" stroke-width="18" stroke-linecap="round" opacity="0.6"/>
  <circle cx="420" cy="738" r="110" fill="url(#ball)"/>
  <path d="M250 640 q-60 10 -110 40 M270 700 q-70 10 -140 50" stroke="#fff" stroke-width="16"
        stroke-linecap="round" fill="none" opacity="0.75"/>
</svg>"""


def main():
    catalog = sys.argv[1]
    out = os.path.join(catalog, "AppIcon.appiconset")
    os.makedirs(out, exist_ok=True)
    cairosvg.svg2png(bytestring=SVG.encode(), write_to=os.path.join(out, "icon.png"), output_width=S, output_height=S)
    contents = {
        "images": [{"filename": "icon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
        "info": {"author": "xcode", "version": 1},
    }
    with open(os.path.join(out, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)


if __name__ == "__main__":
    main()
