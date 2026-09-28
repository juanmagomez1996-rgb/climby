"""Genera lib/asset_data.dart: tamaño de cada imagen y lista de imágenes de cada canal.

Así el juego solo abre (y tiene en memoria) las imágenes del canal que se está viendo.
Ejecutar después de añadir imágenes o canales:  python3 tool/gen_assets.py
"""
import glob, os, re
from PIL import Image

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
imgs = {}
for f in sorted(glob.glob(os.path.join(root, 'assets/images/*.webp'))):
    n = os.path.basename(f)[:-5]
    imgs[n] = Image.open(f).size
names = set(imgs)

def refs(code):
    out = set()
    for lit in re.findall(r"'([A-Za-z0-9_]+)'", code):
        if lit in names: out.add(lit)
        if 'anim_' + lit in names: out.add('anim_' + lit)
    # nombres construidos: 'spec${i + 1}', 'singer_$col' → todos los que empiezan así
    for pre in [q for q in re.findall(r"'([A-Za-z0-9_]+)\$", code) if q != 'anim_']:
        out |= {n for n in names if n.startswith(pre)}
    return out

channels = {}
for f in ['lib/channels.dart', 'lib/channels2.dart', 'lib/channels3.dart']:
    code = open(os.path.join(root, f)).read()
    parts = re.split(r"\n(?=class \w+ extends Channel \{)", code)
    for part in parts[1:]:
        m = re.search(r"String get name => '([^']+)'", part)
        if not m: continue
        # el bloque llega hasta la siguiente clase que no sea auxiliar del mismo canal
        body = re.split(r"\n// ─{5,}", part)[0]
        channels[m.group(1)] = sorted(refs(body))

core = set()
core |= refs(open(os.path.join(root, 'lib/game.dart')).read())
gfx = open(os.path.join(root, 'lib/gfx.dart')).read()
core |= refs(gfx[gfx.index('class Gfx'):])  # sin la lista completa de sprites de arriba
core |= {'finger', 'arrow', 'splat', 'anim_host_head', 'host_body', 'bg_screw', 'btn_gold', 'btn_teal', 'btn_pink'}

with open(os.path.join(root, 'lib/asset_data.dart'), 'w') as o:
    o.write('// Generado por tool/gen_assets.py. No editar a mano.\n\n')
    o.write('/// Ancho y alto de cada imagen (para maquetar sin tenerla cargada).\n')
    o.write('const kImageSize = <String, (int, int)>{\n')
    for n, (w, h) in imgs.items():
        o.write(f"  '{n}': ({w}, {h}),\n")
    o.write('};\n\n/// Imágenes que siempre están cargadas (interfaz, tele, menú).\n')
    o.write('const kCoreImages = <String>{\n' + ''.join(f"  '{n}',\n" for n in sorted(core)) + '};\n\n')
    o.write('/// Imágenes de cada canal (por su nombre visible).\n')
    o.write('const kChannelImages = <String, List<String>>{\n')
    for k, v in channels.items():
        o.write(f"  '{k}': [{', '.join(repr(x) for x in v)}],\n")
    o.write('};\n')
print(len(imgs), 'imágenes;', len(channels), 'canales; núcleo', len(core))
