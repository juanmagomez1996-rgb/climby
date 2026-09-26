#!/usr/bin/env python3
"""Registra trabajos en jobs.tsv desde líneas 'nombre timestamp job_id [ext]' (stdin) y los descarga."""
import sys, pathlib, subprocess
D = pathlib.Path(__file__).resolve().parent
B = 'https://d8j0ntlcm91z4.cloudfront.net/user_36rhpN6isZPTRCy9pGYyP1nW9ev'
have = (D / 'jobs.tsv').read_text()
with open(D / 'jobs.tsv', 'a') as f:
    for line in sys.stdin:
        p = line.split()
        if len(p) < 3: continue
        name, ts, job = p[:3]; ext = p[3] if len(p) > 3 else 'png'
        if job not in have: f.write(f'{name}\t{job}\t{B}/hf_20260926_{ts}_{job}.{ext}\n')
subprocess.run([sys.executable, str(D / 'pull.py')])
