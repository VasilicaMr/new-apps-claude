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
# One trip: the passenger paid more than the driver got. Must read "Your earnings", not the customer price.
screen("uber_trip_en.png", "Trip details", "UberX · Oct 12 · Your earnings", "RON 34.20", [
    ("Customer price", "RON 45.00"),
    ("Uber service fee", "-RON 10.80"),
    ("Fare", "RON 30.70"),
    ("Tip", "RON 3.50"),
    ("Distance", "9.4 km"),
    ("Duration", "23 min"),
])
# Uber in Romanian, weekly, with points and online time that must be ignored.
screen("uber_week_ro.png", "Câștiguri", "6 oct. - 12 oct.", "2.146,75 RON", [
    ("Tarif", "1.948,25 RON"),
    ("Promoții", "120,00 RON"),
    ("Bacșișuri", "78,50 RON"),
    ("Curse", "71"),
    ("Timp online", "41 h 20 min"),
    ("Puncte", "512"),
], dark=True)
# Bolt shows gross and commission: the driver's money is the NET line.
screen("bolt_day_gross_net.png", "Bolt", "Today", "Net earnings 318,40 lei", [
    ("Gross earnings", "398,00 lei"),
    ("Bolt commission", "-79,60 lei"),
    ("Tips", "12,00 lei"),
    ("Cash collected", "145,00 lei"),
    ("Rides", "14"),
])



def receipt(path, lines):
    """A narrow thermal-printer style fuel receipt."""
    img = Image.new("RGB", (900, 120 + 70 * len(lines)), (250, 250, 247))
    d = ImageDraw.Draw(img)
    y = 60
    for left, right in lines:
        d.text((50, y), left, font=font(40), fill=(20, 20, 20))
        if right:
            width = d.textlength(right, font=font(40))
            d.text((850 - width, y), right, font=font(40), fill=(20, 20, 20))
        y += 70
    img.save(OUT / path)


receipt("receipt_fuel_ro.png", [
    ("OMV PETROM MARKETING SRL", ""),
    ("Statia Bucuresti Unirii", ""),
    ("Data: 11.10.2026  Ora 18:42", ""),
    ("MOTORINA MAXXMOTION", ""),
    ("34,12 L x 7,33", "250,10"),
    ("SUBTOTAL", "250,10"),
    ("TVA 21%", "43,41"),
    ("TOTAL LEI", "250,10"),
    ("CARD", "250,10"),
])

print(f"Wrote fixtures to {OUT}")
