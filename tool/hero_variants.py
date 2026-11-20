#!/usr/bin/env python3
"""Картинки-иллюстрации для главного экрана «Начать проект».

Тот же стиль, что у знака: только прямые углы и окружности, одна толщина
линии, один цвет на белом. Формат 1600×900 — под шапку экрана.
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
W, H = 1600, 900


def svg(body: str) -> str:
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
        f'viewBox="0 0 {W} {H}">\n'
        f'<rect width="{W}" height="{H}" fill="{PAPER}"/>\n{body}\n</svg>\n'
    )


# ── A. Щит с открытой дверцей, рейка, автоматы, кабели ──────────────────
def hero_a() -> str:
    modules = []
    x = 600
    for i in range(6):
        modules.append(
            f'<rect x="{x}" y="330" width="62" height="210" fill="{INK}"/>'
        )
        # рычаг: у чётных выше, у нечётных ниже
        ly = 360 if i % 2 == 0 else 380
        modules.append(
            f'<rect x="{x + 20}" y="{ly}" width="22" height="60" fill="{PAPER}"/>'
        )
        x += 78

    cables = "".join(
        f'<path d="M{620 + i * 78} 540 V660 H{560 + i * 96}"/>'
        for i in range(6)
    )

    return svg(f"""
  <g fill="none" stroke="{INK}" stroke-width="10">
    <rect x="520" y="220" width="600" height="420"/>
    <path d="M520 300 H1120"/>
    <path d="M560 540 H1080"/>

    <!-- открытая дверца слева -->
    <path d="M520 220 L300 140 V700 L520 640 Z"/>
    <path d="M470 420 H500"/>

    {''.join(modules)}
  </g>
  <g fill="none" stroke="{INK}" stroke-width="8" stroke-linejoin="miter">
    {cables}
  </g>
  <g fill="none" stroke="{INK}" stroke-width="10">
    <path d="M1160 520 H1300"/>
    <path d="M1160 470 H1260"/>
  </g>""")


# ── B. Рейка с автоматами и уходящими кабелями, минимум ─────────────────
def hero_b() -> str:
    modules = []
    x = 420
    for i in range(5):
        modules.append(
            f'<rect x="{x}" y="300" width="96" height="260" fill="none" '
            f'stroke="{INK}" stroke-width="10"/>'
        )
        modules.append(
            f'<rect x="{x + 34}" y="340" width="28" height="90" fill="{INK}"/>'
        )
        modules.append(
            f'<path d="M{x + 48} 560 V620" stroke="{INK}" stroke-width="8"/>'
        )
        x += 120

    return svg(f"""
  <g fill="none" stroke="{INK}" stroke-width="12">
    <path d="M360 300 H1020"/>
    <path d="M360 560 H1020"/>
  </g>
  {''.join(modules)}
  <g fill="none" stroke="{INK}" stroke-width="8" stroke-linejoin="round">
    <path d="M468 620 V700 H760"/>
    <path d="M588 620 V660 H760"/>
    <path d="M708 620 V700 H760"/>
    <path d="M828 620 V660 H760"/>
    <path d="M948 620 V700 H760"/>
    <path d="M760 700 V760 H1180"/>
  </g>
  <g fill="none" stroke="{INK}" stroke-width="10">
    <rect x="1180" y="700" width="180" height="120"/>
    <path d="M1220 760 H1320"/>
  </g>""")


# ── C. Строгая композиция: контур щита, рейка, один автомат крупно ──────
def hero_c() -> str:
    return svg(f"""
  <g fill="none" stroke="{INK}" stroke-width="12">
    <rect x="480" y="160" width="640" height="560" stroke-width="14"/>
    <path d="M480 300 H1120"/>
    <path d="M480 580 H1120"/>
  </g>

  <!-- крупный автомат по центру -->
  <g fill="none" stroke="{INK}" stroke-width="14">
    <rect x="700" y="330" width="200" height="230"/>
    <rect x="770" y="368" width="60" height="110" fill="{INK}" stroke="none"/>
    <path d="M800 330 V300"/>
    <path d="M800 560 V600"/>
  </g>

  <!-- соседние модули схематично -->
  <g fill="none" stroke="{INK}" stroke-width="10">
    <rect x="560" y="360" width="100" height="200"/>
    <rect x="940" y="360" width="100" height="200"/>
    <path d="M595 410 H625"/>
    <path d="M975 410 H1005"/>
  </g>

  <!-- подпись-линия и кабель -->
  <g fill="none" stroke="{INK}" stroke-width="8">
    <path d="M800 600 V700 H1180"/>
    <path d="M1180 700 H1300"/>
  </g>""")


HEROES = [
    ("hero-a-shchit-otkryt", "Щит с открытой дверцей", hero_a),
    ("hero-b-reyka-kabelya", "Рейка с кабелями", hero_b),
    ("hero-c-odin-avtomat", "Один автомат крупно", hero_c),
]


def render(text: str, target: pathlib.Path, width: int = W) -> None:
    svg_path = target.with_suffix(".svg")
    svg_path.write_text(text, encoding="utf-8")
    subprocess.run(
        [
            sys.executable,
            "-c",
            (
                "import cairosvg;"
                f"cairosvg.svg2png(url=r'{svg_path}', write_to=r'{target}', "
                f"output_width={width})"
            ),
        ],
        check=True,
        env={"PYTHONPATH": "/tmp/pylibs", "PATH": "/usr/bin:/bin"},
    )


def main() -> None:
    OUT_SVG.mkdir(parents=True, exist_ok=True)
    OUT_PNG.mkdir(parents=True, exist_ok=True)
    for slug, title, builder in HEROES:
        render(builder(), OUT_PNG / f"{slug}.png")
        (OUT_SVG / f"{slug}.svg").write_text(builder(), encoding="utf-8")
        print(f"{slug}: {title}")
    print(f"\nSVG: {OUT_SVG}\nPNG: {OUT_PNG}")


if __name__ == "__main__":
    main()
