import json, os, traceback
import requests
from playwright.sync_api import sync_playwright

SITE = 'https://arkaschmuck.de'
os.makedirs('out', exist_ok=True)
UA = 'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Mobile Safari/537.36'
S = requests.Session(); S.headers['User-Agent'] = UA

# 1. images
imgs = ['2026/02/Rings.png','2026/02/Necklace.png','2026/02/Earrings.png','2026/02/Combos.png','2026/02/Bracelets.png',
        '2026/02/Gemini_Generated_Image_9anlw09anlw09anl.webp','2026/02/7.png','2026/02/8.png','2026/02/9.png',
        '2023/04/home-default-banner-4.jpg','2026/02/home-default-banner-1.webp','2026/02/home-default-banner-2.webp','2026/02/home-default-banner-3.webp']
os.makedirs('out/img', exist_ok=True)
for p in imgs:
    try:
        r = S.get(f'{SITE}/wp-content/uploads/{p}', timeout=30)
        print('IMG', r.status_code, p, len(r.content), r.headers.get('access-control-allow-origin'))
        if r.ok:
            open('out/img/' + p.replace('/', '_'), 'wb').write(r.content)
    except Exception as e:
        print('IMG ERR', p, e)

# 2. legal pages via WP REST
for pid in [1765, 2193, 1776, 1786, 1792]:
    try:
        r = S.get(f'{SITE}/wp-json/wp/v2/pages/{pid}', params={'_fields': 'id,title,content,modified'}, timeout=30,
                  headers={'Origin': 'http://localhost:8080'})
        j = r.json()
        c = j.get('content', {}).get('rendered', '')
        print('PAGE', pid, r.status_code, j.get('title', {}).get('rendered'), 'len', len(c), 'cors', r.headers.get('access-control-allow-origin'))
        open(f'out/page_{pid}.html', 'w').write(c)
    except Exception as e:
        print('PAGE ERR', pid, e)

# 3. store api
r = S.get(f'{SITE}/wp-json/wc/store/v1/products', params={'per_page': 30, 'orderby': 'date'}, timeout=30, headers={'Origin': 'http://localhost:8080'})
print('STORE', r.status_code, 'cors', r.headers.get('access-control-allow-origin'), 'total', r.headers.get('x-wp-total'))
prods = r.json()
types = {}
for p in prods:
    types[p['type']] = types.get(p['type'], 0) + 1
print('TYPES (first 30)', types)
simple = [p for p in prods if p['type'] == 'simple' and p['is_purchasable'] and p['is_in_stock']][:2]
print('TEST ITEMS', [(p['id'], p['name'], p['prices']['price']) for p in simple])
json.dump(prods[:2], open('out/sample_products.json', 'w'), indent=1)
items = [{'id': p['id'], 'quantity': 1} for p in simple]

JS = r'''
async (items) => {
  const out = [];
  const base = '/wp-json/wc/store/v1';
  let nonce = '';
  const pick = (res) => { const n = res.headers.get('Nonce') || res.headers.get('X-WC-Store-API-Nonce'); if (n) nonce = n; };
  const h = () => ({'Content-Type':'application/json','Accept':'application/json','Nonce':nonce});
  let r = await fetch(base + '/cart', {credentials:'same-origin'}); pick(r); out.push('GET cart ' + r.status + ' nonce=' + (nonce?'yes':'no') + ' carttoken=' + (r.headers.get('Cart-Token')?'yes':'no'));
  r = await fetch(base + '/cart/items', {method:'DELETE', credentials:'same-origin', headers:h()}); pick(r); out.push('DELETE ' + r.status);
  for (const it of items) {
    r = await fetch(base + '/cart/add-item', {method:'POST', credentials:'same-origin', headers:h(), body: JSON.stringify(it)}); pick(r);
    let t = ''; try { const j = await r.json(); t = j.message || ('items=' + (j.items_count)); } catch(e) {}
    out.push('ADD ' + it.id + ' ' + r.status + ' ' + t);
  }
  r = await fetch(base + '/cart', {credentials:'same-origin'}); const j = await r.json(); out.push('CART after: items_count=' + j.items_count);
  out.push('cookies: ' + document.cookie);
  return out;
}
'''

def flow(tag, bootstrap):
    with sync_playwright() as pw:
        b = pw.chromium.launch()
        ctx = b.new_context(**pw.devices['Pixel 7'], locale='de-DE')
        page = ctx.new_page()
        nav = []
        page.on('framenavigated', lambda f: nav.append(f.url) if f == page.main_frame else None)
        try:
            page.goto(SITE + bootstrap, wait_until='domcontentloaded', timeout=60000)
            res = page.evaluate(JS, items)
            print(tag, 'JS:', *res, sep='\n   ')
            print(tag, 'cookies after JS:', sorted(c['name'] for c in ctx.cookies()))
            page.goto(SITE + '/checkout/', wait_until='load', timeout=90000)
            page.wait_for_timeout(5000)
            print(tag, 'final url:', page.url)
            print(tag, 'navigations:', nav)
            page.screenshot(path=f'out/{tag}_checkout.png')
            page.screenshot(path=f'out/{tag}_checkout_full.png', full_page=True)
        except Exception:
            traceback.print_exc()
            try: page.screenshot(path=f'out/{tag}_error.png')
            except Exception: pass
        b.close()

def classic(tag):
    with sync_playwright() as pw:
        b = pw.chromium.launch()
        ctx = b.new_context(**pw.devices['Pixel 7'], locale='de-DE')
        page = ctx.new_page()
        try:
            for it in items:
                page.goto(f"{SITE}/?add-to-cart={it['id']}&quantity=1", wait_until='domcontentloaded', timeout=90000)
                print(tag, 'after add url', page.url)
            print(tag, 'cookies:', sorted(c['name'] for c in ctx.cookies()))
            page.goto(SITE + '/checkout/', wait_until='load', timeout=90000)
            page.wait_for_timeout(5000)
            print(tag, 'final url:', page.url)
            page.screenshot(path=f'out/{tag}_checkout.png')
        except Exception:
            traceback.print_exc()
        b.close()

flow('A_cartpage', '/cart/')
flow('B_jsonboot', '/wp-json/wc/store/v1/cart')
classic('C_classic')
