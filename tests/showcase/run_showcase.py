#!/usr/bin/env python3
"""Showcase tier — browser tests for the Simulate kit and the check-prototype.py harness (spec 1.1.3 §3.1).
Free and deterministic; needs Python Playwright with Chromium (pip install playwright; python -m playwright install chromium).
Usage: python tests/showcase/run_showcase.py [out-dir]
"""
import os
import pathlib
import re
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except (AttributeError, ValueError):
    pass
from playwright.sync_api import sync_playwright


HERE = pathlib.Path(__file__).resolve().parent
ROOT = pathlib.Path(os.environ.get("AIT_REPO_ROOT") or HERE.parent.parent)
SKILL = ROOT / "plugins" / "ai-team-sdlc" / "skills" / "ait-product-showcase" / "assets"
KIT, HARNESS = SKILL / "simulate-kit.html", SKILL / "check-prototype.py"
# The same speech stub the shipped harness uses, so every test page is silent.
SILENT_JS = re.search(r'SILENT_JS = """(.*?)"""', HARNESS.read_text(encoding="utf-8"), re.S).group(1)

RESULTS = []


def check(name, ok, detail=""):
    RESULTS.append(ok)
    print(f"{'OK ' if ok else 'BAD'}  {name}{' — ' + detail if detail else ''}", flush=True)


def block(text, start, end):
    m = re.search(re.escape(start) + r".*?" + re.escape(end) + r"[^\n]*", text, re.S)
    if not m:
        raise SystemExit(f"kit block not found: {start}")
    return m.group(0)


def build_fixture(out, mutate=None):
    """The template with the kit's three blocks pasted in and the engine's CONFIG replaced, as an author does."""
    kit = KIT.read_text(encoding="utf-8")
    tpl = (HERE / "app.template.html").read_text(encoding="utf-8")
    css = block(kit, "/* ==== SIMULATE · CSS", "/* ==== /SIMULATE · CSS")
    btn = block(kit, "<!-- ==== SIMULATE · BUTTON ==== -->", "<!-- ==== /SIMULATE · BUTTON ==== -->")
    eng = block(kit, "<!-- ==== SIMULATE · ENGINE ==== -->", "<!-- ==== /SIMULATE · ENGINE ==== -->")
    config = re.search(r'<script id="fixture-config" type="text/plain">\n(.*?)</script>', tpl, re.S).group(1)
    eng = re.sub(r"  /\* -+ CONFIG.*?/CONFIG \*/", lambda _: config.rstrip(), eng, flags=re.S)
    html = (tpl.replace("/* ==== SIMULATE CSS (injected) ==== */", css)
               .replace("<!-- ==== SIMULATE BUTTON (injected) ==== -->", btn)
               .replace("<!-- ==== SIMULATE ENGINE (injected) ==== -->", eng))
    html = re.sub(r'<script id="fixture-config".*?</script>\n', "", html, flags=re.S)
    for old, new in (mutate or {}).items():
        if old not in html:
            raise SystemExit(f"mutation anchor not found: {old[:60]}")
        html = html.replace(old, new)
    out.write_text(html, encoding="utf-8")
    return out


# Counts utterances on top of the silent stub, to prove narration on and off.
COUNT_JS = "window.__spoken = 0; { const s = speechSynthesis.speak.bind(speechSynthesis); speechSynthesis.speak = u => { window.__spoken++; s(u); }; }"


def page_with_log(browser, url, viewport=(1366, 900)):
    pg = browser.new_page(viewport={"width": viewport[0], "height": viewport[1]})
    pg.add_init_script(SILENT_JS)   # never call native speech (--mute-audio misses it on Windows)
    pg.add_init_script(COUNT_JS)
    log = []
    pg.on("console", lambda m: log.append(f"{m.type}: {m.text}") if m.type in ("error", "warning") else None)
    pg.on("pageerror", lambda e: log.append(f"pageerror: {e}"))
    pg.goto(url)
    pg.wait_for_timeout(300)
    return pg, log


def beats(pg, start):
    """Plays a scenario with Next and records (title, view) per beat."""
    start()
    pg.wait_for_selector("#simbar", state="attached")
    seen = []
    for _ in range(20):
        if not pg.evaluate("Simulate.running"):
            break
        pg.wait_for_timeout(900)   # let the beat set up its screen
        if not pg.evaluate("Simulate.running"):
            break
        seen.append((pg.text_content("#sim-title"), pg.evaluate("S.view")))
        pg.evaluate("Simulate.next()")
    pg.wait_for_function("!Simulate.running", timeout=5000)
    return seen


def kit_tests(browser, fixture):
    kit = KIT.as_uri()
    pg, log = page_with_log(browser, kit)
    # 1. Next on the last beat ends the tour at once; a toast is gone at the next beat.
    pg.evaluate("void Simulate.start('full')")
    pg.wait_for_selector("#simbar")
    pg.evaluate("Simulate.next()")
    pg.wait_for_selector(".toast.show", timeout=10000)
    pg.evaluate("Simulate.next()")
    pg.wait_for_timeout(250)
    check("kit: a toast from one beat is cleared at the next", not pg.is_visible(".toast.show"))
    while pg.text_content("#sim-title") and "that's not all" not in (pg.text_content("#sim-title") or ""):
        pg.evaluate("Simulate.next()")
        pg.wait_for_timeout(250)
    pg.wait_for_timeout(300)
    t = time.time()
    pg.evaluate("Simulate.next()")
    pg.wait_for_function("!Simulate.running", timeout=5000)
    took = time.time() - t
    check("kit: Next on the last beat ends the tour at once", took < 1.0, f"{took:.2f}s")
    # 2. Scenarios: menu item, shortcut and API; the same beats every time.
    a = beats(pg, lambda: pg.evaluate("void Simulate.start('short')"))
    b = beats(pg, lambda: pg.keyboard.press("Control+Alt+1"))
    c = beats(pg, lambda: pg.click("[data-simulate-run=short]"))
    check("kit: short scenario from API, shortcut and menu item plays the same beats", a == b == c and len(a) == 2, f"{a}")
    f1 = beats(pg, lambda: pg.keyboard.press("Control+Alt+2"))
    f2 = beats(pg, lambda: pg.evaluate("void Simulate.start('full')"))
    check("kit: full scenario plays the same beats twice", f1 == f2 and len(f1) == 4, f"{len(f1)} beats")
    # 4. Shortcuts are ignored while typing.
    pg.evaluate("nav('ask')")
    pg.focus("#q")
    pg.keyboard.press("Control+Alt+2")
    pg.keyboard.press("Control+Alt+P")
    pg.wait_for_timeout(300)
    check("kit: shortcuts are ignored while typing", not pg.evaluate("Simulate.running") and not pg.evaluate("Simulate.presenting"))
    pg.evaluate("document.activeElement.blur()")
    # 3. Presentation mode by shortcut; a tour runs in it.
    pg.keyboard.press("Control+Alt+P")
    pg.evaluate("void Simulate.start('short')")
    pg.wait_for_selector(".simfocus", state="attached", timeout=5000)
    hidden = not any(pg.is_visible(s) for s in ("[data-simulate]", "[data-simulate-run]", "#simbar")) and \
        pg.evaluate("getComputedStyle(document.getElementById('simprog')).display") == "none"
    focus_outline = pg.evaluate("() => { const e = document.querySelector('.simfocus'); return e ? getComputedStyle(e).outlineStyle : 'none'; }")
    check("kit: presentation mode (shortcut) hides the walkthrough controls while a tour runs",
          hidden and pg.evaluate("Simulate.running") and focus_outline == "none" and pg.is_visible("#tabs"))
    pg.keyboard.press("Escape")
    pg.wait_for_function("!Simulate.running", timeout=3000)
    check("kit: Esc exits a tour in presentation mode", True)
    check("kit: no console errors or warnings", not log, "; ".join(log[:3]))
    pg.close()
    # ?present&cursor&mute
    pg, log = page_with_log(browser, kit + "?present&cursor&mute")
    pg.evaluate("void Simulate.start('short')")
    pg.wait_for_timeout(400)
    check("kit: ?present ?cursor ?mute", pg.evaluate("Simulate.presenting") and pg.query_selector("#simcursor") is not None
          and pg.get_attribute("#sim-mute", "aria-pressed") == "true" and not pg.is_visible("#simbar"))
    pg.evaluate("Simulate.stop()")
    pg.wait_for_timeout(300)
    check("kit: the cursor is removed on exit", pg.query_selector("#simcursor") is None)
    pg.close()
    # closeAll on start and on exit (fixture maps it to the app's own close-all).
    pg, log = page_with_log(browser, fixture.as_uri())
    pg.click("#notif-btn")
    was_open = pg.is_visible("#notif")
    pg.evaluate("void Simulate.start('full')")
    pg.wait_for_timeout(300)
    on_start = was_open and pg.is_hidden("#notif")
    pg.evaluate("document.getElementById('user-btn').click()")
    pg.wait_for_timeout(200)
    pg.evaluate("Simulate.stop()")
    pg.wait_for_timeout(300)
    check("kit: closeAll runs when a tour starts and when it exits", on_start and pg.is_hidden("#user-menu"))
    # The full tour from its menu item; presentation mode hides data-demo-only elements too.
    pg.click("#user-btn")
    pg.click("[data-simulate-run=full]")
    pg.wait_for_timeout(500)
    from_menu = pg.evaluate("Simulate.running") and pg.evaluate("Simulate.scenario") == "full"
    pg.evaluate("Simulate.stop()")
    pg.wait_for_timeout(300)
    shown_before = pg.is_visible("#demo-note")
    pg.keyboard.press("Control+Alt+P")
    hidden_after = pg.is_hidden("#demo-note") and pg.is_visible("footer") and pg.is_visible("[data-nav]")
    pg.keyboard.press("Control+Alt+P")
    check("kit: full tour from its menu item; presentation mode hides data-demo-only, keeps nav and footer",
          from_menu and shown_before and hidden_after and pg.is_visible("#demo-note"))
    # Esc while typing in the app's own dialog closes the dialog, not the tour; the next Esc exits.
    pg.evaluate("void Simulate.start('full')")
    pg.wait_for_timeout(500)
    pg.click("#search-btn")
    pg.wait_for_timeout(200)
    pg.keyboard.press("Escape")
    pg.wait_for_timeout(300)
    kept = pg.evaluate("Simulate.running") and pg.is_hidden("#search")
    pg.keyboard.press("Escape")
    pg.wait_for_timeout(400)
    check("kit: Esc in the app's dialog closes it and keeps the tour; the next Esc exits", kept and not pg.evaluate("Simulate.running"))
    # Rapid scenario requests: only the latest runs, and Exit cancels a request still waiting.
    pg.keyboard.press("Control+Alt+1")
    pg.keyboard.press("Control+Alt+2")
    pg.keyboard.press("Escape")
    pg.wait_for_timeout(1500)
    check("kit: Exit cancels scenario requests still waiting to start", not pg.evaluate("Simulate.running"))
    pg.close()
    # Unattended playback (no Next) in presentation mode: both scenarios finish on their own.
    pg, log = page_with_log(browser, fixture.as_uri() + "?present&cursor")
    pg.keyboard.press("Control+Alt+1")
    pg.wait_for_selector("#simcursor", state="attached")
    start_pos = pg.get_attribute("#simcursor", "style")
    pg.wait_for_timeout(2500)
    moved = pg.get_attribute("#simcursor", "style") != start_pos
    pg.wait_for_function("!Simulate.running", timeout=30000)
    spoken_short = pg.evaluate("window.__spoken")
    check("kit: short tour plays to the end unattended in presentation mode, cursor moving, narration on",
          moved and spoken_short == 2 and pg.evaluate("Simulate.presenting"), f"moved={moved} utterances={spoken_short}")
    pg.keyboard.press("m")   # no effect outside a tour; mute is tested via ?mute below
    pg.close()
    pg, log = page_with_log(browser, fixture.as_uri() + "?present&mute")
    pg.keyboard.press("Control+Alt+2")
    pg.wait_for_selector("#simbar", state="attached")
    pg.wait_for_function("!Simulate.running", timeout=40000)
    check("kit: full tour plays to the end unattended in presentation mode, narration off",
          pg.evaluate("window.__spoken") == 0 and not log, f"utterances={pg.evaluate('window.__spoken')} log={log[:2]}")
    pg.close()
    # Without CONFIG.dismiss the engine still clears .toast.show at the next beat.
    nodis = build_fixture(fixture.parent / "no-dismiss.html", {'    dismiss: () => $("#toast").classList.remove("show"),\n': ""})
    pg, log = page_with_log(browser, nodis.as_uri())
    pg.evaluate("void Simulate.start('full')")
    pg.wait_for_timeout(300)
    pg.evaluate("Simulate.next()")
    pg.wait_for_selector(".toast.show", timeout=10000)
    pg.evaluate("Simulate.next()")
    pg.wait_for_timeout(250)
    check("kit: without CONFIG.dismiss, .toast.show is still cleared at the next beat", not pg.is_visible(".toast.show"))
    pg.evaluate("Simulate.stop()")
    pg.close()


def run_harness(fixture):
    env = dict(os.environ, PYTHONIOENCODING="utf-8")
    return subprocess.run([sys.executable, str(HARNESS), str(fixture), "--quiet"], capture_output=True, text=True,
                          encoding="utf-8", errors="replace", env=env)


def harness(r, expect_fail=None):
    failed = set(re.findall(r"^FAIL  (\S+)", r.stdout, re.M))
    if expect_fail is None:
        check("harness: the fixture app passes every check", r.returncode == 0, r.stdout.strip().splitlines()[-1] if r.stdout.strip() else r.stderr[-300:])
        if r.returncode:
            print(r.stdout)
    else:
        name, want = expect_fail
        ok = (r.returncode == 1 and want <= failed) if want else (r.returncode == 0 and not failed)
        check(f"harness: mutation '{name}' " + (f"fails {sorted(want)}" if want else "still passes"), ok, f"failed={sorted(failed)}" + ("" if r.stdout else " " + (r.stderr or "")[-300:]))


MUTATIONS = [
    ("low-contrast ink in dark mode", {"--ink-muted:#9aa4b2": "--ink-muted:#4a525c"}, {"contrast-dark"}),
    ("Esc does not close", {'if (e.key === "Escape" && openId) { e.preventDefault(); closeAll(true); return; } /* MUT:esc */': ""}, {"overlays"}),
    ("faded text (group opacity)", {".muted{color:var(--ink-muted)}": ".muted{color:var(--ink-muted);opacity:.45}"}, {"contrast-light", "contrast-dark"}),
    ("text over a gradient (unmeasurable)", {".card{background:var(--surface);": ".card{background:linear-gradient(var(--surface),var(--surface-2));"}, {"contrast-light", "contrast-dark"}),
    ("screens never marked active", {'if (b.dataset.nav === v) b.setAttribute("aria-current", "page"); else b.removeAttribute("aria-current");': ""}, {"contrast-light", "contrast-dark"}),
    ("closed overlay stays on screen", {'function show(id, on) { if (id === "side") $("#side").classList.toggle("open", on); else $("#" + id).hidden = !on; }':
                                        'function show(id, on) { if (id === "side") $("#side").classList.toggle("open", on); else if (on) $("#" + id).hidden = false; }'}, {"overlays"}),
    ("two overlays open at once", {"closeAll(false); /* MUT:one-at-a-time */": ""}, {"overlays"}),
    ("focus not returned", {"if (restoreFocus && back) back.focus(); /* MUT:focus */": ""}, {"overlays"}),
    ("Tab escapes the dialog", {'if (e.key === "Tab" && openId && $("#" + openId).matches("[role=dialog]") /* MUT:trap-other */) {': "if (false) {"}, {"overlays"}),
    ("Tab escapes a dialog on another screen", {'$("#" + openId).matches("[role=dialog]") /* MUT:trap-other */': 'openId === "search"'}, {"overlays"}),
    ("presentation mode shows the panel", {"body.sim-present .simbar,body.sim-present .simprog{display:none!important}":
                                           "body.sim-present .simprog{display:none!important}"}, {"presentation"}),
    ("presentation mode shows the progress line", {"body.sim-present .simbar,body.sim-present .simprog{display:none!important}":
                                                   "body.sim-present .simbar{display:none!important}"}, {"presentation"}),
    ("presentation mode shows the spotlight", {"body.sim-present .simfocus{outline:none!important;animation:none!important}": ""}, {"presentation"}),
    ("host shortcut fires while typing", {"if (typing) return; /* MUT:typing */": ""}, {"typing"}),
    ("unreadable text in a first-screen overlay", {".help-tx{color:var(--ink-2)}": ".help-tx{color:#cfd3d8}"}, {"contrast-light"}),
    ("photo/gradient page behind solid surfaces", {"body{margin:0;": "body{background-image:linear-gradient(#123,#456);margin:0;"}, set()),
    ("drawer slides off-canvas (transform)", {"#side{display:none;position:fixed;top:56px;bottom:0;left:0;z-index:55;box-shadow:0 8px 24px rgba(0,0,0,.3)}\n  #side.open{display:flex}":
                                              "#side{display:flex;position:fixed;top:56px;bottom:0;left:0;z-index:55;transform:translateX(-105%);transition:.2s}\n  #side.open{transform:none}"}, set()),
    ("footer says synthetic data", {"Simulated data for demonstration": "Synthetic data for demonstration"}, set()),
    ("menu not a drawer on phones", {"#side{display:none;position:fixed": "#side{position:fixed"}, {"mobile-drawer"}),
]


def main():
    out = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ROOT / "tests" / "out" / "showcase" / f"{time.strftime('%Y%m%d-%H%M%S')}-{os.getpid()}").resolve()
    out.mkdir(parents=True, exist_ok=True)
    fixture = build_fixture(out / "app.html")
    with sync_playwright() as p:
        browser = p.chromium.launch(args=["--mute-audio"])
        kit_tests(browser, fixture)
        browser.close()
    # The clean fixture and every mutation, 4 harness runs at a time (each is an independent browser).
    jobs = [(fixture, None)] + [(build_fixture(out / f"mut-{i}.html", mut), (name, want)) for i, (name, mut, want) in enumerate(MUTATIONS)]
    with ThreadPoolExecutor(max_workers=4) as pool:
        runs = list(pool.map(lambda j: run_harness(j[0]), jobs))
    for (_, expect), r in zip(jobs, runs):
        harness(r, expect)
    print(f"\nshowcase: {sum(RESULTS)}/{len(RESULTS)} as expected")
    return 0 if all(RESULTS) else 1


if __name__ == "__main__":
    sys.exit(main())
