# PROGRESS.md — OpenAgentIsland work log

Chronological log. Newest first within each section. Architecture/design rationale
lives in `NOTES.md`.

---

## Current phase & status

**FEATURE-COMPLETE; multi-monitor GO-LIVE BLOCKER — ROOT-CAUSED + FIXED in repo,
pending a real 3-monitor re-test (2026-06-07).** All features built + polished +
validated in the SINGLE-SCREEN nested dev window. The headline feature (live
Claude Code agent + permission Allow/Deny from the notch) is safety-proven (13/13,
never hangs Claude) and worked on a real `claude` session. The first real-desktop
switch (Path A) **blanked the scaled + rotated monitors**; root cause found and
fixed (below). User is still on `ii` (safe); **hooks DISABLED** until re-test.

### ✅ MULTI-MONITOR BLANKING — root cause found + fixed
**Symptom (Path A switch, 3 monitors):** only the main external monitor worked;
the laptop built-in and the vertical monitor went COMPLETELY BLANK (no wallpaper /
dock / islands), plus wrong sizing. Confirmed by photos + `monitors.lua`:
- `HDMI-A-1` 2560×1440 **scale 1.0, no transform** → logical == physical → **worked**.
- `eDP-1` 2880×1800 **scale 1.5** → logical 1920×1200 → **blank**.
- `DP-3` 1920×1080 **transform 1 (rotated)** → logical 1080×1920 → **blank**.

**Root cause:** `IslandNotch.qml` sized its PanelWindow with PHYSICAL pixels —
`implicitWidth: screen.width; implicitHeight: screen.height`. Layer-shell surfaces
use LOGICAL coords, so on any monitor with scale≠1 or a rotation the full-screen
Top-layer surface was oversized/mis-axed and **broke compositing for the whole
output** (everything on it went black, wallpaper included). The one scale-1.0,
unrotated monitor was the only one where physical==logical, so it alone rendered.
The notch was the SOLE violator — every other panel (Background, Dock, left/right
islands) is content-/edge-sized and survived; their disappearance on the dead
monitors was collateral from the broken output, not their own bug.

**Fix (commit pending):** anchor the notch window `top+left+right` (logical
full-width per monitor) + fixed `implicitHeight: maxHeight+60`; removed both
`screen.width/height`. `exclusiveZone` (40) still honored (anchored top + both
perpendicular edges). This matches the framework's `Background`/`Dock` pattern,
which is already proven on all 3 of the user's monitors under `ii`. Trade-off: the
outside-click-to-close catcher now covers the top ~460px instead of the full
screen (Esc / re-click the pill still close); fine since surfaces hang from the top.

**Re-test plan:** user re-switches Path A and checks ALL 3 monitors render
wallpaper + islands + dock; if a secondary monitor's wallpaper still looks
mis-scaled, that's a separate `Background` parallax tweak (also uses `screen.width`
in its zoom math) — but it renders fine under `ii`, so likely a non-issue.
Path-A switch + revert is one line:
`~/.config/hypr/hyprland/variables.lua` → `hl.env("qsConfig", "ii"/"openagentisland")`.

Toggle hooks for real Claude work (currently DISABLED):
  python3 ~/Projects/openagentisland/bridge/install-hooks.py enable|disable|status

---

## Done (newest first)

- **2026-06-06 — Phase 6+7 agent feature VALIDATED end-to-end (real Claude Code).**
  Ran a real `claude` session in `~/agent-island-test/` (project-level hooks,
  isolated from the dev session): notch showed SessionStart → Working… → the
  orange permission card with the real Write preview; approved from the island;
  Claude Code wrote hello.txt and continued. Full UI built + user-approved:
  AgentSpinner (4-frame running pixel mascot, state-tinted), AgentStatusText
  (shimmer + cycling dots, fixed width), compact State 2 (DI spread, fixed 224w,
  auto-collapse via 5s done-prune), AgentSurface State 3 (session list +
  permission card with write/edit/bash preview + Deny/Allow Once/Allow All/Bypass
  w/ 2-click confirm). Permission auto-opens the surface and auto-closes on
  resolve. Bugs fixed live: status string mismatch (running vs working), stale
  "permission" status after resolve/timeout (dropPending reverts to working).

- **2026-06-05 — Phase 6 agent bridge BACKEND (safety-first).** Built the riskiest
  piece first and proved it before any UI. `bridge/oai_hook.py` (Python — no
  socat/nc on this box) forwards Claude Code hook events to a unix socket; for
  PreToolUse it blocks for an Allow/Deny decision with a hard timeout. **Safety
  contract:** any failure (no socket / refused / timeout / frozen / exception) →
  exit 0, no stdout → Claude falls back to its normal prompt; never hangs, never
  auto-approves. `bridge/test_safety.py` proves it (13/13: down, allow, deny,
  frozen→bounded fallback, delivery). Quickshell side `services/AgentService.qml`
  hosts a `SocketServer`, keeps per-session status + a pending-permission queue,
  writes decisions back on the held connection, and drops a pending request if
  its connection closes (queue can't wedge). Verified END-TO-END through the real
  Quickshell listener: status events received with correct project/tool/summary;
  full allow + deny round-trip via the `agent` IPC target; disconnect cleanup.
  Gotchas: Quickshell `SocketServer.handler` is a `QQmlComponent` (one `Socket`
  per connection); `Socket` has `write()`/`flush()`/`connected`; new singleton
  needed a fresh `qs` start to register (imported-module quirk) — socket appeared
  after restart. Hooks documented but NOT yet wired into live `~/.claude/`.

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
