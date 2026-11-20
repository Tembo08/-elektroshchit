#!/usr/bin/env python3
"""Генератор иконки «Электрощит».

Рисуем программно, без дизайнерских файлов: одну мастер-картинку 1024×1024,
из неё — все размеры Android (обычные и adaptive), иконку 512 для магазина.

Запуск:  python3 tool/generate_icon.py
"""
from __future__ import annotations

import pathlib

import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import icon_art  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
ANDROID_RES = ROOT / "android/app/src/main/res"
ASSET_DIR = ROOT / "assets/icon"

BG = (11, 15, 20, 255)          # тёмный корпус
PANEL = (23, 30, 40, 255)       # панель
NEON = (53, 230, 255, 255)      # неоновый контур
NEON_DIM = (53, 230, 255, 90)
BLOCK = (226, 244, 255, 255)    # автоматы
ACCENT = (76, 232, 158, 255)    # зелёный акцент (земля/норма)

SIZE = 1024


def rounded(draw: ImageDraw.ImageDraw, box, radius, fill=None, outline=None,
            width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline,
                           width=width)


def draw_panel(canvas: Image.Image, scale: float = 1.0) -> None:
    """Рисует знак иконки: рубильник (см. tool/icon_art.py)."""
    icon_art.draw_knife(canvas, s=scale)


def make_master() -> Image.Image:
    """Мастер 1024×1024: тёмный скруглённый квадрат + свечение + щит."""
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

    # фон
    bg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    rounded(ImageDraw.Draw(bg), (0, 0, SIZE - 1, SIZE - 1), 220, fill=BG)
    canvas.alpha_composite(bg)

    # свечение под щитом
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw_panel(glow)
    glow = glow.filter(ImageFilter.GaussianBlur(38))
    canvas.alpha_composite(glow)

    # сам щит
    panel = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw_panel(panel)
    canvas.alpha_composite(panel)

    return canvas


def make_foreground() -> Image.Image:
    """Adaptive-иконка: только щит, без фона, в безопасной зоне.

    Безопасная зона adaptive-иконки — центральные 66 из 108 dp, поэтому
    рисунок занимает ~58 % холста и стоит по центру.
    """
    size = 1080
    art = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw_panel(art, scale=1.0)

    bbox = art.getbbox()
    art = art.crop(bbox)
    target = int(size * 0.58)
    ratio = target / max(art.width, art.height)
    art = art.resize(
        (max(1, int(art.width * ratio)), max(1, int(art.height * ratio))),
        Image.LANCZOS,
    )

    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(
        art, ((size - art.width) // 2, (size - art.height) // 2)
    )
    return canvas


def main() -> None:
    master = make_master()
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    master.save(ASSET_DIR / "icon_1024.png")
    master.resize((512, 512), Image.LANCZOS).save(ASSET_DIR / "icon_512.png")

    # обычные (legacy) иконки
    legacy_sizes = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144,
                    "xxxhdpi": 192}
    for density, px in legacy_sizes.items():
        out = ANDROID_RES / f"mipmap-{density}"
        out.mkdir(parents=True, exist_ok=True)
        master.resize((px, px), Image.LANCZOS).save(out / "ic_launcher.png")

    # adaptive: передний план 108dp
    foreground = make_foreground()
    fg_sizes = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324,
                "xxxhdpi": 432}
    for density, px in fg_sizes.items():
        out = ANDROID_RES / f"mipmap-{density}"
        out.mkdir(parents=True, exist_ok=True)
        foreground.resize((px, px), Image.LANCZOS).save(
            out / "ic_launcher_foreground.png")

    # adaptive-описание
    anydpi = ANDROID_RES / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    xml = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"""
    (anydpi / "ic_launcher.xml").write_text(xml, encoding="utf-8")

    # цвет фона adaptive-иконки
    values = ANDROID_RES / "values"
    values.mkdir(parents=True, exist_ok=True)
    colors = values / "ic_launcher_background.xml"
    colors.write_text(
        """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#0B0F14</color>
</resources>
""",
        encoding="utf-8",
    )

    print("готово:")
    print("  assets/icon/icon_1024.png")
    print("  assets/icon/icon_512.png")
    print(f"  {len(legacy_sizes)} legacy + {len(fg_sizes)} adaptive в android res")


if __name__ == "__main__":
    main()
