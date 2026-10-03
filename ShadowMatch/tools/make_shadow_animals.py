#!/usr/bin/env python3
"""Original kawaii cartoon animals for Nubee's Peekaboo Shapes game.
Each animal is authored as SVG (512x512 viewBox) and rendered to a transparent 1024px PNG.
"""
import os, sys
import cairosvg

OUT = "#3B2A4A"   # outline ink
SW = 12           # outline width
PINK = "#FF8FA3"

def blob(shapes, fill, sw=SW):
    """Compound shape with a single outer outline: stroke everything first, then fill on top."""
    stroked = "".join(s.format(fill=OUT, extra=f'stroke="{OUT}" stroke-width="{sw*2}" stroke-linejoin="round"') for s in shapes)
    filled = "".join(s.format(fill=fill, extra='') for s in shapes)
    return f"<g>{stroked}</g><g>{filled}</g>"

def C(cx, cy, r):
    return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{{fill}}" {{extra}}/>'

def E(cx, cy, rx, ry, rot=0):
    t = f' transform="rotate({rot} {cx} {cy})"' if rot else ""
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{{fill}}" {{extra}}{t}/>'

def P(d):
    return f'<path d="{d}" fill="{{fill}}" {{extra}}/>'

def R(x, y, w, h, r):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{{fill}}" {{extra}}/>'

def shape(s, fill, stroke=True, sw=SW):
    extra = f'stroke="{OUT}" stroke-width="{sw}" stroke-linejoin="round" stroke-linecap="round"' if stroke else ""
    return s.format(fill=fill, extra=extra)

def eye(cx, cy, r=22):
    return (f'<ellipse cx="{cx}" cy="{cy}" rx="{r}" ry="{r*1.18}" fill="{OUT}"/>'
            f'<circle cx="{cx - r*0.35}" cy="{cy - r*0.45}" r="{r*0.38}" fill="white"/>'
            f'<circle cx="{cx + r*0.35}" cy="{cy + r*0.4}" r="{r*0.16}" fill="white"/>')

def cheeks(x1, x2, y, rx=26, ry=16):
    return (f'<ellipse cx="{x1}" cy="{y}" rx="{rx}" ry="{ry}" fill="{PINK}" opacity="0.65"/>'
            f'<ellipse cx="{x2}" cy="{y}" rx="{rx}" ry="{ry}" fill="{PINK}" opacity="0.65"/>')

def smile(cx, cy, w=36, h=18, sw=9):
    return (f'<path d="M {cx-w} {cy} Q {cx-w/2} {cy+h} {cx} {cy} Q {cx+w/2} {cy+h} {cx+w} {cy}" '
            f'fill="none" stroke="{OUT}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round"/>')

def open_smile(cx, cy, w=40, h=34):
    return (f'<path d="M {cx-w} {cy} Q {cx} {cy+h*2} {cx+w} {cy} Z" fill="#E8546B" stroke="{OUT}" '
            f'stroke-width="9" stroke-linejoin="round"/>'
            f'<path d="M {cx-w*0.45} {cy+h*0.62} Q {cx} {cy+h*0.95} {cx+w*0.45} {cy+h*0.62} Q {cx} {cy+h*0.35} {cx-w*0.45} {cy+h*0.62} Z" fill="#FF9BAA"/>')

def svg(body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">{body}</svg>'

animals = {}

# 1. Lion — scalloped mane
mane = [C(256 + 150 * __import__("math").cos(a * 3.14159 / 6), 262 + 150 * __import__("math").sin(a * 3.14159 / 6), 62) for a in range(12)]
mane.append(C(256, 262, 160))
animals["lion"] = svg(
    blob(mane, "#E8822A") +
    shape(C(176, 160, 34), "#FFC857") + shape(C(336, 160, 34), "#FFC857") +
    f'<circle cx="176" cy="160" r="16" fill="#F4A259"/><circle cx="336" cy="160" r="16" fill="#F4A259"/>' +
    shape(C(256, 262, 122), "#FFC857") +
    shape(E(256, 316, 64, 44), "#FFF1D0") +
    eye(212, 250) + eye(300, 250) + cheeks(184, 328, 300) +
    shape(P("M 236 292 Q 256 284 276 292 Q 272 312 256 316 Q 240 312 236 292 Z"), "#7A4A2E", sw=8) +
    smile(256, 324, w=26, h=16)
)

# 2. Elephant — big ears + curly trunk
animals["elephant"] = svg(
    shape(E(118, 240, 100, 128, -12), "#9FB0D4") + shape(E(394, 240, 100, 128, 12), "#9FB0D4") +
    f'<ellipse cx="124" cy="244" rx="62" ry="86" fill="#F5B7C8" transform="rotate(-12 124 244)"/>'
    f'<ellipse cx="388" cy="244" rx="62" ry="86" fill="#F5B7C8" transform="rotate(12 388 244)"/>' +
    f'<path d="M 256 300 C 256 380 250 420 300 440 C 330 452 352 430 340 410" fill="none" stroke="{OUT}" stroke-width="84" stroke-linecap="round"/>' +
    shape(C(256, 226, 132), "#BCC9E3") +
    f'<path d="M 256 300 C 256 380 250 420 300 440 C 330 452 352 430 340 410" fill="none" stroke="#BCC9E3" stroke-width="60" stroke-linecap="round"/>' +
    f'<path d="M 236 360 Q 256 366 276 358 M 240 392 Q 258 398 278 390" fill="none" stroke="#8E9FC4" stroke-width="7" stroke-linecap="round"/>' +
    eye(206, 214) + eye(306, 214) + cheeks(170, 342, 266)
)

# 3. Giraffe — long neck, full body
animals["giraffe"] = svg(
    blob([
        R(170, 380, 34, 112, 16), R(216, 384, 34, 108, 16), R(300, 384, 34, 108, 16), R(346, 380, 34, 112, 16),
        E(274, 384, 128, 70),
        P("M 236 140 L 312 140 L 336 380 L 232 380 Z"),
        E(278, 112, 78, 60),
        R(232, 24, 14, 60, 7), R(298, 24, 14, 60, 7), C(239, 26, 16), C(305, 26, 16),
        E(196, 92, 34, 16, -25), E(360, 92, 34, 16, 25),
    ], "#F9C74F") +
    f'<rect x="170" y="466" width="34" height="26" rx="12" fill="#8A5A3B"/><rect x="216" y="466" width="34" height="26" rx="12" fill="#8A5A3B"/>'
    f'<rect x="300" y="466" width="34" height="26" rx="12" fill="#8A5A3B"/><rect x="346" y="466" width="34" height="26" rx="12" fill="#8A5A3B"/>'
    f'<circle cx="239" cy="26" r="11" fill="#8A5A3B"/><circle cx="305" cy="26" r="11" fill="#8A5A3B"/>' +
    "".join(f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="#D98B3A"/>' for x, y, rx, ry in
            [(266, 200, 18, 14), (300, 252, 16, 13), (262, 300, 20, 15), (306, 340, 17, 13), (200, 380, 22, 16),
             (260, 410, 20, 14), (330, 400, 22, 15), (380, 372, 16, 12)]) +
    shape(E(296, 134, 46, 30), "#FFE3A3", sw=8) +
    f'<circle cx="284" cy="132" r="5" fill="{OUT}"/><circle cx="310" cy="132" r="5" fill="{OUT}"/>' +
    eye(246, 102, 16) + eye(318, 102, 16) + cheeks(226, 340, 128, rx=16, ry=10) +
    smile(296, 150, w=18, h=10, sw=7)
)

# 4. Monkey — side ears, heart face, curly tail
animals["monkey"] = svg(
    f'<path d="M 360 380 C 470 400 480 280 420 270 C 380 264 380 320 410 318" fill="none" stroke="{OUT}" stroke-width="44" stroke-linecap="round"/>'
    f'<path d="M 360 380 C 470 400 480 280 420 270 C 380 264 380 320 410 318" fill="none" stroke="#8B5A3C" stroke-width="22" stroke-linecap="round"/>' +
    shape(C(122, 250, 50), "#8B5A3C") + shape(C(390, 250, 50), "#8B5A3C") +
    f'<circle cx="122" cy="250" r="28" fill="#F2C6A0"/><circle cx="390" cy="250" r="28" fill="#F2C6A0"/>' +
    shape(C(256, 250, 138), "#8B5A3C") +
    blob([C(212, 226, 60), C(300, 226, 60), E(256, 310, 96, 68)], "#F2C6A0", sw=0) +
    eye(214, 228) + eye(298, 228) + cheeks(176, 336, 292) +
    f'<circle cx="244" cy="290" r="6" fill="{OUT}"/><circle cx="268" cy="290" r="6" fill="{OUT}"/>' +
    open_smile(256, 318, w=36, h=26) +
    f'<path d="M 230 116 Q 256 90 268 120 Q 280 100 290 118" fill="none" stroke="{OUT}" stroke-width="9" stroke-linecap="round"/>'
)

# 5. Penguin — egg body, flippers, orange feet
animals["penguin"] = svg(
    shape(E(180, 470, 46, 22), "#FF9F1C") + shape(E(332, 470, 46, 22), "#FF9F1C") +
    shape(E(112, 300, 34, 92, 24), "#2E3A59") + shape(E(400, 300, 34, 92, -24), "#2E3A59") +
    shape(E(256, 280, 140, 186), "#2E3A59") +
    blob([E(256, 330, 100, 126), C(212, 210, 62), C(300, 210, 62)], "#FFFFFF", sw=0) +
    eye(214, 208) + eye(298, 208) + cheeks(184, 328, 252) +
    shape(P("M 228 244 L 284 244 L 256 284 Z"), "#FF9F1C", sw=8)
)

# 6. Frog — wide head, eye bumps, big smile
animals["frog"] = svg(
    blob([E(256, 312, 190, 132), C(164, 190, 70), C(348, 190, 70)], "#6CC24A") +
    f'<circle cx="164" cy="190" r="46" fill="white" stroke="{OUT}" stroke-width="8"/>'
    f'<circle cx="348" cy="190" r="46" fill="white" stroke="{OUT}" stroke-width="8"/>' +
    eye(170, 194, 24) + eye(342, 194, 24) +
    f'<ellipse cx="256" cy="360" rx="120" ry="70" fill="#A6DD7E"/>' +
    cheeks(140, 372, 300, rx=30, ry=18) +
    f'<circle cx="236" cy="270" r="6" fill="{OUT}"/><circle cx="276" cy="270" r="6" fill="{OUT}"/>' +
    f'<path d="M 156 310 Q 256 400 356 310" fill="none" stroke="{OUT}" stroke-width="11" stroke-linecap="round"/>'
)

# 7. Owl — ear tufts, face disks, wings
animals["owl"] = svg(
    shape(E(220, 462, 30, 16), "#FF9F1C") + shape(E(292, 462, 30, 16), "#FF9F1C") +
    blob([E(256, 290, 144, 174), P("M 136 170 L 150 60 L 222 132 Z"), P("M 376 170 L 362 60 L 290 132 Z")], "#9C6B4E") +
    shape(E(126, 320, 40, 96, 12), "#7A4F38") + shape(E(386, 320, 40, 96, -12), "#7A4F38") +
    f'<ellipse cx="256" cy="350" rx="92" ry="100" fill="#E8C9A0"/>' +
    "".join(f'<path d="M {x-14} {y} Q {x} {y+14} {x+14} {y}" fill="none" stroke="#B08560" stroke-width="7" stroke-linecap="round"/>'
            for x, y in [(226, 320), (286, 320), (256, 350), (226, 380), (286, 380), (256, 410)]) +
    shape(C(204, 226, 64), "#F3E1C7", sw=9) + shape(C(308, 226, 64), "#F3E1C7", sw=9) +
    eye(208, 228, 30) + eye(304, 228, 30) +
    shape(P("M 240 262 L 272 262 L 256 296 Z"), "#FF9F1C", sw=8)
)

# 8. Pig — pointy ears on top, snout
animals["pig"] = svg(
    shape(P("M 140 190 L 150 80 L 236 140 Z"), "#F48BA3") + shape(P("M 372 190 L 362 80 L 276 140 Z"), "#F48BA3") +
    shape(C(256, 270, 150), "#F7A8B8") +
    eye(196, 238) + eye(316, 238) + cheeks(158, 354, 296, rx=30, ry=18) +
    shape(E(256, 300, 66, 46), "#F48BA3", sw=10) +
    f'<ellipse cx="234" cy="300" rx="11" ry="17" fill="{OUT}"/><ellipse cx="278" cy="300" rx="11" ry="17" fill="{OUT}"/>' +
    smile(256, 366, w=30, h=16)
)

# 9. Turtle — dome shell, side view
animals["turtle"] = svg(
    blob([R(120, 360, 56, 84, 24), R(320, 360, 56, 84, 24), P("M 72 372 L 22 396 L 80 406 Z")], "#A7D676") +
    blob([P("M 360 380 L 392 286 L 450 300 L 420 384 Z"), C(440, 262, 62)], "#A7D676") +
    shape(P("M 62 384 Q 62 166 240 166 Q 418 166 418 384 Z"), "#5BAA5B") +
    f'<path d="M 180 202 L 240 186 L 300 202 L 310 268 L 240 298 L 170 268 Z" fill="#3E8E41"/>'
    f'<path d="M 100 330 L 140 248 L 170 268 L 160 340 Z" fill="#3E8E41"/>'
    f'<path d="M 380 330 L 340 248 L 310 268 L 320 340 Z" fill="#3E8E41"/>'
    f'<path d="M 190 340 L 240 310 L 290 340 L 280 372 L 200 372 Z" fill="#3E8E41"/>' +
    shape(R(48, 362, 384, 34, 17), "#8CC86A") +
    eye(446, 248, 18) + f'<ellipse cx="474" cy="280" rx="14" ry="9" fill="{PINK}" opacity="0.65"/>' +
    smile(452, 286, w=18, h=10, sw=7)
)

# 10. Fox — pointy ears, white cheeks, bushy tail
animals["fox"] = svg(
    blob([P("M 300 420 C 470 470 500 320 430 260 C 450 340 380 380 330 360 Z")], "#F28C38") +
    '<clipPath id="foxtail"><path d="M 300 420 C 470 470 500 320 430 260 C 450 340 380 380 330 360 Z"/></clipPath>'
    '<circle cx="452" cy="280" r="46" fill="white" clip-path="url(#foxtail)"/>' +
    blob([P("M 106 70 L 216 160 L 296 160 L 406 70 L 410 250 Q 400 340 256 420 Q 112 340 102 250 Z")], "#F28C38") +
    f'<path d="M 130 110 L 196 164 L 140 196 Z" fill="#7A3B1A"/><path d="M 382 110 L 316 164 L 372 196 Z" fill="#7A3B1A"/>' +
    f'<path d="M 108 262 Q 180 270 228 326 Q 256 360 256 410 Q 130 344 108 262 Z" fill="white"/>'
    f'<path d="M 404 262 Q 332 270 284 326 Q 256 360 256 410 Q 382 344 404 262 Z" fill="white"/>' +
    eye(200, 240) + eye(312, 240) + cheeks(168, 344, 290) +
    shape(E(256, 330, 22, 15), OUT, sw=6) + smile(256, 356, w=22, h=12, sw=7)
)

if __name__ == "__main__":
    out_dir = sys.argv[1]
    os.makedirs(out_dir, exist_ok=True)
    for name, s in animals.items():
        open(os.path.join(out_dir, f"{name}.svg"), "w").write(s)
        cairosvg.svg2png(bytestring=s.encode(), write_to=os.path.join(out_dir, f"{name}.png"),
                         output_width=1024, output_height=1024)
        print("rendered", name)
