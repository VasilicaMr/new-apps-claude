#!/usr/bin/env python3
"""Composite a raw macOS app-window screenshot onto an exact App Store Connect
canvas size (default 1280x800).

Realto's window is sized for a phone-portrait wizard (~480x720 min, see
ListingReelApp.swift), not landscape App Store screenshot dimensions, so a
raw window capture needs to be centered on a branded canvas rather than
stretched. This mirrors Theme.Palette.background (#0A0D17) so the canvas
reads as part of the app rather than an obvious frame.

Usage:
    python3 Scripts/compose-appstore-screenshot.py INPUT.png OUTPUT.png \
        [--width 1280] [--height 800]
"""
import argparse
import sys

try:
    from PIL import Image, ImageFilter
except ImportError:
    sys.exit("Pillow is required: pip3 install pillow")

# Theme.Palette.background = Color(red: 0.04, green: 0.05, blue: 0.09)
BACKGROUND = (10, 13, 23)
SHADOW_ALPHA = 120
SHADOW_BLUR = 40
SHADOW_OFFSET_Y = 14
MARGIN_FRACTION = 0.08  # leave breathing room around the window on the canvas


def compose(input_path: str, output_path: str, width: int, height: int) -> None:
    shot = Image.open(input_path).convert("RGBA")

    # Scale the window screenshot to fit within the canvas minus margins,
    # upscaling only if it's smaller than the target (never distort aspect).
    max_w = int(width * (1 - MARGIN_FRACTION))
    max_h = int(height * (1 - MARGIN_FRACTION))
    scale = min(max_w / shot.width, max_h / shot.height)
    new_size = (round(shot.width * scale), round(shot.height * scale))
    shot = shot.resize(new_size, Image.LANCZOS)

    canvas = Image.new("RGBA", (width, height), BACKGROUND + (255,))

    x = (width - shot.width) // 2
    y = (height - shot.height) // 2

    # Soft drop shadow: a blurred black rounded rect behind the screenshot.
    shadow = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    shadow_layer = Image.new("RGBA", shot.size, (0, 0, 0, SHADOW_ALPHA))
    shadow.paste(shadow_layer, (x, y + SHADOW_OFFSET_Y))
    shadow = shadow.filter(ImageFilter.GaussianBlur(SHADOW_BLUR))
    canvas = Image.alpha_composite(canvas, shadow)

    canvas.paste(shot, (x, y), shot)
    canvas.convert("RGB").save(output_path, "PNG")
    print(f"{output_path}: {width}x{height}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input")
    parser.add_argument("output")
    parser.add_argument("--width", type=int, default=1280)
    parser.add_argument("--height", type=int, default=800)
    args = parser.parse_args()
    compose(args.input, args.output, args.width, args.height)
