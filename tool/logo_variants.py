#!/usr/bin/env python3
"""Восемь вариантов знака «Электрощит»: строгая чёрно-белая графика.

Каждый вариант — отдельный SVG (масштабируется без потерь) и PNG 512×512
для просмотра. Плюс общий лист-превью сеткой 2×4.

Стиль: только прямые углы и окружности, одна толщина линии, один цвет.
"""
from __future__ import annotations

import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT_SVG = ROOT / "assets/branding"
OUT_PNG = ROOT / "store/logo-variants"
INK = "#111827"
PAPER = "#FFFFFF"
SIZE = 512


def svg(body: str, background: bool = True) -> str:
    bg = f'<rect width="{SIZE}" height="{SIZE}" fill="{PAPER}"/>' if background else ""
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" '
        f'viewBox="0 0 {SIZE} {SIZE}">\n{bg}\n{body}\n</svg>\n'
    )


# ── 1. Автомат в профиль: корпус, рычаг, два контакта ───────────────────
def v1_breaker() -> str:
    return svg(f"""
  <g fill="none" stroke="{INK}" stroke-width="14" stroke-linecap="square">
    <rect x="176" y="128" width="160" height="256"/>
    <rect x="232" y="200" width="48" height="112" fill="{INK}" stroke="none"/>
    <path d="M256 128 V96" />
    <path d="M256 384 V416" />
  </g>""")


# ── 2. Три модуля на рейке ──────────────────────────────────────────────
def v2_three_modules() -> str:
    return svg(f"""
  <g fill="none" stroke="{INK}" stroke-width="14" stroke-linecap="square">
    <path d="M96 128 H416"/>
    <path d="M96 384 H416"/>
    <rect x="120" y="128" width="64" height="256"/>
    <rect x="224" y="128" width="64" height="256"/>
    <rect x="328" y="128" width="64" height="256"/>
    <path d="M140 176 H164" stroke-width="18"/>
    <path d="M244 320 H268" stroke-width="18"/>
    <path d="M348 176 H372" stroke-width="18"/>
  </g>""")


# ── 3. Монограмма «Э» из модулей ────────────────────────────────────────
def v3_letter_e() -> str:
    return svg(f"""
  <g fill="{INK}">
    <rect x="128" y="104" width="44" height="304"/>
    <rect x="128" y="104" width="256" height="44"/>
    <rect x="128" y="234" width="196" height="44"/>
    <rect x="128" y="364" width="256" height="44"/>
  </g>""")


# ── 4. Щит в разрезе: рамка, рейка, три автомата ────────────────────────
def v4_panel_cutaway() -> str:
    return svg(f"""
  <g fill="none" stroke="{INK}" stroke-width="14">
    <rect x="96" y="112" width="320" height="288"/>
    <path d="M96 208 H416" />
    <rect x="128" y="228" width="72" height="128" fill="{INK}" stroke="none"/>
    <rect x="236" y="228" width="72" height="128" fill="{INK}" stroke="none"/>
    <rect x="344" y="228" width="48" height="128" fill="{INK}" stroke="none"/>
    <path d="M160 160 H352"/>
  </g>""")


# ── 5. Молния в модуле ──────────────────────────────────────────────────
def v5_bolt() -> str:
    return svg(f"""
  <g fill="none" stroke="{INK}" stroke-width="14" stroke-linejoin="miter">
    <rect x="152" y="88" width="208" height="336"/>
    <path d="M280 156 L224 264 H268 L236 364" stroke-width="30"
          fill="none" stroke-linejoin="miter"/>
  </g>""")


# ── 6. Рейка с защёлкой ─────────────────────────────────────────────────
def v6_rail() -> str:
    return svg(f"""
  <g fill="none" stroke="{INK}" stroke-width="18" stroke-linecap="square">
    <path d="M88 256 H424"/>
    <path d="M88 184 V328"/>
    <path d="M424 184 V328"/>
    <path d="M168 256 V304"/>
    <path d="M256 256 V304"/>
    <path d="M344 256 V304"/>
    <path d="M168 256 V208"/>
    <path d="M344 256 V208"/>
  </g>""")


# ── 7. Дверца щита с индикатором ────────────────────────────────────────
def v7_door() -> str:
    return svg(f"""
  <g fill="none" stroke="{INK}" stroke-width="16">
    <rect x="112" y="96" width="288" height="320"/>
    <rect x="152" y="136" width="208" height="240"/>
    <circle cx="316" cy="256" r="16" fill="{INK}" stroke="none"/>
    <path d="M160 256 H204" stroke-width="20"/>
  </g>""")


# ── 8. «Э» с молнией в негативе ─────────────────────────────────────────
def v8_e_bolt() -> str:
    return svg(f"""
  <g fill="{INK}">
    <rect x="136" y="104" width="40" height="304"/>
    <rect x="136" y="104" width="200" height="40"/>
    <rect x="136" y="368" width="200" height="40"/>
  </g>
  <path d="M336 128 L280 240 H332 L296 384" fill="none"
        stroke="{INK}" stroke-width="26" stroke-linejoin="miter"/>
  <g fill="none" stroke="{INK}" stroke-width="14">
    <path d="M240 236 H264"/>
  </g>""")


VARIANTS = [
    ("01-avtomat", "Автомат в профиль", v1_breaker, "узнаваемый модуль, рычаг включён"),
    ("02-tri-modulya", "Три модуля", v2_three_modules, "щит как ряд автоматов на рейке"),
    ("03-monogramma-e", "Монограмма «Э»", v3_letter_e, "буква из DIN-модулей"),
    ("04-shchit-v-razreze", "Щит в разрезе", v4_panel_cutaway, "рамка, рейка, три аппарата"),
    ("05-molniya", "Молния в модуле", v5_bolt, "энергия внутри корпуса"),
    ("06-reyka", "DIN-рейка", v6_rail, "только конструктив, без символов"),
    ("07-dvertsa", "Дверца щита", v7_door, "строгая рамка в рамке + индикатор"),
    ("08-e-molniya", "«Э» и молния", v8_e_bolt, "монограмма плюс разряд"),
]


def render(svg_text: str, target: pathlib.Path, size: int = SIZE) -> None:
    svg_path = target.with_suffix(".svg")
    svg_path.write_text(svg_text, encoding="utf-8")
    subprocess.run(
        [
            sys.executable,
            "-c",
            (
                "import cairosvg,sys;"
                f"cairosvg.svg2png(url=r'{svg_path}', write_to=r'{target}', "
                f"output_width={size}, output_height={size})"
            ),
        ],
        check=True,
        env={"PYTHONPATH": "/tmp/pylibs", "PATH": "/usr/bin:/bin"},
    )


def main() -> None:
    OUT_SVG.mkdir(parents=True, exist_ok=True)
    OUT_PNG.mkdir(parents=True, exist_ok=True)
    for slug, title, builder, note in VARIANTS:
        png = OUT_PNG / f"{slug}.png"
        render(builder(), png)
        (OUT_SVG / f"{slug}.svg").write_text(builder(), encoding="utf-8")
        print(f"{slug}: {title} — {note}")
    print(f"\nSVG: {OUT_SVG}\nPNG: {OUT_PNG}")


if __name__ == "__main__":
    main()
