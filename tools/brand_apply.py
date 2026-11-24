"""Applica il marchio definito in branding/brand.json a tutto il progetto.

Genera:
  branding/out/            logo (SVG chiaro e scuro), simbolo, icona PNG 1024, .ico
  app/lib/brand.g.dart     costanti usate dall'app (nome, versione, colori, cartella dati...)
  icone Windows, Android (mipmap) e iOS (AppIcon.appiconset)
  installer/<Nome>.iss, docs/GUIDA_UTENTE.md (dai modelli in branding/templates)
e aggiorna nome dell'eseguibile, titolo della finestra, informazioni di versione,
identificativi Android/iOS e versione in pubspec.

Uso: python -I tools/brand_apply.py
Disegno del simbolo: anello (manopola) attraversato da una forma d'onda; tutto originale.
"""
import json
import os
import re
import struct
import zlib

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
B = json.load(open(os.path.join(ROOT, 'branding', 'brand.json'), encoding='utf-8'))
OUT = os.path.join(ROOT, 'branding', 'out')
APP = os.path.join(ROOT, 'app')
os.makedirs(OUT, exist_ok=True)


def hexrgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


# ------------------------------------------------------------------ geometria (griglia 64)

WAVE = [((10, 32), (17, 32), (18, 20), (24, 20)), ((24, 20), (30, 20), (30, 44), (36, 44)),
        ((36, 44), (42, 44), (42, 26), (47, 26)), ((47, 26), (51, 26), (51, 32), (54, 32))]
WAVE_SVG = 'M10 32 C 17 32 18 20 24 20 S 30 44 36 44 S 42 26 47 26 S 51 32 54 32'


def bezier_points(seg, n=60):
    p0, p1, p2, p3 = [np.array(p, float) for p in seg]
    t = np.linspace(0, 1, n)[:, None]
    return (1 - t) ** 3 * p0 + 3 * (1 - t) ** 2 * t * p1 + 3 * (1 - t) * t ** 2 * p2 + t ** 3 * p3


WAVE_PTS = np.vstack([bezier_points(s) for s in WAVE])


def render_icon(size, rounded=True, bg=None, ring=None, wave=None, pad=4.0):
    """Disegna il simbolo con anti-aliasing (supercampionamento 4x) e restituisce RGBA uint8."""
    c = B['colors']
    bg = hexrgb(bg or c['surface'])
    ring = hexrgb(ring or c['foreground'])
    wave = hexrgb(wave or c['signal'])
    ss = 4
    n = size * ss
    scale = n / 64.0
    ys, xs = np.mgrid[0:n, 0:n]
    x = (xs + 0.5) / scale
    y = (ys + 0.5) / scale
    img = np.zeros((n, n, 4), float)
    # fondo: quadrato arrotondato (raggio 13 come nelle anteprime)
    lo, hi, r = pad, 64 - pad, 13.0
    qx = np.clip(x, lo + r, hi - r)
    qy = np.clip(y, lo + r, hi - r)
    inside = ((x - qx) ** 2 + (y - qy) ** 2 <= r * r) & (x >= lo) & (x <= hi) & (y >= lo) & (y <= hi)
    if not rounded:
        inside = np.ones_like(inside)
    img[inside] = (*bg, 255)
    # anello
    d = np.abs(np.hypot(x - 32, y - 32) - 18)
    m = d <= 1.75
    img[m] = (*ring, 255)
    # forma d'onda: ogni segmento aggiorna solo i pixel del proprio riquadro (veloce anche a 1024 px)
    hw = 1.75
    for a, b in zip(WAVE_PTS[:-1], WAVE_PTS[1:]):
        ab = b - a
        L2 = float(ab @ ab)
        if L2 == 0:
            continue
        x0 = max(int((min(a[0], b[0]) - hw - 1) * scale), 0)
        x1 = min(int((max(a[0], b[0]) + hw + 1) * scale) + 1, n)
        y0 = max(int((min(a[1], b[1]) - hw - 1) * scale), 0)
        y1 = min(int((max(a[1], b[1]) + hw + 1) * scale) + 1, n)
        sx = x[y0:y1, x0:x1]
        sy = y[y0:y1, x0:x1]
        t = np.clip(((sx - a[0]) * ab[0] + (sy - a[1]) * ab[1]) / L2, 0, 1)
        d2 = np.hypot(sx - (a[0] + t * ab[0]), sy - (a[1] + t * ab[1]))
        img[y0:y1, x0:x1][d2 <= hw] = (*wave, 255)
    # riduzione con media (anti-aliasing)
    img = img.reshape(size, ss, size, ss, 4).mean(axis=(1, 3))
    return np.clip(img, 0, 255).astype(np.uint8)


def png_bytes(rgba):
    h, w, _ = rgba.shape
    raw = b''.join(b'\x00' + rgba[i].tobytes() for i in range(h))

    def chunk(t, d):
        return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)

    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')


def write(path, data, mode='w'):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if mode == 'wb':
        open(path, 'wb').write(data)
    else:
        open(path, 'w', encoding='utf-8', newline='\n').write(data)


def ico(sizes):
    imgs = [png_bytes(render_icon(s)) for s in sizes]
    out = struct.pack('<HHH', 0, 1, len(sizes))
    off = 6 + 16 * len(sizes)
    for s, d in zip(sizes, imgs):
        out += struct.pack('<BBBBHHII', s % 256, s % 256, 0, 0, 1, 32, len(d), off)
        off += len(d)
    return out + b''.join(imgs)


def svg_mark(fg, wave, bg=None):
    back = f'<rect x="4" y="4" width="56" height="56" rx="13" fill="{bg}"/>' if bg else ''
    return (f'{back}<circle cx="32" cy="32" r="18" fill="none" stroke="{fg}" stroke-width="3.5"/>'
            f'<path d="{WAVE_SVG}" fill="none" stroke="{wave}" stroke-width="3.5" stroke-linecap="round"/>')


def svg_logo(dark):
    c = B['colors']
    bg = c['background'] if dark else c['backgroundLight']
    fg = c['foreground'] if dark else c['foregroundLight']
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="560" height="160" viewBox="0 0 560 160">'
            f'<rect width="560" height="160" rx="16" fill="{bg}"/>'
            f'<g transform="translate(24 16) scale(2)">{svg_mark(fg, c["signal"])}</g>'
            f'<text x="172" y="98" font-family="Segoe UI, Inter, Helvetica, Arial, sans-serif" font-size="64" font-weight="600" '
            f'letter-spacing="1" fill="{fg}">{B["name"]}</text>'
            f'<text x="176" y="128" font-family="Segoe UI, Inter, Helvetica, Arial, sans-serif" font-size="17" fill="{fg}" fill-opacity="0.6">'
            f'{B["tagline"]}</text></svg>\n')


def sub(path, pattern, repl, count=1):
    s = open(path, encoding='utf-8', errors='surrogateescape').read()
    n = re.subn(pattern, repl, s, count=count, flags=re.M)
    if n[1] == 0:
        raise SystemExit(f'modello non trovato in {path}: {pattern}')
    open(path, 'w', encoding='utf-8', errors='surrogateescape', newline='').write(n[0])


def fill(template):
    t = open(os.path.join(ROOT, 'branding', 'templates', template), encoding='utf-8').read()
    for k, v in B.items():
        if isinstance(v, (str, int)):
            t = t.replace('{{' + k + '}}', str(v))
    return t


def main():
    c = B['colors']
    name, exe, ver, build = B['name'], B['exeName'], B['version'], B['build']

    # --- grafica
    write(os.path.join(OUT, 'simbolo.svg'), f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">{svg_mark(c["foreground"], c["signal"], c["surface"])}</svg>\n')
    write(os.path.join(OUT, 'logo_scuro.svg'), svg_logo(True))
    write(os.path.join(OUT, 'logo_chiaro.svg'), svg_logo(False))
    for s in (1024, 512, 256):
        write(os.path.join(OUT, f'icona_{s}.png'), png_bytes(render_icon(s)), 'wb')
    write(os.path.join(OUT, f'icona_chiara_512.png'), png_bytes(render_icon(512, bg=c['backgroundLight'], ring=c['foregroundLight'])), 'wb')
    ic = ico([16, 20, 24, 32, 40, 48, 64, 128, 256])
    write(os.path.join(OUT, f'{exe}.ico'), ic, 'wb')
    write(os.path.join(APP, 'windows', 'runner', 'resources', 'app_icon.ico'), ic, 'wb')
    # Android: icona a tutta pagina (il sistema applica la sua maschera)
    for folder, s in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
        write(os.path.join(APP, 'android', 'app', 'src', 'main', 'res', f'mipmap-{folder}', 'ic_launcher.png'), png_bytes(render_icon(s)), 'wb')
    # iOS/iPadOS: icone quadrate senza trasparenza (il sistema arrotonda gli angoli)
    iconset = os.path.join(APP, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    contents = json.load(open(os.path.join(iconset, 'Contents.json'), encoding='utf-8'))
    for im in contents['images']:
        if 'filename' in im:
            px = round(float(im['size'].split('x')[0]) * int(im['scale'].rstrip('x')))
            rgba = render_icon(px, rounded=False, pad=0)
            write(os.path.join(iconset, im['filename']), png_bytes(rgba), 'wb')
    # icona dell'app usata nella schermata iniziale e nelle informazioni
    write(os.path.join(APP, 'assets', 'brand', 'icona_256.png'), png_bytes(render_icon(256)), 'wb')

    # --- costanti Dart
    def dcolor(h):
        return '0xFF' + h.lstrip('#').upper()

    write(os.path.join(APP, 'lib', 'brand.g.dart'), f"""// GENERATO da tools/brand_apply.py a partire da branding/brand.json: non modificare a mano.
import 'dart:ui';

abstract final class Brand {{
  static const name = '{name}';
  static const exeName = '{exe}';
  static const tagline = '{B['tagline']}';
  static const publisher = '{B['publisher']}';
  static const copyright = '{B['copyright']}';
  static const website = '{B['website']}';
  static const version = '{ver}';
  static const build = {build};
  static const appDataFolder = '{B['appDataFolder']}';
  static const packageId = '{B['packageId']}';
  static const compatibility = '{B['compatibility'].replace("'", "\\'")}';
  static const background = Color({dcolor(c['background'])});
  static const surface = Color({dcolor(c['surface'])});
  static const foreground = Color({dcolor(c['foreground'])});
  static const signal = Color({dcolor(c['signal'])});
  static const accent = Color({dcolor(c['accent'])});
}}
""")

    # --- Windows: eseguibile, finestra, informazioni di versione
    sub(os.path.join(APP, 'windows', 'CMakeLists.txt'), r'^set\(BINARY_NAME ".*"\)', f'set(BINARY_NAME "{exe}")')
    sub(os.path.join(APP, 'windows', 'runner', 'main.cpp'), r'window\.Create\(L"[^"]*"', f'window.Create(L"{name}"')
    rc = os.path.join(APP, 'windows', 'runner', 'Runner.rc')
    for key, val in {'CompanyName': B['publisher'], 'FileDescription': f'{name} - {B["tagline"]}', 'InternalName': exe,
                     'LegalCopyright': B['copyright'].replace('©', '(C)'), 'OriginalFilename': f'{exe}.exe', 'ProductName': name}.items():
        sub(rc, rf'VALUE "{key}", "[^"]*"', f'VALUE "{key}", "{val}"')
    # --- versione
    sub(os.path.join(APP, 'pubspec.yaml'), r'^version: .*$', f'version: {ver}+{build}')
    # --- Android e iOS
    sub(os.path.join(APP, 'android', 'app', 'build.gradle.kts'), r'applicationId = "[^"]*"', f'applicationId = "{B["packageId"]}"')
    sub(os.path.join(APP, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'), r'android:label="[^"]*"', f'android:label="{name}"')
    plist = os.path.join(APP, 'ios', 'Runner', 'Info.plist')
    sub(plist, r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)', rf'\g<1>{name}\g<2>')
    sub(plist, r'(<key>CFBundleName</key>\s*<string>)[^<]*(</string>)', rf'\g<1>{name}\g<2>')
    sub(os.path.join(APP, 'ios', 'Runner.xcodeproj', 'project.pbxproj'), r'PRODUCT_BUNDLE_IDENTIFIER = it\.x32remote\.x32Remote;|PRODUCT_BUNDLE_IDENTIFIER = ' + re.escape(B['packageId']) + ';',
        f'PRODUCT_BUNDLE_IDENTIFIER = {B["packageId"]};', count=0)

    # --- installer e documentazione dai modelli
    # Inno Setup legge correttamente gli accenti (messaggi in francese, tedesco…) solo con la BOM UTF-8
    write(os.path.join(ROOT, 'installer', f'{exe}.iss'), fill('installer.iss').encode('utf-8-sig'), 'wb')
    write(os.path.join(ROOT, 'docs', 'GUIDA_UTENTE.md'), fill('GUIDA_UTENTE.md'))
    print(f'marchio applicato: {name} {ver}+{build}')


if __name__ == '__main__':
    main()
