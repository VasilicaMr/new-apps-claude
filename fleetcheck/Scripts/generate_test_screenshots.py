#!/usr/bin/env python3
"""
Draws fake earnings screenshots (Uber-style in English, Bolt-style in Romanian) used by
FleetCheckTests to check that Vision OCR + EarningsTextParser read real-looking screens.

    python3 Scripts/generate_test_screenshots.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent.parent / "FleetCheckTests" / "Fixtures"
W, H = 1170, 2532
FONT = "/System/Library/Fonts/Helvetica.ttc"


def font(size, bold=False):
    return ImageFont.truetype(FONT, size, index=1 if bold else 0)


def screen(path, title, subtitle, headline, rows, dark=False):
    bg, fg, muted = ((0, 0, 0), (255, 255, 255), (170, 170, 170)) if dark else ((255, 255, 255), (0, 0, 0), (110, 110, 110))
    img = Image.new("RGB", (W, H), bg)
    d = ImageDraw.Draw(img)
    d.text((60, 160), title, font=font(64, True), fill=fg)
    d.text((60, 260), subtitle, font=font(44), fill=muted)
    d.text((60, 360), headline, font=font(120, True), fill=fg)
    y = 600
    for label, value in rows:
        d.text((60, y), label, font=font(48), fill=fg)
        width = d.textlength(value, font=font(48))
        d.text((W - 60 - width, y), value, font=font(48), fill=fg)
        d.line((60, y + 90, W - 60, y + 90), fill=(60, 60, 60) if dark else (225, 225, 225), width=2)
        y += 140
    img.save(OUT / path)


OUT.mkdir(parents=True, exist_ok=True)
screen("uber_day_en.png", "Uber", "Mon, Oct 12", "RON 512.40", [
    ("Trip earnings", "RON 431.90"),
    ("Tips", "RON 25.50"),
    ("Promotions", "RON 55.00"),
    ("Trips", "18"),
    ("Online", "8 h 42 min"),
], dark=True)
screen("bolt_week_ro.png", "Bolt", "Săptămâna 5 - 11 oct.", "1.874,30 lei", [
    ("Câștiguri din curse", "1.702,80 lei"),
    ("Bacșișuri", "41,50 lei"),
    ("Promoții", "130,00 lei"),
    ("Curse", "64"),
    ("Numerar încasat", "312,00 lei"),
])
print(f"Wrote fixtures to {OUT}")
