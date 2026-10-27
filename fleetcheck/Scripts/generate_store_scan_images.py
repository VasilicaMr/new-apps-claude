#!/usr/bin/env python3
"""
Draws the earnings screens DriveCap reads in the App Store screenshots, one per language and currency.
They have a generic "Earnings" title (no ride-hailing brand) so they're safe for store artwork.

    python3 Scripts/generate_store_scan_images.py   → AppStoreAssets/Source/scan_<lang>.png
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent.parent / "AppStoreAssets" / "Source"
W, H = 1170, 2532
FONT = "/System/Library/Fonts/Helvetica.ttc"


def font(size, bold=False):
    return ImageFont.truetype(FONT, size, index=1 if bold else 0)


def screen(path, title, subtitle, headline, rows):
    bg, fg, muted = (0, 0, 0), (255, 255, 255), (170, 170, 170)
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
        d.line((60, y + 90, W - 60, y + 90), fill=(60, 60, 60), width=2)
        y += 140
    img.save(OUT / path)


OUT.mkdir(parents=True, exist_ok=True)
screen("scan_en.png", "Earnings", "Today", "$238.40", [
    ("Trip earnings", "$204.90"),
    ("Tips", "$15.50"),
    ("Promotions", "$18.00"),
    ("Trips", "17"),
    ("Online", "8 h 12 min"),
])
screen("scan_ro.png", "Câștiguri", "Azi", "512,40 lei", [
    ("Câștiguri din curse", "431,90 lei"),
    ("Bacșișuri", "25,50 lei"),
    ("Promoții", "55,00 lei"),
    ("Curse", "18"),
    ("Timp online", "8 h 42 min"),
])
screen("scan_fr.png", "Gains", "Aujourd’hui", "186,30 €", [
    ("Gains des courses", "158,80 €"),
    ("Pourboires", "12,50 €"),
    ("Promotions", "15,00 €"),
    ("Courses", "15"),
    ("En ligne", "7 h 50 min"),
])
