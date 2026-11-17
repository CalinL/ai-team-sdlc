#!/usr/bin/env python3
# Created by Calin Lupas with AI assistance. Credits: the repository's README.md (Authors and credits) and NOTICE.
"""Reusable browser checks for a showcase or prototype built as a product app (references/product-app.md).

Usage:  python check-prototype.py <file.html | URL> [--layout app|page] [--tours short,full|none]
                                 [--allow-unverified] [--quiet]
        --tours none when the prototype has no Simulate tour; --layout page for a single-page layout.
Needs:  pip install playwright && python -m playwright install chromium

Checks (each prints PASS/FAIL; exit code 1 on any FAIL):
  app-shell        menu items [data-nav], theme switch [data-theme-toggle], header, footer, Ctrl+K search
  header-row       the header's controls sit on one row (also at phone width: header-row-phone)
  contrast-<theme> every screen in both themes: text >= 4.5:1, large text >= 3:1 (text over images or
                   gradients can't be measured and fails unless --allow-unverified)
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
import re
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
    // Composite the text pixel and the background pixel through every ancestor: each one's background
    // goes under both, and its opacity fades both (group opacity), down to a white canvas.
    let tp = rgba(svg && cs.fill && !cs.fill.startsWith("url") ? cs.fill : cs.color), bp = [0, 0, 0, 0], unknown = false, gone = false;
    const cx = r.left + r.width / 2, cy = r.top + r.height / 2;
    for (let e = el; e; e = e.parentElement) {
      const s = getComputedStyle(e);
      if (+s.opacity === 0) { gone = true; break; }      // inside an invisible container (e.g. a hidden toast)
      // A label positioned outside its parent (a chart axis label) is not painted on that parent.
      if (e !== el && e !== document.body && e !== document.documentElement) {
        const a = e.getBoundingClientRect();
        if (cx < a.left || cx > a.right || cy < a.top || cy > a.bottom) { const o = +s.opacity; if (o < 1) { tp[3] *= o; bp[3] *= o; } continue; }
      }
      // An image or gradient matters only while the layers above it are still see-through.
      if (s.backgroundImage !== "none" && bp[3] < 0.999) { unknown = true; break; }
      const b = rgba(s.backgroundColor); tp = over(tp, b); bp = over(bp, b);
      const o = +s.opacity; if (o < 1) { tp[3] *= o; bp[3] *= o; }
    }
    if (gone) continue;
    if (unknown) { skipped++; continue; }
    tp = over(tp, [255, 255, 255, 1]); bp = over(bp, [255, 255, 255, 1]);
    const c = ratio(tp, bp), size = parseFloat(cs.fontSize), bold = +cs.fontWeight >= 700;
    const need = size >= 24 || (bold && size >= 18.66) ? 3 : 4.5; checked++;
    if (c < need) fails.push({ text: n.textContent.trim().slice(0, 40), ratio: +c.toFixed(2), need,
      where: (el.id ? "#" + el.id : el.tagName.toLowerCase() + (el.className && typeof el.className === "string" ? "." + el.className.trim().split(/\s+/)[0] : "")) });
  }
  return { checked, skipped, fails };
}"""

# Overlays that are actually visible, whatever their openers' aria-expanded says. Only overlays whose
# opener is visible count (on a desktop, the menu a hidden phone button controls is not an overlay).
OPEN_OVERLAYS_JS = """() => { const vis = e => { if (!e) return false; const s = getComputedStyle(e), r = e.getBoundingClientRect();
    return !e.hidden && s.display !== 'none' && s.visibility !== 'hidden' && r.width > 0 && r.height > 0
      && r.right > 0 && r.bottom > 0 && r.left < innerWidth && r.top < innerHeight; };
  return [...new Set([...document.querySelectorAll('[aria-controls][aria-expanded]')]
    .filter(o => vis(o) && !o.closest('.simbar, [data-simulate], [data-simulate-run]')).map(o => o.getAttribute('aria-controls')))]
    .filter(id => vis(document.getElementById(id))); }"""
ARIA_MISMATCH_JS = """() => [...document.querySelectorAll('[aria-controls][aria-expanded]')].filter(o => o.getBoundingClientRect().width > 0)
  .filter(o => { const e = document.getElementById(o.getAttribute('aria-controls')); if (!e) return false;
    const s = getComputedStyle(e), r = e.getBoundingClientRect(), open = !e.hidden && s.display !== 'none' && s.visibility !== 'hidden'
      && r.width > 0 && r.right > 0 && r.bottom > 0 && r.left < innerWidth && r.top < innerHeight;
    return (o.getAttribute('aria-expanded') === 'true') !== open; }).map(o => o.getAttribute('aria-controls'))"""
# Shown = rendered AND on screen: a drawer slid off-canvas with a transform is closed.
VISIBLE_JS = """id => { const e = document.getElementById(id); if (!e) return false;
  const s = getComputedStyle(e), r = e.getBoundingClientRect(); return !e.hidden && s.display !== 'none' && s.visibility !== 'hidden'
    && r.width > 0 && r.height > 0 && r.right > 0 && r.bottom > 0 && r.left < innerWidth && r.top < innerHeight; }"""


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


FORCE_CLOSE_JS = """ids => ids.forEach(id => { const e = document.getElementById(id); if (!e) return; e.hidden = true;
  e.classList.remove('open', 'show', 'active'); document.querySelectorAll(`[aria-controls="${id}"]`).forEach(o => o.setAttribute('aria-expanded', 'false')); })"""


def close_all(page):
    """Esc until no overlay shows; if Esc can't close one (already reported), hide it so later checks still run."""
    for _ in range(4):
        if not page.evaluate(OPEN_OVERLAYS_JS):
            return
        page.keyboard.press("Escape")
        page.wait_for_timeout(120)
    page.evaluate(FORCE_CLOSE_JS, page.evaluate(OPEN_OVERLAYS_JS))


def set_theme(page, want):
    for _ in range(3):
        if page.evaluate("document.documentElement.dataset.theme") == want:
            return True
        page.click("[data-theme-toggle]")
        page.wait_for_timeout(150)
    return page.evaluate("document.documentElement.dataset.theme") == want


def visit(page, screen):
    """Opens a screen from the menu and waits until its item is marked aria-current (proof it is active)."""
    item = page.locator(f'[data-nav="{screen}"]').first
    try:
        item.click(timeout=3000)
    except Exception:  # noqa: BLE001 - covered or collapsed: a programmatic click still exercises the handler
        item.evaluate("e => e.click()")
    try:
        page.wait_for_selector(f'[data-nav="{screen}"][aria-current]:not([aria-current="false"])', state="attached", timeout=3000)
        return True
    except Exception:  # noqa: BLE001
        return False


def check_contrast(page, run, layout, allow_unverified):
    screens = list(dict.fromkeys(page.eval_on_selector_all("[data-nav]", "es => es.map(e => e.dataset.nav)"))) if layout == "app" else []
    toggle = page.query_selector("[data-theme-toggle]") is not None
    for theme in ("light", "dark") if layout == "app" or toggle else ("current",):
        if theme != "current" and not set_theme(page, theme):
            run.check(f"contrast-{theme}", False, "could not switch theme with [data-theme-toggle]")
            continue
        fails, checked, skipped = {}, 0, 0
        for screen in screens or ["page"]:
            if screen != "page":
                close_all(page)
                if not visit(page, screen):
                    fails.setdefault(f"the menu item never became aria-current, so the screen was not verified", screen)
                    continue
                page.wait_for_timeout(200)
            res = page.evaluate(CONTRAST_JS)
            checked += res["checked"]
            skipped += res["skipped"]
            if not res["checked"]:
                fails.setdefault(f"no text could be measured", screen)
            for f in res["fails"]:
                fails.setdefault(f"{f['where']} '{f['text']}' {f['ratio']}:1 < {f['need']}:1", f"{screen}")
            # Every overlay this screen offers (its own and the header's), opened one at a time.
            for i in range(len(openers(page)) if layout == "app" else 0):
                close_all(page)
                ops = openers(page)   # re-acquired each time: opening and closing may re-render
                if i >= len(ops):
                    break
                h, oid = ops[i]
                h.click(timeout=3000)
                page.wait_for_timeout(200)
                if not is_open(page, oid):
                    continue   # the overlay check reports it
                res = page.evaluate(CONTRAST_JS)
                checked += res["checked"]
                skipped += res["skipped"]
                for f in res["fails"]:
                    fails.setdefault(f"{f['where']} '{f['text']}' {f['ratio']}:1 < {f['need']}:1", f"{screen} with #{oid} open")
            close_all(page)
        if skipped and not allow_unverified:
            fails.setdefault(f"{skipped} text element(s) over images or gradients cannot be measured: put a solid scrim behind "
                             "them, or check them by eye and rerun with --allow-unverified (record that in the handoff)", "page")
        detail = f"{checked} text elements measured, {skipped} over images/gradients" + (" accepted as checked by eye" if skipped else "")
        name = "contrast" if theme == "current" else f"contrast-{theme}"
        if theme == "current":
            detail += "; one theme only (no [data-theme-toggle])"
        run.check(name, not fails, detail if not fails else f"{len(fails)} failing: " + "; ".join(f"{k} (first on {v})" for k, v in list(fails.items())[:6]))


def check_overlays(page, run):
    page.reload()   # a clean page: nothing left over from the contrast pass
    page.wait_for_timeout(400)
    close_all(page)
    ops = openers(page)
    if not ops:
        run.check("overlays", False, "no overlay openers ([aria-controls][aria-expanded]) found")
        return
    problems, tested = [], set()

    def test_opener(h, oid):
        tested.add(oid)
        h.focus()
        h.click()
        page.wait_for_timeout(150)
        if not is_open(page, oid) or h.get_attribute("aria-expanded") != "true":
            problems.append(f"#{oid} did not open with aria-expanded=true")
            close_all(page)
            return
        if page.evaluate("id => document.getElementById(id).matches('[role=dialog][aria-modal=true]')", oid):
            stops = page.evaluate("""id => document.getElementById(id).querySelectorAll('a[href], button, input, select, textarea, [tabindex]:not([tabindex="-1"])').length""", oid)
            for _ in range(min(stops + 2, 80)):   # one full cycle and then some
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

    for h, oid in ops:
        test_opener(h, oid)
    # Overlays that only some screens offer (a dialog on a detail screen, a filter panel).
    for screen in page.eval_on_selector_all("[data-nav]", "es => [...new Set(es.map(e => e.dataset.nav))]"):
        close_all(page)
        if not visit(page, screen):
            continue
        page.wait_for_timeout(150)
        for i in range(len(openers(page))):
            close_all(page)
            now = openers(page)
            if i < len(now) and now[i][1] not in tested:
                test_opener(*now[i])
    close_all(page)
    page.reload()
    page.wait_for_timeout(400)
    ops = openers(page)
    for (a, aid), (b, bid) in zip(ops, ops[1:]):
        close_all(page)
        a.click()
        page.wait_for_timeout(120)
        b.evaluate("e => e.click()")
        page.wait_for_timeout(150)
        still = page.evaluate(OPEN_OVERLAYS_JS)
        if len(still) > 1:
            problems.append(f"#{aid} and #{bid} open at once")
        bad = page.evaluate(ARIA_MISMATCH_JS)
        if bad:
            problems.append(f"aria-expanded disagrees with what is shown for #{', #'.join(bad)}")
    close_all(page)
    other = next(((h, oid) for h, oid in ops if page.evaluate("id => !document.getElementById(id).querySelector('input, textarea')", oid)), None)
    if other:   # Ctrl+K while another overlay is open must leave only the search open
        other[0].click()
        page.wait_for_timeout(150)
    page.keyboard.press("Control+k")
    page.wait_for_timeout(200)
    typing = page.evaluate("() => { const a = document.activeElement; return !!a && (/^(INPUT|TEXTAREA)$/.test(a.tagName) || a.isContentEditable); }")
    if not typing:
        problems.append("Ctrl+K did not open search with its input focused")
    elif len(page.evaluate(OPEN_OVERLAYS_JS)) > 1:
        problems.append("Ctrl+K left another overlay open")
    run.check("overlays", not problems, f"{len(tested)} overlays" if not problems else "; ".join(problems))
    running = False
    if typing:
        page.keyboard.type("x")
        page.keyboard.press("Control+Alt+2")
        page.wait_for_timeout(250)
        running = page.evaluate("() => !!(window.Simulate && Simulate.running)")
        if running:
            page.evaluate("Simulate.stop()")
    close_all(page)
    # The host's own shortcuts: typing in an ordinary field, Ctrl+K must not open anything.
    find_field = """() => { const overlays = [...document.querySelectorAll('[aria-controls]')]
        .map(o => document.getElementById(o.getAttribute('aria-controls'))).filter(Boolean);
      return [...document.querySelectorAll('input:not([type=hidden]):not([type=checkbox]):not([type=radio]), textarea')]
        .find(e => e.getBoundingClientRect().width > 0 && !e.closest('[role=dialog]') && !overlays.some(o => o.contains(e))) || null; }"""
    field = page.evaluate_handle(find_field)
    if not field.as_element():   # look for an ordinary field on every screen
        for screen in page.eval_on_selector_all("[data-nav]", "es => [...new Set(es.map(e => e.dataset.nav))]"):
            if visit(page, screen):
                page.wait_for_timeout(150)
                field = page.evaluate_handle(find_field)
                if field.as_element():
                    break
    host_ok, note = True, ""
    if field.as_element():
        field.as_element().focus()
        page.keyboard.type("x")
        page.keyboard.press("Control+k")
        page.wait_for_timeout(200)
        host_ok = not page.evaluate(OPEN_OVERLAYS_JS)
        note = "" if host_ok else "Ctrl+K opened an overlay while typing in a field"
        close_all(page)
    else:
        note = "no ordinary field on any screen, so the host's shortcuts were not tested while typing"
    problems_t = [m for m in ("no field to type in (Ctrl+K search did not focus one)" if not typing else "",
                              "Ctrl+Alt+2 while typing started a tour" if running else "",
                              note if not host_ok else "") if m]
    run.check("typing", not problems_t, "; ".join(problems_t) if problems_t else note)


def check_header(page, run, name="header-row"):
    spans = page.evaluate("""() => { const h = document.querySelector('header'); if (!h) return null;
      return [...h.querySelectorAll('button, a, input, [role=button], nav')].filter(e => { const r = e.getBoundingClientRect();
        return r.width && r.height && getComputedStyle(e).visibility === 'visible'; }).map(e => { const r = e.getBoundingClientRect(); return [r.top, r.bottom]; }); }""")
    if spans is None:
        run.check(name, False, "no <header>")
        return
    ok = bool(spans) and min(b for _, b in spans) > max(t for t, _ in spans)
    run.check(name, ok, f"{len(spans)} controls" + ("" if ok else " wrap onto more than one row"))


def check_mobile(page, run):
    page.set_viewport_size({"width": 390, "height": 844})
    page.reload()
    page.wait_for_timeout(400)
    close_all(page)
    check_header(page, run, "header-row-phone")
    on_screen = "e => { const r = e.getBoundingClientRect(); return r.width > 0 && r.right > 0 && r.left < innerWidth && r.bottom > 0 && r.top < innerHeight; }"
    navs = [n for n in page.query_selector_all("[data-nav]") if n.is_visible() and n.evaluate(on_screen)]
    drawer = [(h, oid) for h, oid in openers(page)
              if page.evaluate("id => !!document.getElementById(id) && !!document.getElementById(id).querySelector('[data-nav]')", oid)]
    if navs or not drawer:
        run.check("mobile-drawer", False, "menu items visible at 390px" if navs else "no menu button controlling the menu")
    else:
        h, oid = drawer[0]
        h.click()
        page.wait_for_timeout(300)
        page.wait_for_timeout(300)   # let a slide-in transition finish
        opened = is_open(page, oid) and any(n.is_visible() and n.evaluate(on_screen) for n in page.query_selector_all("[data-nav]"))
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
        left_open = page.evaluate(OPEN_OVERLAYS_JS)
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
    try:   # wait for a spotlight to exist, so the "no outline in presentation mode" check can fail
        page.wait_for_selector(".simfocus", state="attached", timeout=4000)
    except Exception:  # noqa: BLE001 - a tour without hl() simply has no spotlight to check
        pass
    # By display, not size: the progress line is 0% wide on the first beat.
    shown = page.evaluate("""() => [...document.querySelectorAll('[data-simulate], [data-simulate-run], [data-demo-only], #simbar, #simprog')]
      .filter(e => getComputedStyle(e).display !== 'none' && getComputedStyle(e).visibility !== 'hidden').length
      + [...document.querySelectorAll('.simfocus')].filter(e => getComputedStyle(e).outlineStyle !== 'none').length""")
    nav_ok = layout != "app" or any(n.is_visible() for n in page.query_selector_all("[data-nav]"))
    foot = page.query_selector("footer")
    foot_ok = layout != "app" or bool(foot and foot.is_visible() and re.search(r"simulat|synthetic|sample|mock|fictional|fictitious|illustrative|demo",
                                                                                  foot.text_content() or "", re.I))
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
    ap.add_argument("--allow-unverified", action="store_true", help="accept text over images/gradients, checked by eye")
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
        run.guard("contrast", check_contrast, page, run, a.layout, a.allow_unverified)
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
