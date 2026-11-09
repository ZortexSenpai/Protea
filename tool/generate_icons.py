#!/usr/bin/env python3
"""Regenerate all platform app icons from logo.png (run from the repo root).

logo.png is squircle-on-black artwork. The black is opaque, so the squircle is
extracted and masked to transparency, then written out in the shape each
platform expects:

- macOS: squircle on a transparent 1024 canvas with Apple's margins (icon
  content is 824/1024 of the canvas).
- iOS: full-bleed opaque square (iOS applies its own mask, alpha is not
  allowed); the squircle's background color fills the corners seamlessly.
- Android legacy mipmaps / Windows .ico: squircle with transparent corners,
  no extra margin.
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
S = 1024  # master canvas size


def find_squircle_bounds(img):
    """Bounding box of the non-black squircle, scanned through the center."""
    px = img.load()
    w, h = img.size
    cx, cy = w // 2, h // 2

    def is_bg(c):
        return c[0] < 25 and c[1] < 25 and c[2] < 25

    left = next(x for x in range(w) if not is_bg(px[x, cy]))
    right = next(x for x in range(w - 1, -1, -1) if not is_bg(px[x, cy]))
    top = next(y for y in range(h) if not is_bg(px[cx, y]))
    bottom = next(y for y in range(h - 1, -1, -1) if not is_bg(px[cx, y]))
    return left, top, right, bottom


def corner_radius(img, bounds):
    """Rows from the top until the artwork reaches its left edge ≈ radius."""
    px = img.load()
    left, top, right, _ = bounds

    def is_bg(c):
        return c[0] < 25 and c[1] < 25 and c[2] < 25

    for dy in range((right - left) // 2):
        x = left
        while x < right and is_bg(px[x, top + dy]):
            x += 1
        if x <= left + 1:
            return dy
    raise AssertionError('no corner radius found — is logo.png squircle art?')


def rounded_mask(size, radius, inset=2, oversample=4):
    """Antialiased rounded-rect alpha mask, inset to hide edge fringe."""
    big = size * oversample
    mask = Image.new('L', (big, big), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [inset * oversample, inset * oversample,
         big - 1 - inset * oversample, big - 1 - inset * oversample],
        radius=radius * oversample,
        fill=255,
    )
    return mask.resize((size, size), Image.LANCZOS)


def main():
    src = Image.open(ROOT / 'logo.png').convert('RGB')
    bounds = find_squircle_bounds(src)
    left, top, right, bottom = bounds
    side = right - left + 1
    measured_radius = corner_radius(src, bounds)

    # Sample the background color just inside a corner, past the rounding.
    probe = measured_radius + side // 20
    bg = src.getpixel((left + probe, top + probe))

    crop = src.crop((left, top, right + 1, bottom + 1)).resize(
        (S, S), Image.LANCZOS
    )
    # Never smaller than the artwork's own radius, or black corners leak in;
    # at least Apple's squircle ratio so the shape looks native.
    radius = max(round(measured_radius * S / side), round(S * 0.2237))
    tight = crop.convert('RGBA')
    tight.putalpha(rounded_mask(S, radius))

    # macOS: 824px content centered on a transparent 1024 canvas.
    macos = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    macos.paste(tight.resize((824, 824), Image.LANCZOS), (100, 100))

    # iOS: full-bleed, corners filled with the background color, no alpha.
    fullbleed = Image.new('RGB', (S, S), bg)
    fullbleed.paste(tight, (0, 0), tight)

    macos_dir = ROOT / 'macos/Runner/Assets.xcassets/AppIcon.appiconset'
    for size in (16, 32, 64, 128, 256, 512, 1024):
        macos.resize((size, size), Image.LANCZOS).save(
            macos_dir / f'app_icon_{size}.png'
        )

    ios_dir = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    ios_sizes = {
        'Icon-App-20x20@1x.png': 20, 'Icon-App-20x20@2x.png': 40,
        'Icon-App-20x20@3x.png': 60, 'Icon-App-29x29@1x.png': 29,
        'Icon-App-29x29@2x.png': 58, 'Icon-App-29x29@3x.png': 87,
        'Icon-App-40x40@1x.png': 40, 'Icon-App-40x40@2x.png': 80,
        'Icon-App-40x40@3x.png': 120, 'Icon-App-60x60@2x.png': 120,
        'Icon-App-60x60@3x.png': 180, 'Icon-App-76x76@1x.png': 76,
        'Icon-App-76x76@2x.png': 152, 'Icon-App-83.5x83.5@2x.png': 167,
        'Icon-App-1024x1024@1x.png': 1024,
    }
    for name, size in ios_sizes.items():
        fullbleed.resize((size, size), Image.LANCZOS).save(ios_dir / name)

    android_res = ROOT / 'android/app/src/main/res'
    for density, size in {
        'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192,
    }.items():
        tight.resize((size, size), Image.LANCZOS).save(
            android_res / f'mipmap-{density}/ic_launcher.png'
        )

    tight.save(
        ROOT / 'windows/runner/resources/app_icon.ico',
        sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)],
    )

    print(f'squircle: bounds={bounds} side={side} '
          f'radius={measured_radius}px (used {radius}/1024) bg=rgb{bg}')


if __name__ == '__main__':
    main()
