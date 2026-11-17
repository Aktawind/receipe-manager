"""Génère l'icône « toque de chef » (adaptative + ancienne forme) pour main et dev.

Usage : python3 tools/make_icons.py android/app/src <aperçu.png>  (Pillow requis)
"""
import sys
from PIL import Image, ImageDraw

ROOT = sys.argv[1]
OUT_PREVIEW = sys.argv[2]
DENS = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
S = 16  # sur-échantillonnage

def rgba(h, a=255):
    h = h.lstrip('#'); return tuple(int(h[i:i+2], 16) for i in (0, 2, 4)) + (a,)

def toque(size, hat, band, line=None):
    """Toque sur un canevas 108 x 108 unités (zone sûre : 21..87)."""
    u = size / 108
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    def c(x, y, r): d.ellipse([(x-r)*u, (y-r)*u, (x+r)*u, (y+r)*u], fill=hat)
    # Le haut bouffant : trois boules et un corps.
    c(40.5, 47, 12.5); c(67.5, 47, 12.5); c(54, 40, 15)
    d.rounded_rectangle([34*u, 46*u, 74*u, 66*u], radius=3*u, fill=hat)
    # Le bandeau.
    d.rounded_rectangle([35*u, 68.5*u, 73*u, 78*u], radius=3*u, fill=band)
    if line:  # deux plis
        for x in (47, 61):
            d.rounded_rectangle([(x-1)*u, 52*u, (x+1)*u, 64*u], radius=1*u, fill=line)
    return img

def variant(res, bg, hat, band, line, mono):
    for name, k in DENS.items():
        fg_px = round(108 * k)
        big = toque(fg_px * S, hat, band, line).resize((fg_px, fg_px), Image.LANCZOS)
        big.save(f'{res}/mipmap-{name}/ic_launcher_foreground.png')
        if mono:
            m = toque(fg_px * S, rgba('#FFFFFF'), rgba('#FFFFFF')).resize((fg_px, fg_px), Image.LANCZOS)
            m.save(f'{res}/mipmap-{name}/ic_launcher_monochrome.png')
        # Ancienne forme (API < 26) : 48 dp, carré arrondi, toque au centre.
        px = round(48 * k)
        L = px * S
        legacy = Image.new('RGBA', (L, L), (0, 0, 0, 0))
        ImageDraw.Draw(legacy).rounded_rectangle([L*0.04, L*0.04, L*0.96, L*0.96], radius=L*0.2, fill=bg)
        t = toque(round(L * 108 / 72), hat, band, line)  # 72 dp visibles sur 108
        off = (L - t.width) // 2
        legacy.alpha_composite(t, (off, off))
        legacy.resize((px, px), Image.LANCZOS).save(f'{res}/mipmap-{name}/ic_launcher.png')

TEAL, CREAM, PEACH = rgba('#0E5A62'), rgba('#FAF6F1'), rgba('#F2A285')
LINE = rgba('#E3D9CF')
variant(f'{ROOT}/main/res', TEAL, CREAM, PEACH, LINE, mono=True)
variant(f'{ROOT}/dev/res', PEACH, rgba('#0E5A62'), CREAM, rgba('#1C7880'), mono=False)

# Aperçu : main et dev, ancienne forme et adaptative ronde.
prev = Image.new('RGBA', (4 * 220, 220), (255, 255, 255, 255))
for i, (res, bg) in enumerate([('main', TEAL), ('dev', PEACH)]):
    leg = Image.open(f'{ROOT}/{res}/res/mipmap-xxxhdpi/ic_launcher.png')
    prev.alpha_composite(leg, (i * 440 + 14, 14))
    fg = Image.open(f'{ROOT}/{res}/res/mipmap-xxxhdpi/ic_launcher_foreground.png')
    disc = Image.new('RGBA', fg.size, (0, 0, 0, 0))
    ImageDraw.Draw(disc).ellipse([36, 36, 396, 396], fill=bg)
    disc.alpha_composite(fg)
    prev.alpha_composite(disc.resize((200, 200), Image.LANCZOS), (i * 440 + 230, 10))
prev.save(OUT_PREVIEW)
