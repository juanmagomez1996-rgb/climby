#!/usr/bin/env python3
"""Descarga originales de Higgsfield a vida/raw/<nombre>.png.
Uso: fetch.py nombre=URL [nombre=URL ...]"""
import sys, urllib.request, pathlib
RAW = pathlib.Path(__file__).resolve().parent.parent / 'raw'
RAW.mkdir(exist_ok=True)
for arg in sys.argv[1:]:
    name, url = arg.split('=', 1)
    out = RAW / (name + '.png')
    urllib.request.urlretrieve(url, out)
    print(out, out.stat().st_size)
