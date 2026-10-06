# Simulate: a voice-narrated guided walkthrough

The `Simulate` button turns a showcase prototype into a self-running product demo. A narrator voice
tells the story while the prototype performs each step on screen. A **live demo panel**, docked at
the bottom, shows the transcript, progress and presenter controls.

**Start from the kit.** [`../assets/simulate-kit.html`](../assets/simulate-kit.html) is a runnable
single-file reference. Open it in Edge and press **▶ Simulate**. It has three marked blocks:
`SIMULATE · CSS`, `SIMULATE · BUTTON` and `SIMULATE · ENGINE`. Copy them into the prototype and edit
only the engine's `CONFIG` section. Do not rebuild the engine; its cancellation, pause and restore
logic is the part that is easy to get subtly wrong.

## Contents
1. What the viewer sees
2. Voice
3. Engine model
4. Integrating into a prototype
5. Writing the narration
6. Verification checklist
7. Gotchas

## 1. What the viewer sees
- **Simulate button.** It sits prominent at the top right of the top bar, filled with the accent
  colour: `▶ Simulate`. While running it flips to `✕ Exit`.
- **Progress hairline.** A 2px accent bar runs across the top of the viewport and fills per beat.
- **Live demo panel** (`.simbar`). It is fixed at the bottom centre, `min(940px, 94vw)` wide, on an
  elevated, rounded, blurred surface. From left to right:
  - **Badge.** An accent pill such as `GUIDED PROTOTYPE · SIMULATED DATA`, with a three-bar
    equaliser that animates only while the voice speaks.
  - **Transcript.** The beat title in bold over the full narration sentence, then the step dots
    (done, current, upcoming). Bonus beats get a `BONUS` tag, a tinted border, and a **seam** in the
    dots, so a presenter knows where the main story ends.
  - **Controls.** `🔊` mute, `⏸`/`▶` pause, `Next ⏭` and `✕` exit. Keyboard: `Esc` exits; `→`
    goes to the next beat and `Space` pauses, but neither fires while the viewer is typing in a
    field.
- **Spotlight** (`.simfocus`). The element being discussed gets a pulsing accent outline and
  scrolls to the centre of the view.
- **Toasts** move to the top while simulating so the panel never covers them.
- **Mobile (≤760px).** The controls wrap above the transcript. The transcript clamps to two lines
  and expands on tap or keyboard. Only at this width is the transcript a toggle button; on desktop
  it is plain text and not a tab stop.

## 2. Voice
The kit uses the Web Speech API (`speechSynthesis`), with no keys or libraries.
- **Preferred voice:** `Microsoft Jenny Online (Natural) - English (United States)`, which ships with
  Microsoft Edge. It is first in the kit's `VOICE_PREF` list, matched by substring. Change that list
  only if the user asks for a different voice.
- **English first.** The kit filters to English voices *before* ranking. The fallbacks are Aria →
  Sonia → Libby → any `Natural` → Samantha → Serena → Google English → Hazel → Zira → any `en-US` →
  any English. With no English voice it lets the browser choose with `lang = en-US`.
- **Online voices** (names containing "Online") are synthesised by a cloud service. They need
  connectivity and send the narration text to that service. If one errors, the kit switches to
  local voices only for the session; with no local English voice it narrates silently (transcript
  only). Mention this in the handoff when the demo may run
  offline or the narration is sensitive.
- **Delivery:** `rate .92` and `pitch 1.05`, which reads as calm and deliberate. `·`, `—` and `–`
  become commas, so they are spoken as pauses rather than read aloud.
- **No TTS:** the mute button is hidden, the tour runs silently on each beat's minimum time, and the
  transcript becomes a polite live region.
- **Edge is recommended** for live demos; say so in the handoff.

## 3. Engine model
A walkthrough is an ordered array of **beats**:

```js
{ t: "Act 1 · Ask once",          // title shown in the panel
  n: "So she asks. Watch …",      // narration: spoken AND shown as the transcript
  d: 11000,                        // minimum un-paused ms the beat stays on screen
  r: async () => { … },            // stage actions, using the helpers below
  extra: true,                     // optional: a bonus beat after the main story
  last: true }                     // optional: hold 2.5s longer on the final frame
```

For each beat, the engine:
1. updates the panel;
2. starts speech **and** stage actions in parallel;
3. waits until the speech has finished **and** `d` ms of un-paused time have passed since the beat
   started;
4. moves on.

A backstop cancels speech if the engine never fires `onend`.

- **Clock.** All timing uses the engine's own pause-aware clock, so a pause freezes both speech and
  choreography, and paused time never counts towards `d`.
- **Next** finishes the current beat's choreography instantly and advances. If the tour is paused,
  Next also resumes it.
- **Exit** cancels the run. The next `wait()` throws a private stop signal, so no pending stage
  action fires after the viewer's state has been restored. Cleanup and restore happen once, by the
  run that owns the snapshot. A rapid restart cannot leave two runs alive.
- **Errors.** A step that throws ends the tour cleanly and logs
  `console.error("[simulate] step failed:", title, error)`. It is never swallowed, so verification
  catches it.

**Helpers** are passed into `CONFIG.steps`. Use them, rather than raw `setTimeout`, inside `r`, so
pause, Next and Exit stay in control:
- `wait(ms)` is a pause-aware delay. It returns early on Next and aborts on Exit.
- `hl(selectorOrElement | null)` spotlights and scrolls into view; `null` clears the spotlight. A
  missing target logs a warning.
- `typeInto(selector, text, msPerChar?)` types visibly and fires `input` events. Next completes it;
  Exit aborts it.
- `click(selectorOrElement)` spotlights briefly, then clicks. A missing target is a no-op with a
  warning.

## 4. Integrating into a prototype
1. **CSS.** Paste `SIMULATE · CSS` into the prototype's `<style>`. It reads the theme tokens
   (`--accent`, `--info`, `--surface-*`, `--line-2`, `--tx*`, `--r-*`, `--sh-2`) and has fallbacks.
   Map the tokens rather than editing the rules. White text sits on `--accent` (button, badge) and
   `--sim-bonus-bg` (BONUS label), so both need ≥ 4.5:1 contrast with white.
   - `--sim-z` (default 1000) sets the stacking level.
   - `--sim-safe` (default 150px) is the space reserved at the bottom of `body` while simulating. If
     the prototype scrolls an inner container instead of the page, give that container the same
     padding under `body.simming`.
   - Rename the `.toast` rules to the prototype's toast class, or delete them if it has none.
2. **Button.** Put `SIMULATE · BUTTON` in the top bar. Any element with `data-simulate` is a trigger,
   so a second entry scene (a landing or host-app screen) can carry its own button. You may swap
   `.sim-trigger` for the prototype's primary-button class.
3. **Engine.** Paste `SIMULATE · ENGINE` after the prototype's own script. It is an IIFE: it declares
   no globals except `window.Simulate` (`start`, `stop`, `next`, `pause`, `running`), and it does
   not depend on the host's `$`/`$$` helpers. Edit only `CONFIG`:
   - `badge` — keep it honest: say "simulated data" when any data is invented; use wording such as "sample data" only when the user supplied all of it.
   - `snapshot()` / `restore(s)` — the tour switches personas, views and filters, and exiting must
     put the viewer back exactly where they were. Also close any modal or drawer a beat opens.
   - `restoreOnFinish` — `true` returns to the snapshot after a full run; `false` stays on the
     final frame.
   - `steps({ wait, hl, typeInto, click })` — returns the beats (see §5).
4. **Drive the real UI.** Call the prototype's own navigation, render and click handlers, so the
   walkthrough exercises the same code paths a user would.
5. **Keep it self-contained.** Use no external scripts and no `fetch`, so it plays from `file://`
   and from shared downloads.

## 5. Writing the narration
The narration is the demo. Write it like a presenter, not a tooltip.
- **Tell the story in acts**, using only those the source supports (skip an act rather than invent
  a pain, number or persona).
  1. "This is today": the pain, with one hard number.
  2. *Act 1*: the core flow working.
  3. The moment it would fail elsewhere, and doesn't.
  4. The most important other persona's view. Cover any further personas, and how each one
     personalises or configures the product, in bonus beats or the montage, so every persona the
     prototype shows appears somewhere in the tour.
  5. The outcome over time.
  6. **The ask**: the decision you want from the room.

  Then add optional `extra` bonus beats for breadth, such as a quick montage of the remaining
  features. Keep the main story to about 3 minutes; cover the remaining screens and personas in
  bonus beats or the montage.
- **Perform, don't assert.** If a beat says something happens, the screen must show it happening.
- **Land on the strongest in-scope moment.** Pick the most compelling thing the prototype actually
  does. Never add a feature just to have a moment to narrate.
- **One idea per beat:** about 25–60 words, or 9–24 seconds. Aim for a main story of about 3
  minutes, with bonus beats of 10–20 seconds each.
- **Spell numbers the way they should be heard,** for example "seventy-one per cent".
- **Point at what you name:** `hl()` every noun the narrator emphasises at that moment.
- **Honesty:** the prototype's persistent simulated-data disclosure covers invented figures, so
  per-figure caveats are not needed; never present simulated outcomes as verified real results.
- **The main story must stand alone.** A presenter who stops at the seam loses nothing structural.

## 6. Verification checklist
Run this with `ait-prototype-testing` (Playwright MCP). Serve over `http://` if the MCP blocks
`file://`.
- [ ] `▶ Simulate` is visible on load. Clicking it shows the panel, the hairline and the first beat.
- [ ] Every `hl()`/`click()` target exists, with no `[simulate] … not found` warnings.
- [ ] Next, pause/resume, mute and `Esc` each respond within about 150ms.
- [ ] **Exit during a beat's actions** restores the snapshot, and nothing changes afterwards (wait
      about 5s and re-check).
- [ ] **Rapid restart** (Exit then Simulate quickly) leaves exactly one panel and one running tour.
- [ ] **Pause** holds the current beat for 10s or more; **Next while paused** resumes and advances.
- [ ] A full run completes with **0 console errors**, the button returns to `▶ Simulate`, and focus
      returns to the trigger.
- [ ] The panel never hides the spotlighted element.
- [ ] At mobile width, the transcript clamps and expands, and the controls are reachable.
- [ ] If persona or theme switches exist, the tour works from each supported persona and in each
      supported theme, with the panel, icons and highlights legible throughout. Do not add personas
      or themes just to satisfy this check.
- [ ] Headless browsers have no voices, so confirm the silent path paces correctly. Hearing the
      actual voice is a **manual** check in Edge. Record it as verified or not verified in the
      handoff, and never claim it without hearing it.

## 7. Gotchas
- `speechSynthesis` requires a user gesture, which is why the tour starts only from the button.
- Chrome may stop a long utterance after about 15 seconds. Keep beats short; the backstop is only a
  safety net.
- `speechSynthesis.pause()` is unreliable on some engines. The engine also freezes its own clock, so
  the visual tour still pauses correctly.
- The kit cancels speech on exit and on `pagehide`, so the voice never outlives the panel.
- Kit classes are prefixed `sim` (`simbar`, `sim-text`, `simfocus` and so on) to avoid colliding
  with the prototype's styles.
