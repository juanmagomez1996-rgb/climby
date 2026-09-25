"""Reduce el peso de un GLB: reescala texturas y las re-codifica (JPEG si no hay transparencia).

Uso: python3 tools/optimize_glb.py entrada.glb salida.glb [--max 1024] [--strip-textures]
--strip-textures elimina las texturas (útil para GLB que solo aportan animaciones).
"""
import argparse, io, json, struct
from PIL import Image


def read_glb(path):
    d = open(path, 'rb').read()
    assert d[:4] == b'glTF'
    off, js, bin_ = 12, None, b''
    while off < len(d):
        ln, typ = struct.unpack('<II', d[off:off + 8])
        chunk = d[off + 8: off + 8 + ln]
        if typ == 0x4E4F534A: js = json.loads(chunk)
        elif typ == 0x004E4942: bin_ = chunk
        off += 8 + ln
    return js, bin_


def write_glb(path, js, views):
    blob = bytearray()
    for i, data in enumerate(views):
        while len(blob) % 4: blob.append(0)
        js['bufferViews'][i]['byteOffset'] = len(blob)
        js['bufferViews'][i]['byteLength'] = len(data)
        js['bufferViews'][i]['buffer'] = 0
        blob += data
    while len(blob) % 4: blob.append(0)
    js['buffers'] = [{'byteLength': len(blob)}]
    j = json.dumps(js, separators=(',', ':')).encode()
    j += b' ' * ((4 - len(j) % 4) % 4)
    total = 12 + 8 + len(j) + 8 + len(blob)
    with open(path, 'wb') as f:
        f.write(struct.pack('<4sII', b'glTF', 2, total))
        f.write(struct.pack('<II', len(j), 0x4E4F534A)); f.write(j)
        f.write(struct.pack('<II', len(blob), 0x004E4942)); f.write(blob)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('src'); ap.add_argument('dst')
    ap.add_argument('--max', type=int, default=1024)
    ap.add_argument('--strip-textures', action='store_true')
    a = ap.parse_args()
    js, bin_ = read_glb(a.src)
    views = [bin_[v.get('byteOffset', 0): v.get('byteOffset', 0) + v['byteLength']] for v in js['bufferViews']]
    if a.strip_textures:
        for m in js.get('materials', []):
            pbr = m.get('pbrMetallicRoughness', {})
            for k in ('baseColorTexture', 'metallicRoughnessTexture'): pbr.pop(k, None)
            for k in ('normalTexture', 'emissiveTexture', 'occlusionTexture'): m.pop(k, None)
            m.pop('extensions', None)
        dead = {img['bufferView'] for img in js.get('images', []) if 'bufferView' in img}
        js.pop('images', None); js.pop('textures', None); js.pop('samplers', None)
        for i in dead: views[i] = b''
    else:
        for img in js.get('images', []):
            bv = img['bufferView']
            im = Image.open(io.BytesIO(views[bv]))
            im.load()
            if max(im.size) > a.max: im.thumbnail((a.max, a.max), Image.LANCZOS)
            has_alpha = im.mode in ('RGBA', 'LA') and im.getchannel('A').getextrema()[0] < 250
            out = io.BytesIO()
            if has_alpha: im.save(out, 'PNG', optimize=True); img['mimeType'] = 'image/png'
            else: im.convert('RGB').save(out, 'JPEG', quality=84, optimize=True); img['mimeType'] = 'image/jpeg'
            views[bv] = out.getvalue()
    write_glb(a.dst, js, views)
    print(a.dst, sum(len(v) for v in views) // 1024, 'KB')


if __name__ == '__main__':
    main()
