# PROGRESS.md — OpenAgentIsland work log

Chronological log. Newest first within each section. Architecture/design rationale
lives in `NOTES.md`.

---

## Current phase & status

**Phase 2 — Populate islands: LEFT DONE & VERIFIED (2026-06-03). Right island next.**
Left island: custom workspace indicator + compact active-window title, styled via a
shared `IslandStyle` singleton (space-black solid pill, white/blue accents, 4px
margin, 32px height). Now building the right island (resources · clock · battery ·
tray · wifi/bt) reusing end-4 widgets + the same `IslandStyle`.

Phase 1 (skeleton) done & verified earlier.

- Phase 0 (orient) complete and committed; nested dev window confirmed by user.
- Disabled the full-width `Bar` PanelLoader; added `IslandLeft` / `IslandNotch` /
  `IslandRight` PanelLoaders to `IllogicalImpulseFamily.qml`.
- Built three components in `modules/ii/island/`, each a `Scope { Variants { model:
  Quickshell.screens; PanelWindow {…} } }` → renders on every monitor. Transparent
  window bg, rounded themed pill (`colLayer0` + `colLayer0Border`,
  `rounding.full`), floating via layer-shell `margins` (8 px). Left anchored
  top-left, Notch top-center (top-only anchor → auto-centered), Right top-right.
- Static `"left"` / `"notch"` / `"right"` placeholder labels for now.
- Removed superseded `Island.qml`. Kept `IslandContent.qml` as the Phase-3 notch sketch.

**What works (expected):** three floating rounded pills at top-left / center / right,
wallpaper through the gaps, no full-width bar — on every monitor.
**What doesn't yet:** pills are static placeholders (no workspaces/clock/metrics);
notch doesn't morph. That's Phases 2–3.

---

## Done (newest first)

- **2026-06-03 — Phase 2 LEFT island.** Built the left island iteratively with the user:
  - `IslandWorkspaces.qml` (custom): a `Row` of uniform-spaced dots where the CURRENT
    workspace is a capsule (same height as dots) that **expands and pushes neighbours**
    apart → genuinely uniform gaps + fluid 280ms animation. Reuses end-4's Hyprland
    dispatch (`hl.dsp.focus`) + occupancy logic. Used dots = white, unused = faint,
    current = blue-tint. Scroll = switch ws, right-click = overview, left-click = focus.
    (Earlier tried bending the reused end-4 `Workspaces.qml` via override props, but
    fixed slots can't give uniform spacing around an elongated capsule — reverted that
    file to pristine and went custom.)
  - `ActiveWindow.qml`: added `compact` mode (single-line title, short "Desktop" idle
    label) — default off, so the disabled bar is unaffected.
  - `IslandStyle.qml` (singleton): shared tokens — solid space-black `#0B0B0E` pill,
    white text, `#8AB4F8` blue accent, 4px edge margin, 32px height, full radius. ALL
    islands use this for consistency.
  - Left-click pill → `sidebarLeftOpen`. Verified by user across several rounds of
    color/spacing/size tuning.

- **2026-06-03 — Phase 0 orientation.**
  - Read `~/Projects/island-reference/hyprfabricated/modules/notch.py` (995 lines) and
    `utils/animator.py`. Key finding: their notch "morph" is a GTK `Stack` with
    `set_interpolate_size(True)` swapping fixed-size children, NOT a width/height tween;
    the functional left/right clusters live in a separate full-width bar (we split those
    into two floating islands); single-window, no multi-monitor. animator.py is a
    hand-rolled cubic-bezier tick tween → replaced by native Qt `Behavior`/`easing`.
  - Wrote `NOTES.md` and `PROGRESS.md`.
  - **Surveyed current repo state:**
    - `panelFamilies/IllogicalImpulseFamily.qml`: full-width `Bar` PanelLoader ACTIVE;
      `// PanelLoader { component: Island {} }` commented out; `qs.modules.ii.island`
      already imported.
    - `modules/ii/island/` already contains a **prior-session sketch**:
      `Island.qml` (static 220×32 "island" pill, single `PanelWindow` in `Variants`,
      anchored top-center) and `IslandContent.qml` (volume-only state machine where
      `idle` is *invisible* and the trigger is `GlobalStates.osdVolumeOpen`). Both
      diverge from the target design (idle should be a minimal clock; trigger off the
      `Audio` value, not the flickering flag). Treat as a sketch to rewrite in Phase 3.
  - **Dev env confirmed present:**
    - Runtime symlink OK: `~/.config/quickshell/openagentisland` →
      `~/Projects/openagentisland/quickshell`.
    - Nested Hyprland config OK: `~/.config/hypr-nested/hyprland.conf`
      (monitor `WL-1 2560x1440@60`, `exec-once = qs -c openagentisland`,
      animations/blur disabled).
    - The live `ii` config is untouched (hard rule).

---

## Next

1. **User action:** launch the nested dev window and confirm `openagentisland` renders:
   `WLR_BACKENDS=wayland WLR_NO_HARDWARE_CURSORS=1 HYPRLAND_INSTANCE_SIGNATURE= Hyprland --config ~/.config/hypr-nested/hyprland.conf`
2. **Phase 1 — Floating skeleton:** disable the `Bar` PanelLoader; build
   `IslandLeft` / `IslandNotch` / `IslandRight` as three transparent rounded
   `PanelWindow`s, each in `Variants` over `Quickshell.screens`, anchored
   top-left/center/right with margins; register their PanelLoaders. Verify: three
   floating pills, wallpaper through the gaps, no bar — on every monitor.

---

## Blockers / open questions

- (Phase 6) Confirm `Quickshell.Io` 0.2.1 supports a listening socket +
  bidirectional/blocking writes from QML; if awkward, propose an external listener
  daemon to the user before building.
- Memory file `project_openagentland.md` describes this as a "fork of dynisland" —
  that is **stale/incorrect**; the actual project is Quickshell/QML on end-4 per
  `CLAUDE.md`. Trusting `CLAUDE.md` + the repo.

---

## Gotchas hit

- **⚠ HOT-RELOAD DOESN'T FIRE FROM CLAUDE'S FILE WRITES (critical, every phase).**
  Claude's Write/Edit tools save *atomically* (write temp + rename → new inode), and
  Quickshell's file watcher is on the old inode, so it never sees the change. Symptom:
  you edit a `.qml`, nothing updates in the nested window, and there's NO red error
  panel (suppressed by `//@ pragma Env QS_NO_RELOAD_POPUP=1` in `shell.qml`). Diagnosed
  via `qs -c openagentisland log` (shows "Configuration Loaded" only at launch, no
  reload). Also: a **plain `touch` does NOT reload** (mtime/IN_ATTRIB ignored); only a
  real content change (IN_MODIFY) does, and it must *persist* (append+immediate-truncate
  nets zero and gets coalesced → no reload).
  **Reliable reload nudge after editing QML** (in-place, then restore so git stays clean):
  ```bash
  bash -c "printf '%s\n' '// reload-nudge' >> ~/Projects/openagentisland/quickshell/shell.qml"
  sleep 2   # let Quickshell reload from current disk state
  cd ~/Projects/openagentisland/quickshell && git checkout shell.qml   # remove the nudge line
  ```
  When the **user** saves from their own editor, normal hot-reload works fine — this
  only affects Claude's tool-writes. `qs -c openagentisland log` is the way to read
  silenced QML errors (note the log/"Configuration Loaded" counter appears capped, so
  trust the screenshot + error lines, not the reload count).
- User shell is **fish** — no `<<EOF` heredocs; write files with tools or
  `printf`/`cat` inside `bash -c '...'`. (A chained `ls A B && find …` failed because
  fish/`ls` returned exit 2 when one path was missing and short-circuited the `&&`.)
- A prior session already scaffolded `modules/ii/island/` — check existing files before
  creating, to avoid clobbering or duplicating.
