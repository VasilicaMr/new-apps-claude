#!/usr/bin/env python3
"""Paid picture packs for Peekaboo Shapes (same kawaii style as make_shadow_animals.py).

Usage:  python3 make_shadow_packs.py <Assets.xcassets dir>
Writes one folder per pack (ShadowVehicles, ShadowFood, ShadowOcean) of 1024px transparent
PNG imagesets named <prefix>_<item>, e.g. vehicles_car.
"""
import json, math, os, sys
import cairosvg
from make_shadow_animals import OUT, PINK, SW, blob, C, E, P, R, shape, eye, cheeks, smile, open_smile, svg


def line(d, color, w):
    """Thick outlined stroke (tails, stems, frames)."""
    return (f'<path d="{d}" fill="none" stroke="{OUT}" stroke-width="{w + SW * 2}" stroke-linecap="round" stroke-linejoin="round"/>'
            f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"/>')


def face(x1, x2, y, r=20, cheek_dy=40, smile_dy=40, sw=8):
    cx = (x1 + x2) / 2
    return (eye(x1, y, r) + eye(x2, y, r) +
            cheeks(x1 - r * 1.2, x2 + r * 1.2, y + cheek_dy, rx=r * 1.1, ry=r * 0.7) +
            smile(cx, y + smile_dy, w=r * 1.1, h=r * 0.6, sw=sw))


def wheel(cx, cy, r):
    return shape(C(cx, cy, r), "#3B3B4F") + shape(C(cx, cy, r * 0.45), "#D9DDE8", sw=8)


# ======================================================
# Things That Go
# ======================================================
vehicles = {}

vehicles["car"] = svg(
    shape(P("M 52 340 L 52 280 Q 52 244 92 238 L 160 230 L 206 164 Q 216 150 236 150 L 330 150 "
            "Q 350 150 362 166 L 410 230 L 440 236 Q 468 242 468 282 L 468 340 Q 468 360 448 360 L 72 360 Q 52 360 52 340 Z"), "#FF6B6B") +
    shape(P("M 214 228 L 246 176 L 288 176 L 288 228 Z"), "#BDE7FF", sw=9) +
    shape(P("M 308 228 L 308 176 L 334 176 Q 344 176 350 184 L 384 228 Z"), "#BDE7FF", sw=9) +
    shape(E(456, 270, 12, 18), "#FFE066", sw=7) +
    wheel(150, 360, 54) + wheel(380, 360, 54) +
    face(232, 312, 284, r=18, cheek_dy=30, smile_dy=34)
)

vehicles["bus"] = svg(
    shape(R(36, 118, 440, 262, 40), "#FFC93C") +
    "".join(shape(R(x, 152, 72, 76, 14), "#BDE7FF", sw=9) for x in (70, 162, 254)) +
    shape(R(352, 152, 94, 76, 14), "#BDE7FF", sw=9) +
    shape(R(36, 262, 440, 22, 0), "#3B3B4F", sw=0) +
    shape(E(462, 320, 12, 18), "#FFF4B0", sw=7) +
    wheel(130, 380, 52) + wheel(380, 380, 52) +
    face(220, 300, 320, r=17, cheek_dy=26, smile_dy=30)
)

vehicles["airplane"] = svg(
    shape(P("M 230 230 L 300 230 L 250 120 L 210 120 Z"), "#5B8DEF") +           # far wing
    blob([E(256, 270, 214, 64), P("M 76 262 L 42 120 L 104 120 L 168 240 Z")], "#EAF2FF") +
    shape(P("M 52 140 L 98 140 L 136 220 L 80 220 Z"), "#FF6B6B", stroke=False) +  # tail stripe
    shape(P("M 214 286 L 304 286 L 236 420 L 176 420 Z"), "#5B8DEF") +            # near wing
    "".join(f'<circle cx="{x}" cy="252" r="13" fill="#7FC4FF" stroke="{OUT}" stroke-width="6"/>' for x in (124, 168)) +
    shape(P("M 446 246 Q 430 222 400 222 L 400 262 L 462 262 Q 460 254 446 246 Z"), "#7FC4FF", sw=8) +
    face(330, 378, 272, r=14, cheek_dy=22, smile_dy=22, sw=6)
)

vehicles["train"] = svg(
    "".join(shape(C(x, y, r), "#E6E9F2", sw=8) for x, y, r in [(352, 92, 30), (394, 62, 38), (444, 36, 30)]) +
    shape(R(302, 104, 56, 90, 10), "#3B3B4F") + shape(R(288, 92, 84, 26, 10), "#3B3B4F") +   # chimney
    shape(R(40, 108, 150, 270, 18), "#E63946") + shape(R(28, 92, 174, 34, 14), "#3B3B4F") +   # cab + roof
    shape(R(72, 146, 86, 76, 14), "#BDE7FF", sw=9) +
    shape(R(176, 184, 250, 160, 30), "#2A9D8F") +                                                # boiler
    shape(P("M 410 340 L 486 400 L 410 400 Z"), "#FFC93C", sw=10) +                             # cow-catcher
    shape(R(40, 330, 400, 40, 12), "#3B3B4F") +
    wheel(110, 392, 46) + wheel(236, 392, 46) + wheel(352, 392, 46) +
    shape(C(426, 262, 74), "#D9DDE8") +
    face(400, 452, 252, r=16, cheek_dy=28, smile_dy=30, sw=7)
)

vehicles["sailboat"] = svg(
    line("M 256 60 L 256 340", "#8A5A3B", 14) +
    shape(P("M 274 70 L 274 316 L 446 316 Z"), "#FFFFFF") +
    shape(P("M 238 100 L 238 316 L 88 316 Z"), "#FFB4A2") +
    shape(P("M 256 52 L 320 70 L 256 88 Z"), "#E63946", sw=8) +
    shape(P("M 40 334 L 472 334 Q 452 444 382 444 L 130 444 Q 60 444 40 334 Z"), "#2A9D8F") +
    face(214, 298, 380, r=17, cheek_dy=26, smile_dy=30)
)

vehicles["rocket"] = svg(
    shape(P("M 214 400 Q 256 520 298 400 Z"), "#FF9F1C", sw=10) +
    f'<path d="M 232 404 Q 256 470 280 404 Z" fill="#FFE066"/>' +
    shape(P("M 176 300 L 112 400 L 196 380 Z"), "#E63946") + shape(P("M 336 300 L 400 400 L 316 380 Z"), "#E63946") +
    shape(P("M 256 30 Q 360 120 340 330 L 330 400 L 182 400 L 172 330 Q 152 120 256 30 Z"), "#EAF2FF") +
    shape(P("M 256 30 Q 316 80 330 130 L 182 130 Q 196 80 256 30 Z"), "#E63946") +
    shape(C(256, 200, 44), "#7FC4FF", sw=10) +
    f'<circle cx="240" cy="186" r="12" fill="white" opacity="0.8"/>' +
    face(222, 290, 290, r=15, cheek_dy=24, smile_dy=28, sw=7)
)

vehicles["bicycle"] = svg(
    "".join(f'<circle cx="{x}" cy="340" r="88" fill="none" stroke="{OUT}" stroke-width="34"/>'
            f'<circle cx="{x}" cy="340" r="88" fill="none" stroke="#3B3B4F" stroke-width="12"/>'
            f'<circle cx="{x}" cy="340" r="62" fill="none" stroke="#B8C0D0" stroke-width="5"/>'
            + "".join(f'<line x1="{x}" y1="340" x2="{x + 62 * math.cos(a * math.pi / 4):.1f}" y2="{340 + 62 * math.sin(a * math.pi / 4):.1f}" stroke="#B8C0D0" stroke-width="4"/>' for a in range(8))
            for x in (126, 386)) +
    line("M 126 340 L 216 340 L 330 210 L 196 210 L 126 340 M 196 210 L 216 340 M 330 210 L 386 340", "#2A9D8F", 18) +
    line("M 186 180 L 196 210", "#2A9D8F", 18) + line("M 330 210 L 316 150 L 356 140", "#3B3B4F", 14) +
    shape(P("M 150 170 Q 186 156 226 170 Q 226 186 186 186 Q 150 186 150 170 Z"), "#E63946", sw=8) +
    shape(C(216, 340, 22), "#FFC93C", sw=8) +
    shape(R(346, 176, 104, 72, 16), "#FFC93C", sw=9) +
    "".join(shape(C(x, 168, 18), c, sw=6) for x, c in [(372, "#FF8FA3"), (404, "#FFE066"), (432, "#FF8FA3")]) +
    face(380, 418, 206, r=11, cheek_dy=16, smile_dy=20, sw=5)
)

vehicles["helicopter"] = svg(
    line("M 236 300 L 50 250", "#FFC93C", 26) +
    shape(C(54, 246, 40), "#D9DDE8", sw=8) + line("M 54 206 L 54 286", "#3B3B4F", 8) +
    line("M 196 430 L 400 430 M 236 430 L 250 384 M 360 430 L 346 384", "#3B3B4F", 12) +
    shape(E(296, 290, 140, 104), "#FFC93C") +
    shape(P("M 300 206 Q 410 210 420 290 L 300 290 Z"), "#BDE7FF", sw=9) +
    line("M 296 186 L 296 136", "#3B3B4F", 14) +
    line("M 96 132 L 496 132", "#3B3B4F", 16) +
    shape(R(266, 120, 60, 24, 10), "#3B3B4F", sw=6) +
    face(236, 298, 300, r=18, cheek_dy=28, smile_dy=36)
)

vehicles["balloon"] = svg(
    line("M 186 300 L 214 400 M 326 300 L 298 400", "#8A5A3B", 6) +
    shape(R(196, 392, 120, 84, 16), "#C98B4E") +
    "".join(f'<line x1="196" y1="{y}" x2="316" y2="{y}" stroke="#9C6B3A" stroke-width="5"/>' for y in (420, 448)) +
    shape(P("M 256 30 C 400 30 440 170 380 250 C 350 290 320 310 300 340 L 212 340 C 192 310 162 290 132 250 C 72 170 112 30 256 30 Z"), "#FF6B6B") +
    '<clipPath id="balloonclip"><path d="M 256 30 C 400 30 440 170 380 250 C 350 290 320 310 300 340 L 212 340 C 192 310 162 290 132 250 C 72 170 112 30 256 30 Z"/></clipPath>'
    '<g clip-path="url(#balloonclip)">'
    '<path d="M 256 20 C 180 60 170 260 220 350 L 292 350 C 342 260 332 60 256 20 Z" fill="#FFE066"/>'
    '<path d="M 70 150 L 450 150 L 450 176 L 70 176 Z" fill="#5B8DEF"/></g>' +
    f'<path d="M 256 30 C 400 30 440 170 380 250 C 350 290 320 310 300 340 L 212 340 C 192 310 162 290 132 250 C 72 170 112 30 256 30 Z" fill="none" stroke="{OUT}" stroke-width="{SW}"/>' +
    shape(R(204, 330, 104, 20, 8), "#C98B4E", sw=8) +
    face(220, 292, 220, r=18, cheek_dy=30, smile_dy=36)
)

vehicles["tractor"] = svg(
    shape(R(320, 118, 22, 110, 8), "#3B3B4F", sw=8) +
    shape(P("M 70 150 L 230 150 L 250 290 L 70 290 Z"), "#6CC24A") +
    shape(R(56, 132, 194, 30, 12), "#E63946", sw=10) +
    shape(R(98, 178, 116, 86, 12), "#BDE7FF", sw=9) +
    shape(R(220, 220, 240, 110, 22), "#6CC24A") +
    shape(R(440, 236, 28, 50, 10), "#FFE066", sw=8) +
    wheel(146, 352, 104) + wheel(392, 386, 64) +
    face(300, 372, 266, r=16, cheek_dy=26, smile_dy=30, sw=7)
)

# ======================================================
# Yummy Food
# ======================================================
food = {}

food["apple"] = svg(
    line("M 256 130 Q 252 80 274 50", "#7A4A2E", 14) +
    shape(P("M 278 92 Q 340 40 390 70 Q 340 120 278 92 Z"), "#6CC24A") +
    shape(P("M 256 130 C 200 90 80 110 84 250 C 88 380 180 470 256 440 C 332 470 424 380 428 250 C 432 110 312 90 256 130 Z"), "#FF4D5E") +
    f'<ellipse cx="160" cy="210" rx="26" ry="44" fill="white" opacity="0.35" transform="rotate(20 160 210)"/>' +
    face(208, 304, 280)
)

food["banana"] = svg(
    shape(P("M 70 150 C 60 340 220 450 420 380 C 460 366 470 340 450 330 C 300 380 160 300 128 140 C 124 120 76 120 70 150 Z"), "#FFE066") +
    f'<path d="M 120 180 C 150 300 260 370 400 360" fill="none" stroke="#E8C547" stroke-width="10" stroke-linecap="round"/>' +
    shape(R(78, 92, 40, 54, 10), "#8A6A3B", sw=9) +
    shape(C(458, 344, 14), "#5C4026", sw=6) +
    face(236, 292, 344, r=14, cheek_dy=22, smile_dy=24, sw=6)
)

food["strawberry"] = svg(
    shape(P("M 256 460 C 120 400 70 260 100 190 C 130 130 200 140 256 150 C 312 140 382 130 412 190 C 442 260 392 400 256 460 Z"), "#FF4D5E") +
    "".join(f'<ellipse cx="{x}" cy="{y}" rx="6" ry="9" fill="#FFE066"/>' for x, y in
            [(150, 230), (362, 230), (140, 300), (372, 300), (190, 380), (322, 380), (256, 410), (224, 340), (290, 340)]) +
    shape(P("M 256 160 L 196 110 L 236 132 L 226 80 L 256 120 L 286 80 L 276 132 L 316 110 Z"
            "M 256 160 L 150 160 L 210 140 Z M 256 160 L 362 160 L 302 140 Z"), "#4CAF50", sw=9) +
    line("M 256 110 L 256 60", "#4CAF50", 12) +
    face(212, 300, 240, r=18, cheek_dy=30, smile_dy=34)
)

food["pear"] = svg(
    line("M 256 110 Q 258 70 236 40", "#7A4A2E", 14) +
    shape(P("M 262 74 Q 320 30 372 54 Q 324 104 262 74 Z"), "#6CC24A") +
    shape(P("M 256 100 C 206 100 196 160 186 220 C 176 270 96 300 100 380 C 104 460 200 476 256 470 "
            "C 312 476 408 460 412 380 C 416 300 336 270 326 220 C 316 160 306 100 256 100 Z"), "#C5E063") +
    f'<ellipse cx="170" cy="370" rx="22" ry="40" fill="white" opacity="0.35" transform="rotate(20 170 370)"/>' +
    face(212, 300, 340)
)

food["carrot"] = svg(
    shape(P("M 300 140 Q 270 60 300 30 Q 330 80 320 140 Z"), "#4CAF50", sw=9) +
    shape(P("M 300 140 Q 360 50 420 60 Q 380 120 320 150 Z"), "#4CAF50", sw=9) +
    shape(P("M 300 140 Q 220 80 180 100 Q 230 150 290 160 Z"), "#4CAF50", sw=9) +
    shape(P("M 230 150 C 280 120 360 140 362 200 C 364 260 200 400 110 470 C 90 486 70 470 80 446 C 140 360 170 190 230 150 Z"), "#FF8C2E") +
    "".join(f'<path d="M {x} {y} l 26 6" stroke="#D9661A" stroke-width="8" stroke-linecap="round"/>' for x, y in [(250, 280), (200, 340), (154, 404)]) +
    face(250, 316, 210, r=16, cheek_dy=26, smile_dy=30, sw=7)
)

food["watermelon"] = svg(
    shape(P("M 36 200 L 476 200 A 220 220 0 0 1 36 200 Z"), "#4CAF50") +
    f'<path d="M 66 210 L 446 210 A 190 190 0 0 1 66 210 Z" fill="#E8F5C8"/>' +
    f'<path d="M 86 214 L 426 214 A 170 170 0 0 1 86 214 Z" fill="#FF5C6E"/>' +
    f'<line x1="36" y1="200" x2="476" y2="200" stroke="{OUT}" stroke-width="{SW}" stroke-linecap="round"/>' +
    "".join(f'<ellipse cx="{x}" cy="{y}" rx="7" ry="11" fill="{OUT}" transform="rotate({r} {x} {y})"/>' for x, y, r in
            [(150, 300, -30), (362, 300, 30), (200, 340, -15), (312, 340, 15), (256, 352, 0), (130, 250, -40), (382, 250, 40)]) +
    face(216, 296, 256, r=17, cheek_dy=24, smile_dy=28, sw=7)
)

grapes = [(256, 410), (206, 340), (306, 340), (156, 270), (256, 270), (356, 270), (206, 200), (306, 200), (256, 140)]
food["grapes"] = svg(
    line("M 256 110 Q 250 60 280 40", "#7A4A2E", 14) +
    shape(P("M 270 80 Q 360 20 420 70 Q 350 130 270 80 Z"), "#6CC24A") +
    blob([C(x, y, 56) for x, y in grapes], "#9B5DE5") +
    "".join(f'<circle cx="{x}" cy="{y}" r="56" fill="#9B5DE5" stroke="#7B3FC4" stroke-width="5"/>'
            f'<circle cx="{x - 20}" cy="{y - 22}" r="12" fill="white" opacity="0.4"/>' for x, y in grapes) +
    face(222, 290, 262, r=17, cheek_dy=28, smile_dy=32, sw=7)
)

food["pineapple"] = svg(
    shape(P("M 256 170 L 196 50 L 240 110 L 256 20 L 272 110 L 316 50 L 256 170 Z"), "#4CAF50", sw=10) +
    shape(P("M 256 170 L 150 90 L 230 140 Z M 256 170 L 362 90 L 282 140 Z"), "#4CAF50", sw=10) +
    shape(E(256, 320, 130, 160), "#FFC93C") +
    '<clipPath id="pineclip"><ellipse cx="256" cy="320" rx="124" ry="154"/></clipPath>'
    '<g clip-path="url(#pineclip)" stroke="#D99A1E" stroke-width="7">' +
    "".join(f'<line x1="{x}" y1="140" x2="{x + 340}" y2="480"/><line x1="{x + 340}" y1="140" x2="{x}" y2="480"/>' for x in range(-80, 400, 60)) +
    '</g>' +
    face(214, 298, 300, r=19, cheek_dy=32, smile_dy=36)
)

food["cherries"] = svg(
    line("M 160 330 Q 200 160 290 70 M 352 340 Q 330 180 290 70", "#4CAF50", 12) +
    shape(P("M 290 70 Q 360 20 430 60 Q 360 110 290 70 Z"), "#6CC24A") +
    shape(C(150, 370, 92), "#E63946") + shape(C(360, 380, 92), "#E63946") +
    f'<circle cx="116" cy="334" r="16" fill="white" opacity="0.4"/><circle cx="326" cy="344" r="16" fill="white" opacity="0.4"/>' +
    face(124, 176, 372, r=13, cheek_dy=20, smile_dy=24, sw=6) +
    face(334, 386, 382, r=13, cheek_dy=20, smile_dy=24, sw=6)
)

food["broccoli"] = svg(
    shape(P("M 196 280 L 316 280 L 300 470 Q 256 486 212 470 Z"), "#B5E48C") +
    blob([C(150, 220, 86), C(256, 150, 100), C(362, 220, 86), C(256, 250, 110), C(190, 120, 64), C(322, 120, 64)], "#4CAF50") +
    "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#3E8E41"/>' for x, y, r in
            [(140, 180, 18), (360, 180, 18), (200, 96, 14), (320, 96, 14), (256, 100, 16), (110, 250, 12), (400, 250, 12)]) +
    face(212, 300, 240, r=19, cheek_dy=32, smile_dy=36) +
    f'<path d="M 230 330 L 240 440 M 282 330 L 272 440" stroke="#8CC86A" stroke-width="8" stroke-linecap="round"/>'
)

# ======================================================
# Under the Sea
# ======================================================
ocean = {}

ocean["fish"] = svg(
    shape(P("M 140 256 L 40 160 Q 70 256 40 352 Z"), "#FF8C2E") +
    shape(P("M 230 160 Q 270 70 340 120 L 320 170 Z"), "#FF8C2E") +
    shape(E(270, 260, 200, 130), "#FF8C2E") +
    '<clipPath id="fishclip"><ellipse cx="270" cy="260" rx="194" ry="124"/></clipPath>'
    '<g clip-path="url(#fishclip)">'
    f'<path d="M 190 120 Q 230 260 190 400 L 250 400 Q 290 260 250 120 Z" fill="white" stroke="{OUT}" stroke-width="8"/>'
    f'<path d="M 330 120 Q 300 260 330 400 L 370 400 Q 340 260 370 120 Z" fill="white" stroke="{OUT}" stroke-width="8"/></g>' +
    shape(P("M 240 330 Q 270 400 320 350 Z"), "#FF8C2E", sw=9) +
    eye(402, 230, 24) + cheeks(366, 440, 286, rx=20, ry=12) +
    smile(430, 300, w=18, h=10, sw=7)
)

ocean["octopus"] = svg(
    "".join(line(d, "#C77DFF", 40) for d in [
        "M 170 300 Q 90 360 130 440 Q 150 470 110 480",
        "M 220 320 Q 190 410 220 470",
        "M 292 320 Q 322 410 292 470",
        "M 342 300 Q 422 360 382 440 Q 362 470 402 480",
    ]) +
    shape(P("M 256 50 C 400 50 420 200 400 270 C 380 340 132 340 112 270 C 92 200 112 50 256 50 Z"), "#C77DFF") +
    "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#A55EEA"/>' for x, y, r in [(200, 110, 18), (320, 100, 14), (350, 160, 10)]) +
    face(212, 300, 216, r=20, cheek_dy=34, smile_dy=40)
)

ocean["whale"] = svg(
    line("M 236 100 Q 236 60 210 40 M 256 100 Q 256 50 256 30 M 276 100 Q 276 60 302 40", "#7FC4FF", 12) +
    shape(P("M 80 290 Q 40 230 20 180 Q 60 190 90 230 Q 100 180 140 160 Q 140 230 130 300 Z"), "#4A7FD6") +
    shape(P("M 120 300 C 120 160 260 110 360 130 C 460 150 490 250 480 320 C 470 400 380 420 300 420 C 200 420 120 380 120 300 Z"), "#5B8DEF") +
    f'<path d="M 150 340 C 200 400 400 420 470 340 C 460 400 380 416 300 416 C 220 416 170 390 150 340 Z" fill="#C8DCFF"/>' +
    shape(P("M 300 360 Q 290 420 350 420 Q 330 390 330 360 Z"), "#4A7FD6", sw=9) +
    face(330, 410, 260, r=19, cheek_dy=32, smile_dy=40)
)

ocean["crab"] = svg(
    "".join(line(d, "#E63946", 18) for d in [
        "M 140 330 L 70 360 L 50 420", "M 150 370 L 90 420 L 80 470",
        "M 372 330 L 442 360 L 462 420", "M 362 370 L 422 420 L 432 470"]) +
    line("M 170 270 L 110 190", "#E63946", 22) + line("M 342 270 L 402 190", "#E63946", 22) +
    shape(P("M 110 190 C 40 170 40 80 100 60 L 112 120 L 150 80 C 180 130 160 190 110 190 Z"), "#E63946") +
    shape(P("M 402 190 C 472 170 472 80 412 60 L 400 120 L 362 80 C 332 130 352 190 402 190 Z"), "#E63946") +
    line("M 216 220 L 206 150 M 296 220 L 306 150", "#E63946", 12) +
    shape(E(256, 320, 150, 100), "#FF5C6E") +
    shape(C(206, 150, 28), "white", sw=9) + shape(C(306, 150, 28), "white", sw=9) +
    eye(206, 152, 16) + eye(306, 152, 16) +
    cheeks(170, 342, 320, rx=24, ry=14) + open_smile(256, 316, w=30, h=22)
)

star_pts = []
for i in range(10):
    a = -math.pi / 2 + i * math.pi / 5
    r = 230 if i % 2 == 0 else 104
    star_pts.append((256 + r * math.cos(a), 276 + r * math.sin(a)))
star_d = "M " + " L ".join(f"{x:.1f} {y:.1f}" for x, y in star_pts) + " Z"
ocean["starfish"] = svg(
    f'<path d="{star_d}" fill="#FF9F5A" stroke="{OUT}" stroke-width="{SW * 3}" stroke-linejoin="round"/>'
    f'<path d="{star_d}" fill="#FF9F5A" stroke="#FF9F5A" stroke-width="{SW}" stroke-linejoin="round"/>' +
    "".join(f'<circle cx="{256 + d * math.cos(-math.pi / 2 + i * 2 * math.pi / 5):.1f}" cy="{276 + d * math.sin(-math.pi / 2 + i * 2 * math.pi / 5):.1f}" r="9" fill="#FFD3B0"/>'
            for i in range(5) for d in (140, 180)) +
    face(220, 292, 264, r=18, cheek_dy=30, smile_dy=34)
)

ocean["seahorse"] = svg(
    shape(P("M 300 250 Q 380 250 384 320 Q 340 310 306 290 Z"), "#FFB84C", sw=9) +                # back fin
    line("M 300 400 C 320 460 270 490 240 470 C 220 456 232 430 256 440", "#FFC93C", 30) +        # curled tail
    shape(P("M 236 80 C 300 76 340 130 320 200 C 306 250 296 290 316 340 C 330 380 316 420 290 430 "
            "C 240 420 190 380 186 320 C 182 270 206 240 200 214 L 90 214 Q 66 200 90 180 L 186 164 "
            "C 180 116 200 82 236 80 Z"), "#FFC93C") +
    f'<path d="M 206 250 C 196 300 210 360 270 400 C 250 360 236 300 246 250 Z" fill="#FFE29A"/>' +
    "".join(f'<path d="M {x} {y} q 18 -8 30 2" fill="none" stroke="#E0A030" stroke-width="7" stroke-linecap="round"/>' for x, y in [(222, 290), (232, 330), (252, 368)]) +
    shape(P("M 228 84 L 240 40 L 256 72 L 276 38 L 286 92 Z"), "#FF9F1C", sw=8) +
    eye(246, 150, 20) + f'<ellipse cx="270" cy="196" rx="18" ry="11" fill="{PINK}" opacity="0.65"/>' +
    smile(150, 204, w=14, h=8, sw=6)
)

ocean["jellyfish"] = svg(
    "".join(line(d, "#FF9BD2", 16) for d in [
        "M 170 290 Q 140 350 170 400 Q 200 450 170 490",
        "M 222 300 Q 200 360 222 410 Q 244 450 222 480",
        "M 290 300 Q 312 360 290 410 Q 268 450 290 480",
        "M 342 290 Q 372 350 342 400 Q 312 450 342 490"]) +
    shape(P("M 90 300 C 80 120 180 50 256 50 C 332 50 432 120 422 300 "
            "Q 396 280 370 300 Q 340 280 310 300 Q 282 280 256 300 Q 228 280 200 300 Q 172 280 142 300 Q 116 280 90 300 Z"), "#FF9BD2") +
    f'<path d="M 140 160 Q 160 100 220 86" fill="none" stroke="white" stroke-width="14" stroke-linecap="round" opacity="0.5"/>' +
    face(212, 300, 196, r=20, cheek_dy=34, smile_dy=40)
)

ocean["dolphin"] = svg(
    shape(P("M 300 140 Q 300 70 250 50 Q 270 110 250 160 Z"), "#4FA3D9") +
    shape(P("M 130 400 Q 80 400 40 460 Q 100 450 120 430 Q 130 470 170 490 Q 160 440 170 410 Z"), "#4FA3D9") +
    shape(P("M 150 420 C 120 300 200 140 340 150 C 400 154 440 190 456 220 L 500 236 Q 504 252 488 256 "
            "L 450 262 C 430 290 380 300 330 290 C 260 280 210 340 190 430 Z"), "#5BB5EA") +
    f'<path d="M 190 420 C 210 330 260 280 330 290 C 380 300 430 290 450 262 C 420 310 340 320 300 320 C 240 330 200 380 190 420 Z" fill="#D6EEFF"/>' +
    shape(P("M 320 290 Q 330 350 280 360 Q 290 330 280 300 Z"), "#4FA3D9", sw=9) +
    eye(390, 214, 18) + f'<ellipse cx="420" cy="252" rx="16" ry="10" fill="{PINK}" opacity="0.65"/>' +
    smile(462, 254, w=16, h=8, sw=6)
)

spikes = []
for i in range(16):
    a = i * math.pi / 8
    bx, by = 256 + 150 * math.cos(a), 270 + 150 * math.sin(a)
    tx, ty = 256 + 200 * math.cos(a), 270 + 200 * math.sin(a)
    l1x, l1y = 256 + 150 * math.cos(a - 0.12), 270 + 150 * math.sin(a - 0.12)
    l2x, l2y = 256 + 150 * math.cos(a + 0.12), 270 + 150 * math.sin(a + 0.12)
    spikes.append(f"M {l1x:.1f} {l1y:.1f} L {tx:.1f} {ty:.1f} L {l2x:.1f} {l2y:.1f} Z")
ocean["pufferfish"] = svg(
    "".join(shape(P(d), "#FFE066", sw=8) for d in spikes) +
    shape(C(256, 270, 160), "#FFE066") +
    f'<ellipse cx="256" cy="340" rx="120" ry="70" fill="#FFF5C2"/>' +
    "".join(f'<circle cx="{x}" cy="{y}" r="10" fill="#E8B530"/>' for x, y in [(180, 170), (330, 160), (256, 140), (140, 240), (372, 240)]) +
    eye(206, 250, 24) + eye(306, 250, 24) + cheeks(162, 350, 306, rx=26, ry=16) +
    f'<ellipse cx="256" cy="322" rx="20" ry="16" fill="#E8546B" stroke="{OUT}" stroke-width="8"/>'
)

ocean["shell"] = svg(
    shape(P("M 256 450 L 50 220 C 80 80 200 40 256 40 C 312 40 432 80 462 220 Z"), "#FFB4A2") +
    "".join(f'<path d="M 256 440 L {256 + 210 * math.cos(math.pi + a * math.pi / 8):.1f} {230 + 190 * math.sin(math.pi + a * math.pi / 8):.1f}" stroke="#E8846E" stroke-width="8" stroke-linecap="round"/>'
            for a in range(1, 8)) +
    shape(P("M 200 440 L 312 440 L 300 486 L 212 486 Z"), "#FF8FA3", sw=10) +
    face(214, 298, 250, r=18, cheek_dy=30, smile_dy=36)
)

PACKS = {
    "ShadowVehicles": ("vehicles", vehicles),
    "ShadowFood": ("food", food),
    "ShadowOcean": ("ocean", ocean),
}


def write_imageset(folder, name, svg_text):
    d = os.path.join(folder, f"{name}.imageset")
    os.makedirs(d, exist_ok=True)
    cairosvg.svg2png(bytestring=svg_text.encode(), write_to=os.path.join(d, f"{name}.png"), output_width=1024, output_height=1024)
    with open(os.path.join(d, "Contents.json"), "w") as f:
        json.dump({"images": [{"filename": f"{name}.png", "idiom": "universal"}], "info": {"author": "xcode", "version": 1}}, f, indent=2)


if __name__ == "__main__":
    assets = sys.argv[1]
    for folder, (prefix, items) in PACKS.items():
        out = os.path.join(assets, folder)
        os.makedirs(out, exist_ok=True)
        with open(os.path.join(out, "Contents.json"), "w") as f:
            json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)
        for name, s in items.items():
            write_imageset(out, f"{prefix}_{name}", s)
            print("rendered", f"{prefix}_{name}")
