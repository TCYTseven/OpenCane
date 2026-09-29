"""OpenCane launch-screen logo (Step 69.2). Renders the app icon as a rounded tile for the static
launch screen and the SwiftUI splash, and writes the navy launch background colour set.

Usage: python3 ios/scripts/launchlogo.py        (needs Pillow: pip install pillow)
"""
# Owner / callers: run by hand when the app icon changes (it reads Icon-1024.png, which
# `appicon.py` writes). Nothing in the build calls it; the PNGs and Contents.json it writes are
# committed. The launch screen (`UILaunchScreen` in ios/project.yml) shows `LaunchLogo` at its
# point size, centred on the `LaunchBackground` colour; `SplashView` draws the same image at the
# same size on `CKColor.brand` (same hex), so the handoff from launch screen to splash is seamless.
# ⚠ Keep BRAND in step with `CKColor.brand` in ios/CaneKit/UI/Theme.swift.
# Tests: none automated; check the PNGs by eye (a thin light rim, no halo on the navy).
from PIL import Image, ImageDraw
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "CaneKit", "Resources", "Assets.xcassets")
ICON = os.path.join(ASSETS, "AppIcon.appiconset", "Icon-1024.png")

# Logo edge in points on screen (1x). 120 pt is the size iOS itself uses for app-launch logos
# in the HIG examples; big enough to read as the icon, small enough to sit clear of Dynamic Island.
POINTS = 120
# Corner radius as a fraction of the edge: iOS app-icon corners are ~22.37 % of the edge.
CORNER = 0.2237
# Brand navy (CKColor.brand) and its increased-contrast variant, as 0-255 RGB.
BRAND = (0x0B, 0x15, 0x33)
BRAND_HC = (0x05, 0x0A, 0x1A)
# A 1 pt rim at 14 % white so the icon's own dark field does not melt into the navy.
RIM_ALPHA = 36


def tile(scale):
    """The icon at `POINTS * scale` px with rounded corners and a faint light rim, RGBA."""
    size = POINTS * scale
    ss = 4  # supersample the mask for smooth corners
    icon = Image.open(ICON).convert("RGBA").resize((size * ss, size * ss), Image.LANCZOS)
    mask = Image.new("L", (size * ss, size * ss), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size * ss - 1, size * ss - 1],
                                           radius=int(size * ss * CORNER), fill=255)
    out = Image.new("RGBA", (size * ss, size * ss), (0, 0, 0, 0))
    out.paste(icon, (0, 0), mask)
    rim = Image.new("RGBA", (size * ss, size * ss), (0, 0, 0, 0))
    ImageDraw.Draw(rim).rounded_rectangle([0, 0, size * ss - 1, size * ss - 1],
                                          radius=int(size * ss * CORNER),
                                          outline=(255, 255, 255, RIM_ALPHA), width=scale * ss)
    out = Image.alpha_composite(out, rim)
    return out.resize((size, size), Image.LANCZOS)


def write_logo():
    """LaunchLogo.imageset with @1x/@2x/@3x PNGs."""
    folder = os.path.join(ASSETS, "LaunchLogo.imageset")
    os.makedirs(folder, exist_ok=True)
    images = []
    for scale in (1, 2, 3):
        name = f"LaunchLogo@{scale}x.png"
        tile(scale).save(os.path.join(folder, name), optimize=True)
        images.append({"filename": name, "idiom": "universal", "scale": f"{scale}x"})
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump({"images": images, "info": {"author": "xcode", "version": 1}}, f, indent=2)
        f.write("\n")


def colour(rgb):
    """An asset-catalog sRGB colour entry."""
    return {"color-space": "srgb",
            "components": {"red": f"0x{rgb[0]:02X}", "green": f"0x{rgb[1]:02X}",
                           "blue": f"0x{rgb[2]:02X}", "alpha": "1.000"}}


def write_background():
    """LaunchBackground.colorset: the navy in every appearance, deeper under Increase Contrast."""
    folder = os.path.join(ASSETS, "LaunchBackground.colorset")
    os.makedirs(folder, exist_ok=True)
    colors = [
        {"idiom": "universal", "color": colour(BRAND)},
        {"idiom": "universal", "appearances": [{"appearance": "luminosity", "value": "dark"}],
         "color": colour(BRAND)},
        {"idiom": "universal", "appearances": [{"appearance": "contrast", "value": "high"}],
         "color": colour(BRAND_HC)},
        {"idiom": "universal", "appearances": [{"appearance": "luminosity", "value": "dark"},
                                               {"appearance": "contrast", "value": "high"}],
         "color": colour(BRAND_HC)},
    ]
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump({"colors": colors, "info": {"author": "xcode", "version": 1}}, f, indent=2)
        f.write("\n")


write_logo()
write_background()
print("wrote LaunchLogo.imageset and LaunchBackground.colorset")
