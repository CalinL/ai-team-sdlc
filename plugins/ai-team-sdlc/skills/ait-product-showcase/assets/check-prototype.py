#!/usr/bin/env python3
# Created by Calin Lupas with AI assistance. Credits: the repository's README.md (Authors and credits) and NOTICE.
"""Reusable browser checks for a showcase or prototype built as a product app (references/product-app.md).

Usage:  python check-prototype.py <file.html | URL> [--layout app|page] [--tours short,full] [--quiet]
Needs:  pip install playwright && python -m playwright install chromium

Checks (each prints PASS/FAIL; exit code 1 on any FAIL):
  app-shell        menu items [data-nav], theme switch [data-theme-toggle], header, footer, Ctrl+K search
  header-row       the header's controls sit on one row
  contrast-<theme> every screen in both themes: text >= 4.5:1, large text >= 3:1
  overlays         one open at a time, Esc closes it, focus returns to its opener, Tab stays in dialogs
  typing           shortcuts are ignored while typing in a field
  mobile-drawer    at phone width the menu is a slide-out drawer that opens and closes
  simulate-<name>  each scenario runs to the end with Next, with no [simulate] warnings, and Exit
                   leaves no overlay open
  presentation     presentation mode hides every walkthrough control; navigation and footer stay
  console          no console errors or page errors during the whole run

Known pitfalls, handled here; keep them in mind when you add checks:
  - Read SVG text with text_content(), never inner_text(): inner_text() returns "" for SVG <text>.
  - The kit's progress line is 0% wide on the first beat, so it is not "visible": check that it is
    attached instead.
  - The Simulate button is taller than other header controls, so "header height <= one control"
    fails falsely: check that the controls' vertical spans overlap instead.
  - --mute-audio alone does not silence Web Speech on Windows: SILENT_JS stubs speechSynthesis.
  - Windows consoles default to a legacy code page: stdout is switched to UTF-8 so characters
    such as − and · in page text never crash printing.
"""
import argparse
import pathlib
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except (AttributeError, ValueError):
    pass

from playwright.sync_api import sync_playwright

# --mute-audio does not silence Web Speech on every OS (Windows speaks through the system voice), so
# every test page also gets this init script: native speech is never called, and each utterance
# "ends" on its own so the tour keeps its pacing. The delivered prototype is not changed.
SILENT_JS = """(() => { try {
  const s = window.speechSynthesis; if (!s) return;
  s.speak = u => { setTimeout(() => { try { u.onend && u.onend(new Event("end")); } catch (e) { } }, 50); };
  s.cancel = () => { }; s.pause = () => { }; s.resume = () => { };
  if (window.SpeechSynthesisUtterance) Object.defineProperty(SpeechSynthesisUtterance.prototype, "volume", { get: () => 0, set: () => { }, configurable: true });
} catch (e) { } })();"""

# Runs as-is in the Playwright MCP's browser_evaluate as well.
CONTRAST_JS = r"""() => {
  const cv = document.createElement("canvas"); cv.width = cv.height = 1; const cx = cv.getContext("2d", { willReadFrequently: true });
  const rgba = c => { cx.clearRect(0, 0, 1, 1); cx.fillStyle = "#000"; cx.fillStyle = c; cx.fillRect(0, 0, 1, 1); const d = cx.getImageData(0, 0, 1, 1).data; return [d[0], d[1], d[2], d[3] / 255]; };
  const over = (top, bot) => { const a = top[3] + bot[3] * (1 - top[3]); if (!a) return [0, 0, 0, 0]; return [0, 1, 2].map(i => (top[i] * top[3] + bot[i] * bot[3] * (1 - top[3])) / a).concat(a); };
  const lum = c => { const f = v => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); }; return 0.2126 * f(c[0]) + 0.7152 * f(c[1]) + 0.0722 * f(c[2]); };
  const ratio = (a, b) => { const x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); };
  const fails = [], seen = new Set(); let checked = 0, skipped = 0;
  const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
  for (let n = walker.nextNode(); n; n = walker.nextNode()) {
    const el = n.parentElement; if (!el || seen.has(el) || !n.textContent.trim()) continue; seen.add(el);
    if (el.closest("script,style,noscript,[aria-hidden='true'],[hidden]") || el.closest(":disabled")) continue;
    const r = el.getBoundingClientRect(), cs = getComputedStyle(el);
    if (!r.width || !r.height || cs.visibility !== "visible" || +cs.opacity === 0) continue;
    const svg = el.closest("svg");
    let fg = rgba(svg && cs.fill && !cs.fill.startsWith("url") ? cs.fill : cs.color);
    let op = 1; for (let e = el; e; e = e.parentElement) op *= +getComputedStyle(e).opacity;
    fg[3] *= op;
    let bg = [0, 0, 0, 0], unknown = false;
    for (let e = el; e; e = e.parentElement) {
      const s = getComputedStyle(e);
      if (s.backgroundImage !== "none") { unknown = true; break; }
      bg = over(bg, rgba(s.backgroundColor)); if (bg[3] >= 0.999) break;
    }
    if (unknown) { skipped++; continue; }
    bg = over(bg, [255, 255, 255, 1]);
    const c = ratio(over(fg, bg), bg), size = parseFloat(cs.fontSize), bold = +cs.fontWeight >= 700;
    const need = size >= 24 || (bold && size >= 18.66) ? 3 : 4.5; checked++;
    if (c < need) fails.push({ text: n.textContent.trim().slice(0, 40), ratio: +c.toFixed(2), need,
      where: (el.id ? "#" + el.id : el.tagName.toLowerCase() + (el.className && typeof el.className === "string" ? "." + el.className.trim().split(/\s+/)[0] : "")) });
  }
  return { checked, skipped, fails };
}"""

OPEN_OVERLAYS_JS = """() => [...document.querySelectorAll('[aria-controls][aria-expanded="true"]')]
  .filter(o => !o.closest('.simbar')).map(o => o.getAttribute('aria-controls'))"""
VISIBLE_JS = """id => { const e = document.getElementById(id); if (!e) return false;
  const s = getComputedStyle(e), r = e.getBoundingClientRect(); return !e.hidden && s.display !== 'none' && s.visibility !== 'hidden' && r.width > 0 && r.height > 0; }"""


class Run:
    def __init__(self, quiet):
        self.failed = 0
        self.quiet = quiet

    def guard(self, name, fn, *args):
        """Runs one group of checks; an exception (a stuck overlay, a missing element) is a FAIL, not a crash."""
        try:
            fn(*args)
        except Exception as e:  # noqa: BLE001 - report any browser error as a failed check
            self.check(name, False, f"{type(e).__name__}: {str(e).splitlines()[0][:160]}")

    def check(self, name, ok, detail=""):
        if not ok:
            self.failed += 1
        if not ok or not self.quiet:
            print(f"{'PASS' if ok else 'FAIL'}  {name}{' — ' + detail if detail else ''}")


def target_url(t):
    return t if "://" in t else pathlib.Path(t).resolve().as_uri()


def openers(page):
    """Visible overlay openers outside the Simulate panel, as (element, overlay id)."""
    out = []
    for h in page.query_selector_all("[aria-controls][aria-expanded]"):
        if h.is_visible() and not h.evaluate("e => !!e.closest('.simbar, [data-simulate], [data-simulate-run]')"):
            out.append((h, h.get_attribute("aria-controls")))
    return out


def is_open(page, oid):
    return page.evaluate(VISIBLE_JS, oid)


def close_all(page):
    for _ in range(4):
        if not page.evaluate(OPEN_OVERLAYS_JS):
            return
        page.keyboard.press("Escape")
        page.wait_for_timeout(120)


def set_theme(page, want):
    for _ in range(3):
        if page.evaluate("document.documentElement.dataset.theme") == want:
            return True
        page.click("[data-theme-toggle]")
        page.wait_for_timeout(150)
    return page.evaluate("document.documentElement.dataset.theme") == want


def check_contrast(page, run, layout):
    navs = page.query_selector_all("[data-nav]") if layout == "app" else []
    toggle = page.query_selector("[data-theme-toggle]") is not None
    for theme in ("light", "dark") if layout == "app" or toggle else ("current",):
        if theme != "current" and not set_theme(page, theme):
            run.check(f"contrast-{theme}", False, "could not switch theme with [data-theme-toggle]")
            continue
        fails, checked, skipped = {}, 0, 0
        for nav in navs or [None]:
            if nav is not None:
                close_all(page)
                screen = nav.get_attribute("data-nav")
                nav.evaluate("e => e.click()")
                page.wait_for_timeout(250)
            else:
                screen = "page"
            res = page.evaluate(CONTRAST_JS)
            checked += res["checked"]
            skipped += res["skipped"]
            for f in res["fails"]:
                fails.setdefault(f"{screen}: {f['where']} '{f['text']}' {f['ratio']}:1 < {f['need']}:1", 1)
        detail = f"{checked} text elements, {skipped} over images/gradients skipped"
        name = "contrast" if theme == "current" else f"contrast-{theme}"
        if theme == "current":
            detail += "; one theme only (no [data-theme-toggle])"
        run.check(name, not fails, detail if not fails else f"{len(fails)} failing: " + "; ".join(list(fails)[:6]))


def check_overlays(page, run):
    close_all(page)
    ops = openers(page)
    if not ops:
        run.check("overlays", False, "no overlay openers ([aria-controls][aria-expanded]) found")
        return
    problems = []
    for h, oid in ops:
        h.focus()
        h.click()
        page.wait_for_timeout(150)
        if not is_open(page, oid) or h.get_attribute("aria-expanded") != "true":
            problems.append(f"#{oid} did not open with aria-expanded=true")
            close_all(page)
            continue
        if page.evaluate("id => document.getElementById(id).matches('[role=dialog][aria-modal=true]')", oid):
            for _ in range(12):
                page.keyboard.press("Tab")
                if not page.evaluate("id => document.getElementById(id).contains(document.activeElement)", oid):
                    problems.append(f"Tab left dialog #{oid}")
                    break
        page.keyboard.press("Escape")
        page.wait_for_timeout(150)
        if is_open(page, oid):
            problems.append(f"Esc did not close #{oid}")
            close_all(page)
        elif not h.evaluate("e => document.activeElement === e"):
            problems.append(f"focus did not return to the opener of #{oid}")
    for (a, aid), (b, bid) in zip(ops, ops[1:]):
        close_all(page)
        a.click()
        page.wait_for_timeout(120)
        b.evaluate("e => e.click()")
        page.wait_for_timeout(150)
        still = [o for o in page.evaluate(OPEN_OVERLAYS_JS) if is_open(page, o)]
        if len(still) > 1:
            problems.append(f"#{aid} and #{bid} open at once")
    close_all(page)
    page.keyboard.press("Control+k")
    page.wait_for_timeout(200)
    typing = page.evaluate("() => { const a = document.activeElement; return !!a && (/^(INPUT|TEXTAREA)$/.test(a.tagName) || a.isContentEditable); }")
    if not typing:
        problems.append("Ctrl+K did not open search with its input focused")
    run.check("overlays", not problems, f"{len(ops)} openers" if not problems else "; ".join(problems))
    if typing:
        page.keyboard.type("x")
        page.keyboard.press("Alt+Shift+2")
        page.wait_for_timeout(250)
        running = page.evaluate("() => !!(window.Simulate && Simulate.running)")
        if running:
            page.evaluate("Simulate.stop()")
        run.check("typing", not running, "Alt+Shift+2 while typing started a tour" if running else "")
    close_all(page)


def check_header(page, run):
    spans = page.evaluate("""() => { const h = document.querySelector('header'); if (!h) return null;
      return [...h.querySelectorAll('button, a, input, [role=button], nav')].filter(e => { const r = e.getBoundingClientRect();
        return r.width && r.height && getComputedStyle(e).visibility === 'visible'; }).map(e => { const r = e.getBoundingClientRect(); return [r.top, r.bottom]; }); }""")
    if spans is None:
        run.check("header-row", False, "no <header>")
        return
    ok = bool(spans) and min(b for _, b in spans) > max(t for t, _ in spans)
    run.check("header-row", ok, f"{len(spans)} controls" + ("" if ok else " wrap onto more than one row"))


def check_mobile(page, run):
    page.set_viewport_size({"width": 390, "height": 844})
    page.reload()
    page.wait_for_timeout(400)
    close_all(page)
    navs = [n for n in page.query_selector_all("[data-nav]") if n.is_visible()]
    drawer = [(h, oid) for h, oid in openers(page)
              if page.evaluate("id => !!document.getElementById(id) && !!document.getElementById(id).querySelector('[data-nav]')", oid)]
    if navs or not drawer:
        run.check("mobile-drawer", False, "menu items visible at 390px" if navs else "no menu button controlling the menu")
    else:
        h, oid = drawer[0]
        h.click()
        page.wait_for_timeout(300)
        opened = is_open(page, oid) and any(n.is_visible() for n in page.query_selector_all("[data-nav]"))
        page.keyboard.press("Escape")
        page.wait_for_timeout(300)
        closed = not is_open(page, oid)
        run.check("mobile-drawer", opened and closed, "" if opened and closed else f"opened={opened} closed_by_esc={closed}")
    page.set_viewport_size({"width": 1366, "height": 900})
    page.reload()
    page.wait_for_timeout(400)


def check_simulate(page, run, tours, warnings):
    if not page.evaluate("() => !!window.Simulate"):
        run.check("simulate", False, "no window.Simulate (the kit's engine is missing)")
        return
    for name in tours:
        before = len(warnings)
        page.evaluate(f"void Simulate.start('{name}')")
        page.wait_for_timeout(300)
        if not page.evaluate("Simulate.running"):
            run.check(f"simulate-{name}", False, "did not start (no such scenario?)")
            continue
        bar = page.is_visible("#simbar")
        prog = page.query_selector("#simprog") is not None   # attached: it is 0% wide on the first beat
        titles = []
        for _ in range(60):
            if not page.evaluate("Simulate.running"):
                break
            t = page.text_content("#sim-title") or ""
            if not titles or titles[-1] != t:
                titles.append(t)
            page.evaluate("Simulate.next()")
            page.wait_for_timeout(350)
        ended = not page.evaluate("Simulate.running")
        if not ended:
            page.evaluate("Simulate.stop()")
            page.wait_for_timeout(300)
        left_open = [o for o in page.evaluate(OPEN_OVERLAYS_JS) if is_open(page, o)]
        warns = warnings[before:]
        ok = bar and prog and ended and not warns and not left_open
        run.check(f"simulate-{name}", ok, f"{len(titles)} beats" if ok else
                  f"panel={bar} progress={prog} ended={ended} warnings={warns[:2]} open_after_exit={left_open}")


def check_presentation(page, run, tours, layout):
    if not page.evaluate("() => !!(window.Simulate && Simulate.present)"):
        run.check("presentation", False, "the kit has no presentation mode (Simulate.present)")
        return
    page.evaluate("Simulate.present(true)")
    page.evaluate(f"void Simulate.start('{tours[0]}')")
    page.wait_for_timeout(400)
    shown = page.evaluate("""() => [...document.querySelectorAll('[data-simulate], [data-simulate-run], [data-demo-only], #simbar, #simprog')]
      .filter(e => { const r = e.getBoundingClientRect(); return r.width > 0 && r.height > 0 && getComputedStyle(e).display !== 'none'; }).length""")
    nav_ok = layout != "app" or any(n.is_visible() for n in page.query_selector_all("[data-nav]"))
    foot = page.query_selector("footer")
    foot_ok = layout != "app" or bool(foot and foot.is_visible() and (foot.text_content() or "").strip())
    page.evaluate("Simulate.stop()")
    page.wait_for_timeout(300)
    page.evaluate("Simulate.present(false)")
    ok = shown == 0 and nav_ok and foot_ok
    run.check("presentation", ok, "" if ok else f"walkthrough controls visible={shown} navigation={nav_ok} footer disclosure={foot_ok}")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("target")
    ap.add_argument("--layout", choices=["app", "page"], default="app", help="page = a single-page layout the user asked for")
    ap.add_argument("--tours", default="short,full", help="comma-separated Simulate scenarios, or 'none'")
    ap.add_argument("--quiet", action="store_true", help="print failures only")
    a = ap.parse_args()
    tours = [] if a.tours == "none" else [t.strip() for t in a.tours.split(",") if t.strip()]
    run, errors, warnings = Run(a.quiet), [], []
    with sync_playwright() as p:
        browser = p.chromium.launch(args=["--mute-audio"])
        context = browser.new_context(viewport={"width": 1366, "height": 900})
        context.add_init_script(SILENT_JS)   # silent run: see SILENT_JS
        page = context.new_page()
        page.on("console", lambda m: errors.append(m.text) if m.type == "error" else
                (warnings.append(m.text) if m.type == "warning" and "[simulate]" in m.text else None))
        page.on("pageerror", lambda e: errors.append(str(e)))
        page.goto(target_url(a.target))
        page.wait_for_load_state("load")
        page.wait_for_timeout(300)
        if a.layout == "app":
            parts = {"menu items [data-nav]": len(page.query_selector_all("[data-nav]")) >= 2,
                     "theme switch": page.query_selector("[data-theme-toggle]") is not None,
                     "header": page.query_selector("header") is not None,
                     "footer": page.query_selector("footer") is not None}
            missing = [k for k, v in parts.items() if not v]
            run.check("app-shell", not missing, "missing: " + ", ".join(missing) if missing else "")
            run.guard("header-row", check_header, page, run)
        run.guard("contrast", check_contrast, page, run, a.layout)
        if a.layout == "app":
            run.guard("overlays", check_overlays, page, run)
            run.guard("mobile-drawer", check_mobile, page, run)
        if tours:
            run.guard("simulate", check_simulate, page, run, tours, warnings)
            run.guard("presentation", check_presentation, page, run, tours, a.layout)
        run.check("console", not errors, f"{len(errors)} errors: " + " | ".join(errors[:3]) if errors else "")
        browser.close()
    print(f"\n{'OK' if not run.failed else 'FAILED'}: {run.failed} check(s) failed")
    return 1 if run.failed else 0


if __name__ == "__main__":
    sys.exit(main())
