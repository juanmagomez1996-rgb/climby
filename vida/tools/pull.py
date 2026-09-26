#!/usr/bin/env python3
"""Descarga a raw/ todo lo de jobs.tsv que falte. Uso: pull.py [prefijo]"""
import sys, urllib.request, pathlib
D = pathlib.Path(__file__).resolve().parent
RAW = D.parent / 'raw'; RAW.mkdir(exist_ok=True)
pre = sys.argv[1] if len(sys.argv) > 1 else ''
for line in (D / 'jobs.tsv').read_text().splitlines():
    if not line.strip(): continue
    name, job, url = line.split('\t')
    ext = url.rsplit('.', 1)[-1]
    out = RAW / f'{name}.{ext}'
    if url and name.startswith(pre) and not out.exists():
        urllib.request.urlretrieve(url, out); print('ok', out.name)
