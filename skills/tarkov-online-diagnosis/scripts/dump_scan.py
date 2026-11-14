# dump_scan.py - scan a minidump for Chromium CHECK/fatal message strings (read-only)
# usage: python dump_scan.py <path-to.dmp>
import re, sys, os

sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if len(sys.argv) < 2:
    print('usage: dump_scan.py <dump.dmp>')
    sys.exit(1)
path = sys.argv[1]

pats = [
    rb'Check failed[^\x00]{0,160}',
    rb'FATAL[^\x00]{0,120}',
    rb'NOTREACHED[^\x00]{0,120}',
    rb'CHECK_[A-Z_]+ ?\([^\x00]{0,120}',
    rb'Fatal error[^\x00]{0,120}',
    rb'Unable to find[^\x00]{0,120}',
    rb'GPU process[^\x00]{0,120}',
]
found = {}
CHUNK = 4 * 1024 * 1024
overlap = 4096
with open(path, 'rb') as f:
    prev_tail = b''
    while True:
        chunk = f.read(CHUNK)
        if not chunk:
            break
        buf = prev_tail + chunk
        for p in pats:
            for m in re.finditer(p, buf):
                s = m.group(0)[:200]
                printable = sum(1 for b in s if 32 <= b < 127)
                if printable > len(s) * 0.7:
                    key = s[:60]
                    if key not in found:
                        found[key] = s
        prev_tail = buf[-overlap:]

print('scanned:', path, os.path.getsize(path), 'bytes')
if not found:
    print('no CHECK/fatal strings found in dump')
for k, v in list(found.items())[:20]:
    print('HIT:', v.decode('ascii', 'replace'))
