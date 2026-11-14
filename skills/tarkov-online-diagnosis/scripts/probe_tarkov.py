# probe_tarkov.py - anonymous GET probes of BSG endpoints + real exit IP (ASCII-friendly output)
# classify 403 pages: ngx_stub challenge (exit-node throttled) vs styled block page (geo/IP block)
import ssl, urllib.request, urllib.error, socket, sys

sys.stdout.reconfigure(encoding='utf-8', errors='replace')
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE
UA = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}

def probe(url):
    req = urllib.request.Request(url, headers=UA)
    try:
        with urllib.request.urlopen(req, timeout=15, context=ctx) as r:
            return r.status, dict(r.headers), r.read(400)
    except urllib.error.HTTPError as e:
        return e.code, dict(e.headers), e.read(400)
    except Exception as e:
        return None, {}, repr(e).encode()

def classify(st, headers, body):
    if st != 403:
        return ''
    for k, v in headers.items():
        if k.lower() == 'set-cookie' and 'ngx_stub_request_ip' in v:
            ip = v.split('ngx_stub_request_ip=')[1].split(';')[0]
            return f'stub-challenge page (anti-DDoS): exit IP as seen by BSG = {ip}'
    if b'<style>' in body or b'--h1-font-size' in body:
        return 'styled block page (geo/IP block, no challenge cookie)'
    return 'other 403 page'

targets = [
    'https://lobby.escapefromtarkov.ru/router?vhost=pve',
    'https://gw-pve.escapefromtarkov.ru/client/game/config',
    'https://api.ipify.org',
    'https://myip.ipip.net',
]
for t in targets:
    st, hd, body = probe(t)
    print('==', t)
    print('   status:', st)
    for k, v in hd.items():
        if k.lower() in ('server', 'set-cookie', 'content-type', 'content-length', 'location'):
            print('   hdr:', k, '=', v)
    if st:
        c = classify(st, hd, body)
        if c:
            print('   class:', c)
    print('   body:', body[:180])

for host in ('lobby.escapefromtarkov.ru', 'gw-pve.escapefromtarkov.ru', 'gw-pvp.escapefromtarkov.ru'):
    try:
        print('DNS', host, '->', socket.gethostbyname_ex(host)[2])
    except Exception as e:
        print('DNS', host, 'FAIL', repr(e))
