# Product app: layout, themes and overlays

How a generated showcase or prototype is laid out, themed and checked. A polished single page
can still feel like slides; a product app feels like the real thing. Build this by default and
**don't ask about the look**. Switch to a single-page or presentation layout only when the user
explicitly asks for one. On the reproduce path, follow the source design instead.

## Contents
1. App shell
2. Themes
3. Overlay rules (default acceptance criteria)
4. Hooks the harness relies on
5. Checking it

## 1. App shell
- **Left menu, collapsible.** An icon and a label per item; collapsing leaves an icon rail with
  tooltips. Show progress where the product has it: a count, a status dot or a completion meter
  per item, so the menu reads as a live product.
- **Header.** A breadcrumb (`Overview › Claims › CLM-2041`), a search opened with **Ctrl+K**
  (**⌘K** on macOS) that jumps to screens and records, notifications (a bell with a count and a
  panel), a light/dark switch, and a user menu (name or role, persona switch if the prototype has
  personas, settings, sign out as a no-op). The `▶ Simulate` button sits at the right end.
- **Footer.** The data date (`Data as of 14 Nov 2026`) and the persistent simulated-data
  disclosure. The disclosure stays in every mode, presentation mode included.
- **Overview home screen.** The landing view: the few numbers that matter, what needs attention,
  and an entry point to each main flow.
- **Phones (≤760px).** The menu becomes a slide-out drawer opened from a menu button in the
  header; the header keeps the essentials on one row.

## 2. Themes
- Build **light and dark from the start**, with theme tokens from day one: every colour comes from
  a token on `:root[data-theme="light"]` and `:root[data-theme="dark"]`. The first load follows
  `prefers-color-scheme`; the switch overrides it for the session.
- **Separate solid backgrounds from ink.** Background tokens (`--bg`, `--surface`, `--surface-2`,
  `--accent-bg`) are only ever fills; ink tokens (`--ink`, `--ink-2`, `--ink-muted`,
  `--accent-ink`, `--on-accent`) are only ever text, icons and strokes. One accent colour rarely
  works as both a fill and readable text in both themes, so it gets one token of each kind.
- **Contrast, on every screen in both themes:** at least 4.5:1 for text, and 3:1 for large text
  (24px, or 18.66px bold). It is checked automatically as part of the gate (§5), not by eye.

## 3. Overlay rules (default acceptance criteria)
Overlays are the search, menus (user, notifications), side panels, dialogs and the mobile menu.
1. Only one overlay is open at a time: opening one closes the others.
2. `Esc` closes the topmost one (and calls `preventDefault()`, so a running Simulate tour stays
   on).
3. Focus returns to the button that opened it.
4. `Tab` stays inside an open dialog.
5. Keyboard shortcuts (the host's and the Simulate kit's) are ignored while the viewer is typing in
   a field.
6. Reset and Simulate exit close everything: map the kit's `CONFIG.closeAll` to the prototype's
   own close-all function.

## 4. Hooks the harness relies on
Plain ARIA and three data attributes, so the checks work on any prototype:
- each menu item that opens a screen carries `data-nav="<screen-id>"`, and the active one carries
  `aria-current="page"`;
- the theme lives on `<html data-theme="light|dark">`, and the switch carries `data-theme-toggle`;
- every overlay opener has `aria-controls="<overlay-id>"` and an up-to-date `aria-expanded`;
  a closed overlay is `hidden` (or `display:none`);
- dialogs carry `role="dialog"` and `aria-modal="true"`;
- the scenario menu items (in the user or help menu) carry `data-simulate-run="short"` and
  `"full"`, and anything only a demo needs carries `data-demo-only` (presentation mode hides both);
- the search opener also opens on Ctrl+K and focuses its input.

## 5. Checking it
Run the bundled harness when Python Playwright is available
(`pip install playwright` and `python -m playwright install chromium` once):

```
python <skill>/assets/check-prototype.py showcase/<use-case>/v<N>.html
```

It opens the file muted, visits every screen in both themes, checks contrast, the overlay rules,
the phone drawer, the header row, both Simulate scenarios and presentation mode, and fails on any
console error. Add `--layout page` for a single-page layout the user asked for, and `--tours none`
when the prototype has no Simulate tour. Text over an image or gradient can't be measured: put a
solid scrim behind it, or check it by eye, rerun with `--allow-unverified` and say so in the
handoff. Without Python,
run the same checks through the Playwright MCP (`ait-prototype-testing`); the harness's check list
is the checklist, and its `CONTRAST_JS` snippet runs as-is in `browser_evaluate`.

When a new version changes a behaviour on purpose, update the checks that encoded the old one
(and say so in `v<N>-changes.md`); never weaken a check to make a regression pass.
