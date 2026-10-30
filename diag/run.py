import json, os, traceback
from playwright.sync_api import sync_playwright
SITE = 'https://arkaschmuck.de'
os.makedirs('out', exist_ok=True)
items = [{'id': 3219, 'quantity': 1}]
BOOT = r'''
async (items) => {
  const base = '/wp-json/wc/store/v1'; let nonce = '';
  const pick = (r) => { const n = r.headers.get('Nonce'); if (n) nonce = n; };
  const h = () => ({'Content-Type':'application/json','Nonce':nonce});
  let r = await fetch(base + '/cart', {credentials:'same-origin'}); pick(r);
  r = await fetch(base + '/cart/items', {method:'DELETE', credentials:'same-origin', headers:h()}); pick(r);
  for (const it of items) { r = await fetch(base + '/cart/add-item', {method:'POST', credentials:'same-origin', headers:h(), body: JSON.stringify(it)}); pick(r); }
  return r.status;
}'''
PROBE = r'''
() => {
  const desc = (el) => el.tagName.toLowerCase() + (el.id ? '#' + el.id : '') + (el.className && typeof el.className === 'string' ? '.' + el.className.trim().split(/\s+/).slice(0,6).join('.') : '');
  const out = {top: [], find: {}};
  for (const c of document.body.children) { const r = c.getBoundingClientRect(); out.top.push(desc(c) + ' h=' + Math.round(r.height) + ' disp=' + getComputedStyle(c).display); }
  const texts = {sale: 'Bis zu 70%', cookie: 'Zustimmen', footer: 'NEWSLETTER', footer2: 'RECHTLICHES', order: 'Your order', billing: 'Rechnungsdaten', coupon: 'Gutschein'};
  for (const [k, t] of Object.entries(texts)) {
    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    let n, chain = null;
    while ((n = walker.nextNode())) { if (n.textContent.includes(t)) { chain = []; let e = n.parentElement; while (e && e !== document.body) { chain.push(desc(e)); e = e.parentElement; } break; } }
    out.find[k] = chain;
  }
  const logo = document.querySelector('img[src*="Logo"], img[alt*="ARKA" i]');
  if (logo) { const chain = []; let e = logo; while (e && e !== document.body) { chain.push(desc(e)); e = e.parentElement; } out.find.logo = chain; }
  return out;
}'''
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx = b.new_context(**pw.devices['Pixel 7'], locale='de-DE')
    page = ctx.new_page()
    page.goto(SITE + '/wp-json/wc/store/v1/cart', wait_until='domcontentloaded')
    print('boot', page.evaluate(BOOT, items))
    page.goto(SITE + '/checkout/', wait_until='load', timeout=90000)
    page.wait_for_timeout(4000)
    print(json.dumps(page.evaluate(PROBE), indent=1, ensure_ascii=False))
    open('out/checkout.html', 'w').write(page.content())
    b.close()
