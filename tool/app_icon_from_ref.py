#!/usr/bin/env python3
"""Иконка приложения «Электрощит» из рисунка Романа (лампочка + вилка).

Мастер — кроп присланного рисунка: знак в скруглённой рамке, без
миллиметровки (она не читается в 48 px). Генерирует обычные иконки
Android и adaptive-foreground (знак в безопасной зоне 66 %).
"""
from __future__ import annotations

import pathlib

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
RES = ROOT / "android/app/src/main/res"
STORE = ROOT / "store"
BRAND = ROOT / "assets/branding"

# мастер-кроп знака
MASTER = BRAND / "icon-lamp-plug-crop.png"


def main() -> None:
    master = Image.open(MASTER).convert("RGB")
    side = master.width

    # 1. Мастер 1024 для магазина (белый фон уже в рисунке).
    store = STORE / "icon-1024.png"
    master.resize((1024, 1024), Image.LANCZOS).save(store)

    # 2. Обычные иконки Android: знак целиком.
    legacy = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for density, px in legacy.items():
        target = RES / f"mipmap-{density}/ic_launcher.png"
        master.resize((px, px), Image.LANCZOS).save(target)

    # 3. Adaptive foreground: знак в безопасной зоне 66 % на прозрачном.
    #    Рисунок с белым фоном — ставим на прозрачный слой.
    adaptive = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
    for density, px in adaptive.items():
        fg = Image.new("RGBA", (px, px), (0, 0, 0, 0))
        inner = int(px * 0.66)
        scaled = master.resize((inner, inner), Image.LANCZOS).convert("RGBA")
        off = (px - inner) // 2
        fg.paste(scaled, (off, off))
        target = RES / f"mipmap-{density}/ic_launcher_foreground.png"
        fg.save(target)

    # 4. Белый фон adaptive-иконки.
    bg = RES / "values/ic_launcher_background.xml"
    bg.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        '    <color name="ic_launcher_background">#FFFFFF</color>\n'
        "</resources>\n",
        encoding="utf-8",
    )

    print("готово: store/icon-1024.png, mipmap-* (обычные + adaptive)")


if __name__ == "__main__":
    main()
