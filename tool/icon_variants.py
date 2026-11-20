#!/usr/bin/env python3
"""Превью вариантов иконки: три штуки рядом на тёмном и светлом фоне."""
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import icon_art  # noqa: E402

OUT = pathlib.Path('store/icon-variants')
OUT.mkdir(parents=True, exist_ok=True)

bold = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 34)
small = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 24)

icons = {}
for key in icon_art.VARIANTS:
    icon = icon_art.make_icon(key)
    icon.save(OUT / f'{key}.png')
    icons[key] = icon.resize((360, 360), Image.LANCZOS)

W = 3 * 400 + 80
H = 640
sheet = Image.new('RGB', (W, H), (16, 20, 26))
d = ImageDraw.Draw(sheet)
for i, (key, (title, _)) in enumerate(icon_art.VARIANTS.items()):
    x = 40 + i * 400
    sheet.paste(icons[key], (x, 90), icons[key])
    tw = d.textlength(title, font=bold)
    d.text((x + (360 - tw) / 2, 470), title, fill=(235, 242, 250), font=bold)
    tw = d.textlength(key, font=small)
    d.text((x + (360 - tw) / 2, 515), key, fill=(120, 134, 150), font=small)

# как выглядит в реальном размере 48 px
tiny = Image.new('RGB', (W, 120), (16, 20, 26))
td = ImageDraw.Draw(tiny)
for i, key in enumerate(icon_art.VARIANTS):
    x = 40 + i * 400
    t48 = icons[key].resize((48, 48), Image.LANCZOS)
    t96 = icons[key].resize((96, 96), Image.LANCZOS)
    tiny.paste(t48, (x + 40, 36), t48)
    tiny.paste(t96, (x + 150, 12), t96)
canvas_with_tiny = Image.new('RGB', (W, H + 200 + 120), (16, 20, 26))
canvas_with_tiny.paste(sheet, (0, 0))
canvas_with_tiny.paste(tiny, (0, H))

# как смотрится на светлом фоне
light = Image.new('RGB', (W, 200), (242, 244, 247))
ld = ImageDraw.Draw(light)
for i, key in enumerate(icon_art.VARIANTS):
    x = 40 + i * 400
    small_icon = icons[key].resize((150, 150), Image.LANCZOS)
    light.paste(small_icon, (x + 105, 25), small_icon)
canvas_with_tiny.paste(light, (0, H + 120))
canvas_with_tiny.save(OUT / 'preview.png', optimize=True)
print('варианты:', ', '.join(icon_art.VARIANTS))
print('превью:', OUT / 'preview.png', canvas_with_tiny.size)
