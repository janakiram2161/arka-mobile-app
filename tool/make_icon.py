"""Builds the app icon from the ARKA logo (assets/images/arka_logo_dark.png).

Writes assets/icon/icon.png (1024x1024, white background), assets/icon/icon_fg.png
(adaptive-icon foreground with safe-zone padding) and flutter_launcher_icons.yaml.
"""
import os
import sys

from PIL import Image

LOGO = os.path.join("assets", "images", "arka_logo_dark.png")
OUT_DIR = os.path.join("assets", "icon")
SIZE = 1024
BACKGROUND = (255, 255, 255)


def place(logo, width_ratio, bg):
    canvas = Image.new("RGBA", (SIZE, SIZE), (bg + (255,)) if bg else (0, 0, 0, 0))
    scale = (SIZE * width_ratio) / logo.width
    resized = logo.resize((int(logo.width * scale), int(logo.height * scale)), Image.LANCZOS)
    canvas.alpha_composite(resized, ((SIZE - resized.width) // 2, (SIZE - resized.height) // 2))
    return canvas


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    logo = Image.open(LOGO).convert("RGBA")
    logo = logo.crop(logo.getchannel("A").getbbox())
    place(logo, 0.74, BACKGROUND).convert("RGB").save(os.path.join(OUT_DIR, "icon.png"))
    place(logo, 0.56, None).save(os.path.join(OUT_DIR, "icon_fg.png"))
    with open("flutter_launcher_icons.yaml", "w", encoding="utf-8") as f:
        f.write(
            "flutter_launcher_icons:\n"
            "  android: true\n"
            "  ios: true\n"
            "  image_path: \"assets/icon/icon.png\"\n"
            "  adaptive_icon_background: \"#FFFFFF\"\n"
            "  adaptive_icon_foreground: \"assets/icon/icon_fg.png\"\n"
            "  remove_alpha_ios: true\n"
            "  min_sdk_android: 21\n"
        )
    print("Icon written from", LOGO)
    return 0


if __name__ == "__main__":
    sys.exit(main())
