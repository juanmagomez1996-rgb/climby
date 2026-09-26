#!/usr/bin/env python3
"""Añade a jobs.tsv las viñetas: líneas 'indice timestamp jobid' (stdin o fichero)."""
import sys, json, subprocess, pathlib
D = pathlib.Path(__file__).resolve().parent
ids = json.loads(subprocess.run([sys.executable, str(D / 'vignettes.py'), '0', '0', 'x'], capture_output=True, text=True).stdout.splitlines()[-1])
B = 'https://d8j0ntlcm91z4.cloudfront.net/user_36rhpN6isZPTRCy9pGYyP1nW9ev'
have = (D / 'jobs.tsv').read_text()
with open(D / 'jobs.tsv', 'a') as f:
    for line in open(sys.argv[1]):
        i, ts, job = line.split()
        name = 'ev_' + ids[int(i)] if int(i) < len(ids) else sys.argv[2 + int(i) - len(ids)]
        if job not in have: f.write(f'{name}\t{job}\t{B}/hf_20260926_{ts}_{job}.png\n')
