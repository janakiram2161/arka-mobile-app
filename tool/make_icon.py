"""Builds the app icon from the ARKA logo on arkaschmuck.de.

Writes assets/icon/icon.png (1024x1024, opaque), assets/icon/icon_fg.png
(adaptive-icon foreground with safe-zone padding) and flutter_launcher_icons.yaml.
The background is light or dark depending on how bright the logo is, so a
white logo never ends up on a white icon.
"""
import io
import os
import sys
import urllib.request

from PIL import Image, ImageChops, ImageDraw, ImageFont

LOGO_URLS = [
    "https://arkaschmuck.de/wp-content/uploads/2026/02/Stylized-Lettermark-Logo-for-Arka-5-3.png",
    "https://arkaschmuck.de/wp-content/uploads/2026/02/LOGO-1.webp",
]
OUT_DIR = os.path.join("assets", "icon")
SIZE = 1024
CREAM = (250, 247, 242)
INK = (28, 27, 25)
GOLD = (176, 141, 87)


def download():
    for url in LOGO_URLS:
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (ARKA app build)"})
            data = urllib.request.urlopen(req, timeout=30).read()
            img = Image.open(io.BytesIO(data)).convert("RGBA")
            print(f"Logo loaded from {url} ({img.width}x{img.height})")
            return img
        except Exception as exc:  # noqa: BLE001
            print(f"Could not load {url}: {exc}")
    return None


def trim(img):
    alpha = img.getchannel("A")
    if alpha.getextrema()[0] < 250:
        box = alpha.point(lambda a: 255 if a > 16 else 0).getbbox()
    else:
        # Opaque logo: trim the border colour taken from the top-left pixel.
        bg = Image.new("RGB", img.size, img.getpixel((0, 0))[:3])
        diff = ImageChops.difference(img.convert("RGB"), bg).convert("L")
        box = diff.point(lambda v: 255 if v > 24 else 0).getbbox()
    return img.crop(box) if box else img


def background_for(img):
    alpha = img.getchannel("A")
    if alpha.getextrema()[0] >= 250:
        return img.getpixel((0, 0))[:3]
    pixels = [p for p in img.getdata() if p[3] > 128]
    if not pixels:
        return CREAM
    lum = sum(0.2126 * r + 0.7152 * g + 0.0722 * b for r, g, b, _ in pixels) / len(pixels)
    print(f"Average logo brightness: {lum:.0f}")
    return INK if lum > 170 else CREAM


def place(logo, canvas_size, width_ratio, bg):
    canvas = Image.new("RGBA", (canvas_size, canvas_size), bg + (255,) if bg else (0, 0, 0, 0))
    target_w = int(canvas_size * width_ratio)
    scale = min(target_w / logo.width, (canvas_size * width_ratio) / logo.height)
    resized = logo.resize((max(1, int(logo.width * scale)), max(1, int(logo.height * scale))), Image.LANCZOS)
    x = (canvas_size - resized.width) // 2
    y = (canvas_size - resized.height) // 2
    canvas.alpha_composite(resized, (x, y))
    return canvas


def fallback_logo():
    img = Image.new("RGBA", (900, 300), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    try:
        font = ImageFont.load_default(size=220)
    except TypeError:
        font = ImageFont.load_default()
    draw.text((450, 150), "ARKA", fill=GOLD + (255,), font=font, anchor="mm")
    return trim(img)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    logo = download()
    if logo is None:
        print("Using a text logo instead.")
        logo = fallback_logo()
    logo = trim(logo)
    bg = background_for(logo)
    icon = place(logo, SIZE, 0.84, bg).convert("RGB")
    icon.save(os.path.join(OUT_DIR, "icon.png"))
    fg = place(logo, SIZE, 0.58, None)
    fg.save(os.path.join(OUT_DIR, "icon_fg.png"))
    hex_bg = "#%02X%02X%02X" % bg
    with open("flutter_launcher_icons.yaml", "w", encoding="utf-8") as f:
        f.write(
            "flutter_launcher_icons:\n"
            "  android: true\n"
            "  ios: true\n"
            "  image_path: \"assets/icon/icon.png\"\n"
            f"  adaptive_icon_background: \"{hex_bg}\"\n"
            "  adaptive_icon_foreground: \"assets/icon/icon_fg.png\"\n"
            "  remove_alpha_ios: true\n"
            "  min_sdk_android: 21\n"
        )
    print(f"Icon written, background {hex_bg}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
