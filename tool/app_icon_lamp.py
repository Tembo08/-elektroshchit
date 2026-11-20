#!/usr/bin/env python3
"""Иконка приложения «Электрощит»: лампочка + вилка.

Стиль A из серии вариантов: чёрный знак на белом, без рамки и сетки —
рамку для adaptive-иконки Android рисует сам маской.

Что делает:
1. Мастер-SVG 512×512 (знак без фона).
2. PNG-мастер 1024 для магазина.
3. Android: ic_launcher.png (48…192) и ic_launcher_foreground.png
   (108…432, знак в безопасной зоне 66 %).
4. Белый фон adaptive-иконки.
"""
from __future__ import annotations

import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
RES = ROOT / "android/app/src/main/res"
STORE = ROOT / "store"
BRAND = ROOT / "assets/branding"

INK = "#111827"
PAPER = "#FFFFFF"
SIZE = 512


def icon_svg(scale: float = 1.0, background: str | None = None) -> str:
    """Знак: лампочка сверху, вилка снизу, толстые линии."""
    cx = 256.0
    lw = 22

    # лампочка
    bulb_cy = 186.0
    r = 62.0
    bulb = f"""
    <circle cx="{cx}" cy="{bulb_cy}" r="{r}"/>
    <path d="M{cx - 20} {bulb_cy + 20} C{cx - 12} {bulb_cy + 36} {cx + 12} {bulb_cy + 36} {cx + 20} {bulb_cy + 20}"/>
    <path d="M{cx - 24} {bulb_cy + 44} H{cx + 24}"/>
    <path d="M{cx - 16} {bulb_cy + 44} H{cx + 16}" stroke-width="14"/>
    <path d="M{cx - 24} {bulb_cy + 62} H{cx + 24}"/>
    <path d="M{cx - 29} {bulb_cy + 62} V{bulb_cy + 88}"/>
    <path d="M{cx + 29} {bulb_cy + 62} V{bulb_cy + 88}"/>
    <path d="M{cx} {bulb_cy - 76} L{cx} {bulb_cy - 48}"/>"""

    # вилка
    plug_cy = 382.0
    plug = f"""
    <path d="M{cx - 26} {plug_cy - 14} V{plug_cy - 66}"/>
    <path d="M{cx + 26} {plug_cy - 14} V{plug_cy - 66}"/>
    <path d="M{cx - 38} {plug_cy - 14} H{cx + 38} V{plug_cy + 26}"/>
    <path d="M{cx - 38} {plug_cy + 26} C{cx - 22} {plug_cy + 50} {cx + 22} {plug_cy + 50} {cx + 38} {plug_cy + 26}"/>"""

    bg = ""
    if background:
        bg = f'<rect width="{SIZE}" height="{SIZE}" fill="{background}"/>'

    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}"
     viewBox="0 0 {SIZE} {SIZE}">
  {bg}
  <g transform="translate({SIZE/2} {SIZE/2 - 12}) scale({scale}) translate({-SIZE/2} {-SIZE/2})"
     fill="none" stroke="{INK}" stroke-width="{lw}"
     stroke-linecap="round" stroke-linejoin="round">
    {bulb}
    {plug}
  </g>
</svg>
"""


def render(svg_text: str, target: pathlib.Path, width: int) -> None:
    svg_path = target.with_suffix(".svg")
    svg_path.write_text(svg_text, encoding="utf-8")
    target.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            sys.executable,
            "-c",
            (
                "import cairosvg;"
                f"cairosvg.svg2png(url=r'{svg_path}', write_to=r'{target}', "
                f"output_width={width}, output_height={width})"
            ),
        ],
        check=True,
        env={"PYTHONPATH": "/tmp/pylibs", "PATH": "/usr/bin:/bin"},
    )


def main() -> None:
    BRAND.mkdir(parents=True, exist_ok=True)
    STORE.mkdir(parents=True, exist_ok=True)

    master_svg = icon_svg()
    (BRAND / "icon-lamp-plug.svg").write_text(master_svg, encoding="utf-8")

    # белый фон + знак: обычная иконка
    filled = icon_svg(background=PAPER)
    render(filled, STORE / "icon-1024.png", 1024)

    # Android: обычные иконки (белый фон)
    legacy = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for density, px in legacy.items():
        target = RES / f"mipmap-{density}/ic_launcher.png"
        render(filled, target, px)

    # Android: adaptive foreground — прозрачный фон, знак в безопасной зоне
    foreground = icon_svg(scale=0.62)
    adaptive = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
    for density, px in adaptive.items():
        target = RES / f"mipmap-{density}/ic_launcher_foreground.png"
        render(foreground, target, px)

    # белый фон adaptive-иконки
    bg_xml = RES / "values/ic_launcher_background.xml"
    bg_xml.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        '    <color name="ic_launcher_background">#FFFFFF</color>\n'
        "</resources>\n",
        encoding="utf-8",
    )

    print("готово: store/icon-1024.png, mipmap-* (обычные и adaptive)")


if __name__ == "__main__":
    main()
