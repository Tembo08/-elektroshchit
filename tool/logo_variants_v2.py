#!/usr/bin/env python3
"""Варианты на основе двух понравившихся стилей.

Стиль A — чёрно-белая иконка (лампочка + вилка в скруглённом квадрате).
Стиль B — цветной щит (тёмно-синие контуры на сером, красный индикатор).
"""
from __future__ import annotations

import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT_SVG = ROOT / "assets/branding"
OUT_PNG = ROOT / "store/logo-variants"
SIZE = 512

# ── палитра стиля B ───────────────────────────────────────────────────
BG = "#C9CDD4"
FRAME = "#1F3B57"
ACCENT = "#2E5A8C"
RED = "#C62828"
PANEL = "#D9DDE2"
INSIDE = "#E8EBEE"
BREAKER = "#F2F4F6"


def svg(body: str, background: str = "#FFFFFF", size: int = SIZE) -> str:
    bg = f'<rect width="{size}" height="{size}" fill="{background}"/>'
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
        f'viewBox="0 0 {size} {size}">\n{bg}\n{body}\n</svg>\n'
    )


# ══════════════════════════════════════════════════════════════════════
#  СТИЛЬ A — чёрно-белая иконка
# ══════════════════════════════════════════════════════════════════════

INK = "#111827"
GRID = "#CDD1D6"
LW = 12  # толщина основной линии


def grid_lines() -> str:
    lines = []
    for x in (120, 184, 248, 312, 376):
        lines.append(f'<line x1="{x}" y1="96" x2="{x}" y2="416" '
                     f'stroke="{GRID}" stroke-width="2"/>')
    for y in (96, 160, 224, 288, 352, 416):
        lines.append(f'<line x1="120" y1="{y}" x2="392" y2="{y}" '
                     f'stroke="{GRID}" stroke-width="2"/>')
    return "\n  ".join(lines)


def bulb(cx: float, cy: float, s: float) -> str:
    """Лампочка: колба-окружность, нить, шейка, цоколь с резьбой."""
    r = 40 * s
    return f"""
  <g fill="none" stroke="{INK}" stroke-width="{LW}" stroke-linecap="round" stroke-linejoin="round">
    <circle cx="{cx}" cy="{cy - 16*s}" r="{r}"/>
    <path d="M{cx - 13*s} {cy} C{cx - 8*s} {cy + 10*s} {cx + 8*s} {cy + 10*s} {cx + 13*s} {cy}"/>
    <path d="M{cx - 15*s} {cy + 16*s} H{cx + 15*s}"/>
    <path d="M{cx - 10*s} {cy + 16*s} H{cx + 10*s}" stroke-width="8"/>
    <path d="M{cx - 15*s} {cy + 28*s} H{cx + 15*s}"/>
    <path d="M{cx - 18*s} {cy + 28*s} V{cy + 46*s}"/>
    <path d="M{cx + 18*s} {cy + 28*s} V{cy + 46*s}"/>
    <path d="M{cx} {cy - 48*s} L{cx} {cy - 30*s}"/>
  </g>"""


def bulb_rays(cx: float, cy: float, s: float) -> str:
    rays = []
    for dx, dy in [(0, -1), (-0.7, -0.7), (0.7, -0.7), (-1, 0), (1, 0)]:
        x1 = cx + dx * 56 * s
        y1 = cy - 16 * s + dy * 56 * s
        x2 = cx + dx * 70 * s
        y2 = cy - 16 * s + dy * 70 * s
        rays.append(f'<line x1="{x1:.0f}" y1="{y1:.0f}" x2="{x2:.0f}" y2="{y2:.0f}"/>')
    return "".join(f'\n    {r}' for r in rays)


def bolt(cx: float, cy: float, s: float) -> str:
    return f"""
  <path d="M{cx + 6*s} {cy - 44*s} L{cx - 22*s} {cy + 2*s} H{cx - 2*s} L{cx - 10*s} {cy + 44*s} L{cx + 18*s} {cy - 2*s} H{cx - 2*s} Z"
        fill="{INK}" stroke="none"/>"""


def plug(cx: float, cy: float, s: float) -> str:
    """Вилка: два зубца, корпус-трапеция, кабель вниз."""
    return f"""
  <g fill="none" stroke="{INK}" stroke-width="{LW}" stroke-linecap="round" stroke-linejoin="round">
    <path d="M{cx - 20*s} {cy - 6*s} V{cy - 44*s}"/>
    <path d="M{cx + 20*s} {cy - 6*s} V{cy - 44*s}"/>
    <path d="M{cx - 28*s} {cy - 6*s} H{cx + 28*s} V{cy + 22*s}"/>
    <path d="M{cx - 28*s} {cy + 22*s} C{cx - 16*s} {cy + 40*s} {cx + 16*s} {cy + 40*s} {cx + 28*s} {cy + 22*s}"/>
    <path d="M{cx} {cy + 38*s} V{cy + 76*s}"/>
  </g>"""


def frame(ink: str = INK, lw: int = LW) -> str:
    return (f'<rect x="96" y="96" width="320" height="320" rx="52" '
            f'fill="none" stroke="{ink}" stroke-width="{lw}" stroke-linejoin="round"/>')


# ── A1: лампочка + вилка (исходник, чище) ─────────────────────────────
def a1_bulb_plug() -> str:
    return svg(f"""
  {grid_lines()}
  {frame()}
  {bulb(256, 172, 1.0)}
  <g fill="none" stroke="{INK}" stroke-width="8" stroke-linecap="round">
    {bulb_rays(256, 172, 1.0)}
  </g>
  {bolt(256, 268, 0.8)}
  {plug(256, 356, 1.0)}
""")


# ── A2: лампочка + молния ─────────────────────────────────────────────
def a2_bulb_bolt() -> str:
    return svg(f"""
  {grid_lines()}
  {frame()}
  {bulb(256, 176, 1.0)}
  <g fill="none" stroke="{INK}" stroke-width="8" stroke-linecap="round">
    {bulb_rays(256, 176, 1.0)}
  </g>
  {bolt(256, 300, 1.0)}
""")


# ── A3: вилка + молния ────────────────────────────────────────────────
def a3_plug_bolt() -> str:
    return svg(f"""
  {grid_lines()}
  {frame()}
  {bolt(256, 184, 1.0)}
  {plug(256, 344, 1.0)}
""")


# ── A4: розетка + вилка ───────────────────────────────────────────────
def a4_socket_plug() -> str:
    return svg(f"""
  {grid_lines()}
  {frame()}
  <g fill="none" stroke="{INK}" stroke-width="{LW}" stroke-linecap="round" stroke-linejoin="round">
    <path d="M140 230 H372"/>
    <path d="M196 230 V170"/>
    <path d="M316 230 V170"/>
    <circle cx="196" cy="170" r="24"/>
    <circle cx="316" cy="170" r="24"/>
  </g>
  {plug(256, 344, 0.9)}
""")


# ══════════════════════════════════════════════════════════════════════
#  СТИЛЬ B — цветной щит
# ══════════════════════════════════════════════════════════════════════

def b_shell(x: float, y: float, w: float, h: float, rx: float = 24) -> str:
    return f"""
  <rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{PANEL}"
        stroke="{FRAME}" stroke-width="12"/>
  <rect x="{x+20}" y="{y+20}" width="{w-40}" height="{h-40}" rx="{rx-8}"
        fill="{INSIDE}" stroke="{FRAME}" stroke-width="7"/>
"""


def b_breakers(cx: float, cy: float, n: int = 4, s: float = 1.0) -> str:
    slot = 48 * s
    total = n * slot
    x0 = cx - total / 2
    out = []
    for i in range(n):
        x = x0 + i * slot
        on = i % 2 == 0
        out.append(f'<rect x="{x}" y="{cy-38*s}" width="{slot-8*s}" '
                   f'height="{76*s}" rx="{7*s}" fill="{BREAKER}" '
                   f'stroke="{ACCENT}" stroke-width="6"/>')
        ry = cy - 20 * s if on else cy + 2 * s
        out.append(f'<rect x="{x+12*s}" y="{ry}" width="{slot-32*s}" '
                   f'height="{16*s}" rx="{5*s}" fill="{ACCENT}"/>')
        if i == 1:
            out.append(f'<rect x="{x+16*s}" y="{cy-4*s}" width="{slot-40*s}" '
                       f'height="{10*s}" fill="{RED}"/>')
    return "\n".join(out)


def b_knob(x: float, y: float, r: float = 9) -> str:
    return (f'<circle cx="{x}" cy="{y}" r="{r}" fill="{ACCENT}" '
            f'stroke="{FRAME}" stroke-width="4"/>')


def b_cables(cx: float, y_top: float, y_bot: float, n: int = 4, s: float = 1.0) -> str:
    gap = 26 * s
    total = n * gap
    x0 = cx - total / 2
    out = []
    for i in range(n):
        x = x0 + i * gap
        out.append(f'<path d="M{x} {y_top} V{y_bot}" stroke="{ACCENT}" '
                   f'stroke-width="8" stroke-linecap="round"/>')
    out.append(f'<path d="M{x0-26*s} {y_bot} H{x0+total+26*s}" '
               f'stroke="{FRAME}" stroke-width="10" stroke-linecap="round"/>')
    return "\n".join(out)


def b1_shchit() -> str:
    return svg(f"""
  {b_shell(96, 96, 320, 320)}
  <g fill="none" stroke="{FRAME}" stroke-width="7">
    <path d="M118 196 H394"/>
  </g>
  {b_breakers(256, 252, 4, 1.0)}
  {b_knob(256, 158)}
  {b_cables(256, 416, 452, 4, 1.0)}
""", background=BG)


def b2_shchit_open() -> str:
    return svg(f"""
  <g fill="none" stroke="{FRAME}" stroke-width="10" stroke-linejoin="round">
    <path d="M96 150 L64 130 V382 L96 362 Z" fill="{PANEL}"/>
    <rect x="110" y="120" width="300" height="272" rx="18" fill="{PANEL}"/>
    <rect x="132" y="142" width="256" height="228" rx="12" fill="{INSIDE}"/>
  </g>
  <g fill="none" stroke="{FRAME}" stroke-width="7">
    <path d="M140 200 H380"/>
  </g>
  {b_breakers(256, 260, 4, 1.0)}
  {b_knob(256, 172)}
  {b_cables(256, 392, 452, 4, 1.0)}
""", background=BG)


def b3_shchit_bolt() -> str:
    return svg(f"""
  {b_shell(96, 96, 320, 320)}
  <g fill="none" stroke="{FRAME}" stroke-width="7">
    <path d="M118 196 H394"/>
  </g>
  {b_breakers(256, 252, 4, 1.0)}
  {b_knob(256, 158)}
  <path d="M300 96 L272 172 H292 L282 244 L328 180 H306 L316 96 Z"
        fill="{RED}" stroke="none"/>
""", background=BG)


def b4_shchit_simple() -> str:
    return svg(f"""
  <rect x="120" y="96" width="272" height="320" rx="24" fill="{PANEL}"
        stroke="{FRAME}" stroke-width="12"/>
  <rect x="150" y="130" width="212" height="180" rx="12" fill="{INSIDE}"
        stroke="{ACCENT}" stroke-width="8"/>
  <rect x="180" y="162" width="152" height="54" rx="8" fill="{BREAKER}"
        stroke="{ACCENT}" stroke-width="7"/>
  <rect x="204" y="178" width="104" height="18" rx="6" fill="{ACCENT}"/>
  <rect x="210" y="200" width="60" height="10" fill="{RED}"/>
  <rect x="180" y="230" width="152" height="54" rx="8" fill="{BREAKER}"
        stroke="{ACCENT}" stroke-width="7"/>
  <rect x="204" y="246" width="104" height="18" rx="6" fill="{ACCENT}"/>
  {b_cables(256, 416, 452, 4, 1.0)}
""", background=BG)


VARIANTS = [
    ("a1-lamp-plug", "A1 · Лампочка + вилка", a1_bulb_plug),
    ("a2-lamp-bolt", "A2 · Лампочка + молния", a2_bulb_bolt),
    ("a3-plug-bolt", "A3 · Вилка + молния", a3_plug_bolt),
    ("a4-socket-plug", "A4 · Розетка + вилка", a4_socket_plug),
    ("b1-shchit", "B1 · Щит", b1_shchit),
    ("b2-shchit-open", "B2 · Щит открыт", b2_shchit_open),
    ("b3-shchit-bolt", "B3 · Щит + молния", b3_shchit_bolt),
    ("b4-shchit-simple", "B4 · Щит простой (48px)", b4_shchit_simple),
]


def render(text: str, target: pathlib.Path, width: int = SIZE) -> None:
    svg_path = target.with_suffix(".svg")
    svg_path.write_text(text, encoding="utf-8")
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
    OUT_SVG.mkdir(parents=True, exist_ok=True)
    OUT_PNG.mkdir(parents=True, exist_ok=True)
    for slug, title, builder in VARIANTS:
        render(builder(), OUT_PNG / f"{slug}.png")
        (OUT_SVG / f"{slug}.svg").write_text(builder(), encoding="utf-8")
        print(f"{slug}: {title}")
    print(f"\nPNG: {OUT_PNG}")


if __name__ == "__main__":
    main()
