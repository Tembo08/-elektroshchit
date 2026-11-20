#!/usr/bin/env python3
"""Рисуем варианты иконки: рубильник, тумблер, автомат.

Координаты заданы в пространстве 1024×1024 и масштабируются.
"""
from __future__ import annotations

from PIL import Image, ImageDraw, ImageFilter

BG = (11, 15, 20, 255)
PLATE = (23, 30, 40, 255)
NEON = (53, 230, 255, 255)
NEON_SOFT = (53, 230, 255, 110)
METAL = (206, 219, 232, 255)
METAL_DARK = (150, 165, 182, 255)
HOT = (255, 176, 32, 255)      # рукоятка под напряжением
HOT_DARK = (214, 132, 12, 255)
SIZE = 1024


def _rr(draw, box, radius, fill=None, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline,
                           width=width)


def _with_glow(paint, blur: int = 30) -> Image.Image:
    """Слой рисунка + размытая копия под ним — неоновое свечение."""
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    paint(layer)
    glow = layer.filter(ImageFilter.GaussianBlur(blur))
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.alpha_composite(glow)
    out.alpha_composite(layer)
    return out


# ───────────────────────── 1. рубильник ─────────────────────────
def draw_knife(canvas: Image.Image, s: float = 1.0, glow: bool = True) -> None:
    """Рубильник: две стойки, толстый нож с шарниром, рукоятка.

    Крупные формы и толстые линии — чтобы силуэт читался в 48 px.
    Нож поднят: зазор до правого контакта показывает «выключено».
    """
    def paint(img: Image.Image) -> None:
        d = ImageDraw.Draw(img)
        k = lambda v: int(v * s)  # noqa: E731

        # стойки контактов — крупные, почти во всю высоту
        _rr(d, (k(214), k(520), k(366), k(872)), k(34), fill=METAL)
        _rr(d, (k(658), k(520), k(810), k(872)), k(34), fill=METAL_DARK)

        # нож: от шарнира вверх-вправо, с явным зазором до правой стойки
        d.line([(k(290), k(560)), (k(676), k(352))], fill=NEON, width=k(86))
        # шарнир
        d.ellipse((k(226), k(496), k(354), k(624)), fill=NEON)
        d.ellipse((k(262), k(532), k(318), k(588)), fill=PLATE)

        # рукоятка
        d.line([(k(676), k(352)), (k(742), k(318))], fill=HOT, width=k(92))
        d.ellipse((k(694), k(272), k(806), k(384)), fill=HOT)
        d.ellipse((k(724), k(302), k(776), k(354)), fill=HOT_DARK)

    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    paint(layer)
    if glow:
        canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(30)))
    canvas.alpha_composite(layer)


# ───────────────────────── 2. тумблер ─────────────────────────
def draw_lever(canvas: Image.Image, s: float = 1.0, glow: bool = True) -> None:
    """Промышленный переключатель: корпус и рычаг с шариком."""
    def paint(img: Image.Image) -> None:
        d = ImageDraw.Draw(img)
        k = lambda v: int(v * s)  # noqa: E731

        # корпус
        _rr(d, (k(300), k(470), k(724), k(900)), k(70), fill=PLATE,
            outline=NEON, width=k(26))
        # основание рычага
        d.ellipse((k(452), k(566), k(572), k(666)), fill=METAL)
        # рычаг вверх-вправо
        d.line([(k(512), k(616)), (k(660), k(318))], fill=METAL, width=k(54))
        # шарик
        d.ellipse((k(604), k(258), k(716), k(370)), fill=HOT)
        d.ellipse((k(628), k(282), k(692), k(346)), fill=HOT_DARK)
        # клеммы снизу — намёк на подключение
        _rr(d, (k(336), k(838), k(404), k(890)), k(10), fill=METAL_DARK)
        _rr(d, (k(620), k(838), k(688), k(890)), k(10), fill=METAL_DARK)
        # дуга хода
        d.arc((k(360), k(300), k(700), k(700)), start=250, end=310,
              fill=NEON_SOFT, width=k(12))

    canvas.alpha_composite(_with_glow(paint) if glow else Image.new(
        "RGBA", (SIZE, SIZE), (0, 0, 0, 0)))
    if not glow:
        paint(canvas)


# ───────────────────────── 3. автомат ─────────────────────────
def draw_breaker(canvas: Image.Image, s: float = 1.0,
                 glow: bool = True) -> None:
    """Модульный автомат на DIN-рейке, рычаг поднят."""
    def paint(img: Image.Image) -> None:
        d = ImageDraw.Draw(img)
        k = lambda v: int(v * s)  # noqa: E731

        # DIN-рейка — тонкая, только намёк
        _rr(d, (k(150), k(800), k(874), k(846)), k(10), fill=PLATE)

        # корпус
        _rr(d, (k(352), k(220), k(672), k(806)), k(48), fill=PLATE,
            outline=NEON_SOFT, width=k(14))
        # окно индикатора
        _rr(d, (k(420), k(300), k(604), k(392)), k(16), fill=(9, 12, 16, 255))
        # рычаг: тело + оранжевая «шапка» как часть рычага
        _rr(d, (k(456), k(440), k(568), k(700)), k(30), fill=METAL)
        _rr(d, (k(456), k(440), k(568), k(516)), k(24), fill=HOT)
        # клеммы сверху и снизу
        _rr(d, (k(398), k(206), k(462), k(244)), k(8), fill=METAL_DARK)
        _rr(d, (k(562), k(206), k(626), k(244)), k(8), fill=METAL_DARK)
        _rr(d, (k(398), k(786), k(462), k(824)), k(8), fill=METAL_DARK)
        _rr(d, (k(562), k(786), k(626), k(824)), k(8), fill=METAL_DARK)

    canvas.alpha_composite(_with_glow(paint) if glow else Image.new(
        "RGBA", (SIZE, SIZE), (0, 0, 0, 0)))
    if not glow:
        paint(canvas)


VARIANTS = {
    'knife': ('Рубильник', draw_knife),
    'lever': ('Тумблер', draw_lever),
    'breaker': ('Автомат', draw_breaker),
}


def make_canvas() -> Image.Image:
    """Тёмный скруглённый квадрат — фон иконки."""
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    bg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    _rr(ImageDraw.Draw(bg), (0, 0, SIZE - 1, SIZE - 1), 220, fill=BG)
    canvas.alpha_composite(bg)
    return canvas


def make_icon(name: str) -> Image.Image:
    canvas = make_canvas()
    VARIANTS[name][1](canvas)
    return canvas
