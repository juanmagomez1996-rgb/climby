#!/usr/bin/env python3
"""Reúne assets/chars/*.json en web/meta.js (window.CHAR_META)."""
import json, glob, pathlib
ROOT = pathlib.Path(__file__).resolve().parent.parent
m = {pathlib.Path(f).stem: json.load(open(f)) for f in sorted(glob.glob(str(ROOT / 'assets/chars/*.json')))}
(ROOT / 'web' / 'meta.js').write_text('window.CHAR_META = ' + json.dumps(m) + ';\n')
print(list(m))
