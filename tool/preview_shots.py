"""Takes phone-sized screenshots of the web preview build (build/web) so the
app's screens can be checked after every change. Shop requests are answered
with CORS headers so product images load in the browser preview."""
import functools
import http.server
import os
import threading

from playwright.sync_api import sync_playwright

OUT = "preview"
PORT = 8765
SHOTS = [
    ("01_home", "home", 0),
    ("02_home_scrolled", "home", 700),
    ("03_shop", "shop", 0),
    ("04_product", "product-3219", 0),
    ("05_more", "more", 0),
    ("06_impressum", "legal-1776", 0),
    ("07_agb", "legal-1765", 0),
    ("08_versand", "legal-1786", 0),
]


def serve():
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory="build/web")
    httpd = http.server.ThreadingHTTPServer(("127.0.0.1", PORT), handler)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()


def add_cors(route):
    if route.request.method == "OPTIONS":
        route.fulfill(status=204, headers={
            "access-control-allow-origin": "*",
            "access-control-allow-headers": "*",
            "access-control-allow-methods": "GET, POST, OPTIONS",
        })
        return
    try:
        resp = route.fetch()
        headers = dict(resp.headers)
        headers["access-control-allow-origin"] = "*"
        headers["access-control-expose-headers"] = "*"
        route.fulfill(response=resp, headers=headers)
    except Exception as exc:  # noqa: BLE001
        print("fetch failed", route.request.url, exc)
        route.abort()


def main():
    os.makedirs(OUT, exist_ok=True)
    serve()
    with sync_playwright() as pw:
        browser = pw.chromium.launch()
        for name, screen, scroll in SHOTS:
            ctx = browser.new_context(viewport={"width": 412, "height": 892}, device_scale_factor=2, locale="de-DE")
            page = ctx.new_page()
            page.route("**/arkaschmuck.de/**", add_cors)
            page.on("console", lambda m: print("console:", m.text) if m.type == "error" else None)
            page.goto(f"http://127.0.0.1:{PORT}/?screen={screen}", wait_until="load")
            page.wait_for_timeout(9000)
            if scroll:
                page.mouse.move(206, 500)
                page.mouse.wheel(0, scroll)
                page.wait_for_timeout(3000)
            page.screenshot(path=f"{OUT}/{name}.png")
            print("shot", name)
            ctx.close()
        browser.close()


if __name__ == "__main__":
    main()
