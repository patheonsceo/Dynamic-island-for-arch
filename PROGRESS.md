# PROGRESS.md — OpenAgentIsland work log

Chronological log. Newest first within each section. Architecture/design rationale
lives in `NOTES.md`.

---

## Current phase & status

**Phases 0–5 DONE. Expansion phases A–H DONE (2026-06-05) — code-complete &
compiling clean; awaiting user visual test in the nested window. Next: Phase 6 —
agent bridge.**

The notch `open` state is now a **surface host** (see NOTES.md): an `Island`
singleton holds `openSurface` and side-island pills command the centre notch to
open one of 5 surfaces — `dashboard` (Widgets/Kanban/Coming-soon tabs), `power`,
`tools`, `launcher`, `overview`. Built in ROADMAP.md phases A–H:
- **A** surface host + dashboard tab shell (Ctrl+Tab nav, per-surface sizes).
- **B** Widgets tab: media card, Wi-Fi/BT/Night/Caffeine toggles, vol+mic
  sliders, calendar, notifications, power-profile selector, live CPU/RAM/Swap bars.
- **C** Kanban tab (3 cols, JSON-persisted, inline edit, drag between columns).
- **D** Power surface (Lock/Night/Logout/Reboot/Shutdown, kbd+mouse). USECASE 1.
- **E** Tools surface (region/full/window screenshot via hyprshot, record via
  wf-recorder, hyprpicker). USECASE 2.
- **F** Launcher surface (AppSearch fuzzy apps+settings, kbd nav). USECASE 4.
- **G** Overview surface (live WS 1-10 icon grid, click focus / RMB close / drag
  to move via vanilla Hyprland dispatchers). USECASE 4.
- **H** Left island rebuilt to 5 pills (search · workspaces · weather · overview ·
  network), title dropped; weather pill (wttr.in °C) + network pill (/proc/net/dev
  hover throughput). Pill bg → pure pitch black. Click-absorber so open surfaces
  don't close on inner clicks (close via Esc / re-click trigger pill).

Right island: power pill → `Island.toggle("power")`; new pencil pill →
`Island.toggle("tools")`.

All styled via `IslandStyle`. Notch reserves a 40px top strip (`exclusiveZone`).

**NEXT:** user tests A–H visually, then **Phase 6 agent bridge** (live Claude Code
status in the notch + permission round-trip).

---

## Done (newest first)

- **2026-06-05 — Expansion phases A–H (notch surfaces + side islands).** Built the
  whole reference feature set ahead of the agent work; each phase compiled clean
  (verified via reload log + force-opening each surface) and committed separately
  (commits Phase A `45c8fe8` → Phase H). New files under `modules/ii/island/`:
  `Island` (bus singleton), `DashboardSurface`/`DashboardPlaceholder`,
  `WidgetsPane`/`WidgetCalendar`, `KanbanStore`/`KanbanPane`, `PowerSurface`,
  `ToolsSurface`, `LauncherSurface`, `OverviewSurface`, `IslandWeatherPill`,
  `IslandNetworkPill`. `IslandNotch` open state → Loader surface-host; `IslandLeft`
  rebuilt to 5 pills (title dropped); `IslandRight` gained pencil pill + power→surface.
  Gotchas hit:
  - **New-file reload race:** adding a new surface file + editing IslandNotch to
    reference it in the SAME reload nudge yields a transient `X is not a type`
    "Failed to load" pass, immediately followed by a successful "Configuration
    Loaded". The `Component { X {} }` wrapper forces X to be a valid type for the
    config to load at all, so a trailing `Configuration Loaded` proves it resolved
    — trust the LAST line; the interleaved error is stale (its line:col often no
    longer even points at the Component after later edits).
  - **PowerProfilesDaemon not running** on this box → mode selector shows default
    and `powerprofilesctl set` is a harmless no-op (env, not a bug).
  - **end-4 `hl.dsp.*` dispatchers are plugin-only** (invalid in vanilla Hyprland)
    — OverviewSurface uses standard `focuswindow`/`closewindow`/
    `movetoworkspacesilent`/`workspace` instead.
  - **Cross-cell/column drag** (kanban + overview): avoided Repeater-delegate
    reparenting; instead arm after 8px, show a floating proxy, and on release map
    cursor position → target cell/column. Robust without z-order fighting.

- **2026-06-05 — Phase 5 media + cava visualizer (notch).**
  - One shared cava `Process` at the `Scope` root runs `cava -p scripts/cava/
    raw_output_config.txt` (50 bars, `;`-sep stdout) only while `mediaActive` →
    `visualizerPoints`. Downsampled to 22 **equalizer bars** (center-anchored
    Rectangles) — NOT the `WaveVisualizer` (user wanted bars).
  - Minimal media UI (reference-style): small album art · bars · play/pause. NO
    title/artist. Compact (~40px). `MprisController.activePlayer`.
  - `mediaActive = isPlaying` → pausing/no-playback collapses back to idle (user choice).
  - **Album-art flicker fix:** binding straight to `trackArtUrl` made art vanish when the
    player rewrote/cleared the URL. Fix = download to a stable local cache
    (`Directories.coverArt/Qt.md5(url)` via a curl `Process`) AND only clear `displayedArt`
    on an actual track change (`trackKey`=trackTitle), set only on curl exit 0. Persists.
- **2026-06-04 — Phase 4 notch brightness + notification.** Generalized to one
  `expandedSource` + shared hide-timer; reusable `OsdBar`/`OsdPercent`. NOTE: brightness
  only fires when changed THROUGH the shell service (`Brightness.brightnessChanged`;
  test via `qs -c openagentisland ipc call brightness increment`), and notifications
  CANNOT be tested in the nested session — the real `ii` already owns the
  `org.freedesktop.Notifications` D-Bus name, so the nested shell gets none. Both wired
  correctly; verify on real desktop.
- **2026-06-04 — Phase 3 notch idle + volume + the morphing framework.**
  - Top-attached notch: square top corners flush with screen edge, rounded bottom,
    concave `RoundCorner` shoulders (left=TopRight, right=TopLeft, overlap −1px) blending
    into the top edge. Borderless (a border drew seam lines). Window fixed at max size +
    `mask: Region{item:notch}` (click-through elsewhere) so size animates smoothly
    Qt-side (no janky per-frame compositor resize).
  - Goey morph: `easing.bezierCurve` from the reference's notch.css
    (`cubic-bezier(0.175,0.885,0.32,1.275)`), softened to **[0.34,1.22,0.64,1,1,1]**
    (1.275 made the open→idle shrink collapse violently; user still wanted bounce).
  - **Constant 18px bottom radius** (≤ idle-height/2 so Qt never clamps it) — animating
    the radius read as corners "rounding in", which the user rejected. idle height = 36.
  - Volume triggers off `Audio.sink.audio` VALUE (not `GlobalStates.osdVolumeOpen`).

- **2026-06-04 — Phase 2 RIGHT island + sidebar slide-in.**
  - `IslandRight.qml`: pills = stats (CPU/RAM/SWAP/battery as `CircularProgress` rings,
    hover → combined RAM/Swap/CPU/Battery tooltip) · tray (hidden when empty) ·
    perf-toggle + settings-gear · clock (12h `h:mm AP`, small) · circular power button.
    Smooth `Behavior on color` hovers on gear/perf/power.
  - `IslandPopup.qml` (new): hover tooltip anchored BELOW via `PopupWindow` (the bar's
    `StyledPopup` is hard-coded for the full-width bar → lands top-left on our island).
    Loader-based + keep-alive timer = crash-safe (an always-mapped PopupWindow triggered
    a Wayland popup protocol error → killed qs). Content passed as a `Component`
    (instantiated fresh inside; reparenting a shared Item rendered empty boxes). Slides
    in from the right + fades, both ways.
  - `IslandWorkspaces.qml`: fixed dispatch — end-4's `hl.dsp.focus({...})` is invalid in
    vanilla Hyprland ("Invalid dispatcher"); switched to standard `workspace N` / `e±1`.
  - `SidebarRight.qml`: top margin 44 (opens below the island strip) + slides in from the
    right screen edge (Translate on content, window kept mapped through slide-out).
  - Gotchas: brace-balance bugs are easy to misdiagnose because `${}` template literals
    and reload-race stale reads show contradictory errors — verify with a string/comment/
    template-aware brace counter, not `grep -c {`.

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

1. **Notch `open` (fully-expanded) state content** — the `open` state (click-toggled,
   480×300) currently has the shape/morph but NO content. Design + build what it shows
   (likely the agent view + media controls + a dashboard-ish surface). User wants to
   iterate on the expanded/open notch.
2. **Phase 6 — agent bridge (status only), safety-first.** Build `bridge/` (NOT created
   yet): Unix socket at `$XDG_RUNTIME_DIR/openagentisland.sock`, Claude Code hooks →
   socket, a listener → notch `agent` state. Build the timeout/failure-safety FIRST so a
   down/broken island can NEVER hang real Claude Code. Confirm `Quickshell.Io` 0.2.1
   socket support (or external daemon). See NOTES.md §4.
3. Phase 7 permission round-trip, Phase 8 multi-session + polish.

Dev: launch nested window with
`WLR_BACKENDS=wayland WLR_NO_HARDWARE_CURSORS=1 HYPRLAND_INSTANCE_SIGNATURE= Hyprland --config ~/.config/hypr-nested/hyprland.conf`

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

- **⚠ NESTED MONITOR NAME VARIES PER SESSION → broke scaling.** The nested output is
  sometimes `WL-1`, sometimes `WAYLAND-1` (changes after a laptop reboot). A
  `monitor=WL-1,...` line silently stops matching → nested falls back to scale 1.5 +
  letterboxed wallpaper. FIX (in `~/.config/hypr-nested/hyprland.conf`): use a wildcard
  `monitor=,preferred,auto,1.0` (empty name = all outputs). Monitor changes need a
  nested-session restart. Check actual name/scale with
  `HYPRLAND_INSTANCE_SIGNATURE=<sig> hyprctl monitors` (find the nested instance under
  `$XDG_RUNTIME_DIR/hypr/`).
- **ConflictKiller "Kill conflicting programs? kded6" dialog** appears in the nested
  session (`ConflictKiller.load()` in shell.qml). Click **No** — `kded6` is shared with
  the real desktop; killing it would break the real session's KDE integration.
- **Brace-balance is easy to misdiagnose:** `${...}` template literals contain `{`/`}`,
  so `grep -c '{'` lies. Use a string/comment/template-aware counter (a small python
  walker). Also, the reload race shows CONTRADICTORY stale errors ("Expected }" then
  "Unexpected }") from different in-flight file states — trust the LAST
  `Configuration Loaded` line, not transient errors.
- **`exclusiveZone` for "windows below the islands":** set
  `exclusionMode: ExclusionMode.Normal; exclusiveZone: 40` on the (top-anchored) notch
  to reserve the top strip so maximized windows don't get covered. Wallpaper (Background,
  layer Bottom, `ExclusionMode.Ignore`) still fills the whole screen.
- **Notifications can't be tested in the nested session** (real `ii` owns the D-Bus
  notification server). **Brightness** only triggers when changed through the shell
  service. Verify both on the real desktop. **Volume/media ARE testable** (shared
  PipeWire / MPRIS).
- **WaveVisualizer / any self-anchoring widget inside a Layout** → "anchors on an item
  managed by a layout" warning; wrap it in a plain `Item` with `Layout.preferredWidth/
  Height` and let the widget `anchors.fill: parent`.

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
