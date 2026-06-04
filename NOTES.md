# NOTES.md — OpenAgentIsland design & architecture

The "how it works and why" reference. Read this first to understand the project.
Stable-ish: update on architecture decisions, not every edit. Chronological work
log lives in `PROGRESS.md`.

---

## 1. Reference findings — Hyprfabricated (Fabric/Python+GTK)

Studied READ-ONLY in `~/Projects/island-reference/hyprfabricated/`. We translate the
*technique*, not the Python.

### 1.1 `modules/notch.py` — notch state model

**Key insight: Hyprfabricated's notch is NOT a width/height tween state machine.**
It's a **GTK `Stack`** that swaps full-size child widgets and *interpolates its own
size* to fit whichever child is showing. The "morph" is an emergent effect of:

```python
self.stack = Stack(name="notch-content", transition_type="crossfade",
                   transition_duration=250, children=[compact, launcher, dashboard,
                   overview, emoji, power, tools, tmux, cliphist])
self.stack.set_interpolate_size(True)   # <-- animates size between children
self.stack.set_homogeneous(False)       # <-- children keep their own size
```

Each child has an explicit fixed size (`set_size_request`), e.g. compact `260×40`,
dashboard `1093×472`, launcher `480×244`. Switching child → Stack animates from the
old size to the new size over 250 ms (crossfade). That's the whole morph.

**Composition (left / notch / right):** the notch window itself is a single
horizontal `CenterBox` (`notch-box`):
- `start_children = corner_left`  — a `MyCorner("top-right")` drawing the rounded
  notch shoulder on the left.
- `center_children = stack`       — the morphing content Stack.
- `end_children = corner_right`   — `MyCorner("top-left")` rounded shoulder on the right.

So Hyprfabricated's "left/right" pieces around the notch are just **decorative
rounded corners**, not functional islands. The functional left/right clusters
(workspaces, metrics, tray, clock) live in a *separate* full-width **bar**
(`modules/bar.py`), which our design discards. **We split the bar's clusters into two
independent floating islands** (`IslandLeft`, `IslandRight`) — a structural change,
not a port.

**Idle ("compact") state:** itself a nested `Stack` (`compact_stack`,
slide-up-down, 100 ms) cycling three children:
- `user_label` → `username@hostname`
- `active_window_box` → app icon + active window title (default visible child)
- `player_small` → tiny media widget

Triggers that switch the compact sub-state:
- **Scroll** on the compact area cycles the three children (`_on_compact_scroll`,
  250 ms debounce via `_scrolling` flag + timeout).
- MPRIS `player-appeared` → show `player_small`; `player-vanished` → back to
  `active_window_box`. **(Reactive to the actual player signal, not a UI flag.)**

**Show / hide (reveal):** a `Revealer` (`slide-down`, 250 ms) wraps the notch box.
Visibility is driven by **occlusion checking** (`utils/occlusion.py`): every 250 ms,
if the top 40 px of the screen is covered by a window AND the notch isn't hovered /
open / temporarily-pinned, the revealer collapses. On active-window-class change the
notch is briefly force-revealed for 500 ms (`on_active_window_changed` →
`_prevent_occlusion`). **Single window, no multi-monitor `Variants` — only renders on
one output. This is the gap we beat.**

**Open / expand:** `open_notch(widget_name)` sets keyboard mode exclusive, swaps the
Stack's visible child to the requested big widget (dashboard/launcher/etc.), and
toggles bar revealers. `close_notch()` returns to `compact`. Lots of
toggle-if-already-open logic; not relevant to our morph-OSD model.

### 1.2 `utils/animator.py` — tween technique

A hand-rolled `Animator` service: ticks a float `value` from `min_value`→`max_value`
across `duration` using a **cubic-bezier ease**, at ~60 fps (`GLib.timeout_add(16,…)`
or a widget tick callback), emitting `finished` at the end.

```python
def do_interpolate_cubic_bezier(self, t):           # only Y control points used
    y = (0, bezier[1], bezier[3], 1)
    return (1-t)**3*y[0] + 3*(1-t)**2*t*y[1] + 3*(1-t)*t**2*y[2] + t**3*y[3]
def do_ease(self, t):  return lerp(min, max, interp_cubic_bezier(t))
```

It only uses the Y components of the bezier (a simplified 1-D ease curve), lerps the
target range, and drives any float property (size, opacity).

**Quickshell equivalent is strictly simpler and better:** Qt has native bezier
easing, so we never reimplement a tick loop. Use:

```qml
Behavior on width  { NumberAnimation { duration: 400; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
// or the exact reference curve:
Behavior on height { NumberAnimation { duration: 350; easing.bezierCurve: [0.34,1.56,0.64,1, ...] } }
```

The "goey/spring" feel = `Easing.OutBack` with overshoot (or a custom bezier).

### 1.3 Fabric → Quickshell mapping table

| Hyprfabricated (Fabric/GTK) concept | Our Quickshell/QML equivalent |
|---|---|
| `Window(layer, anchor, margin, exclusivity)` | `PanelWindow { WlrLayershell.layer; anchors; margins; exclusiveZone }` |
| GTK `Stack` + `set_interpolate_size` (morph) | state property (`islandState`) driving `width/height` + `Behavior … NumberAnimation` |
| `Revealer` (slide-down show/hide) | `opacity`/`implicitHeight` driven by state + `Behavior`, or `Revealer` widget (`qs.modules.common.widgets`) |
| `utils/animator.py` cubic-bezier tween | native `easing.bezierCurve` / `Easing.OutBack` on `NumberAnimation` |
| `compact_stack` scroll-cycle of idle widgets | optional: `StackLayout`/state index, scroll handler on idle pill |
| `occlusion.py` + per-frame occlusion reveal | **dropped** — we float with gaps, always visible; multi-monitor via `Variants` |
| `MyCorner` rounded notch shoulders | `Rectangle { radius }` on the pill; optional `screenCorners` module already in end-4 |
| `ActiveWindow` formatter (win title) | end-4 `Hyprland`/`ActiveWindow.qml` already in `modules/ii/bar/` |
| `PlayerSmall` / `modules/player.py` | `MprisController` service + end-4 `mediaControls/` |
| `modules/metrics.py` (CPU/RAM/SWAP) | `ResourceUsage` service + `bar/Resources.qml` |
| `modules/cavalcade.py` (cava) | `scripts/cava` + end-4 cava in `mediaControls/` |
| `modules/bar.py` left/right clusters | split into `IslandLeft.qml` / `IslandRight.qml` |
| single-window notch (no multimon) | every island wrapped in `Variants { model: Quickshell.screens }` |

---

## 2. Architecture — three floating islands

**No full-width bar.** Three independent rounded `PanelWindow`s, transparent
background, always visible, on **every** monitor (each wrapped in
`Variants { model: Quickshell.screens; PanelWindow { required property var modelData; screen: modelData } }`).
Wallpaper breathes through the gaps.

```
┌─ IslandLeft ─┐        ┌──── IslandNotch ────┐        ┌─ IslandRight ─┐
│ workspaces · │        │  morphing OSD/clock │        │ cpu·clk·bat·  │
│ window title │        │  + AGENT status     │        │ tray·net·bt   │
└──────────────┘        └─────────────────────┘        └───────────────┘
        top-left                 top-center                    top-right
```

### 2.1 IslandLeft — `modules/ii/island/IslandLeft.qml`
Workspace dots (expand for active, Hyprfabricated-style) + active window title.
- Left-click → toggle `GlobalStates.sidebarLeftOpen`.
- Right-click workspaces → `GlobalStates.overviewOpen`.

### 2.2 IslandNotch — `modules/ii/island/IslandNotch.qml` (the star)
`property string islandState`. State machine:

| State | Content | Trigger | Exit |
|---|---|---|---|
| `idle` | minimal clock / small info (**NOT invisible**) | default | — |
| `volume` | volume icon + level bar | `Audio.sink.audio.volume` **value** change | ~2 s timer |
| `brightness` | brightness icon + level bar | `Brightness` value change | ~2 s timer |
| `media` | art + title + cava visualizer + controls | media playing (MPRIS) | media stops |
| `notification` | brief notification preview | incoming `Notifications` | short timer |
| `agent` | Claude session status; permission Allow/Deny | bridge socket event | session ends / decision made |

**Morph:** `implicitWidth`/`implicitHeight` reflect the active state so layout
reserves space; `Behavior on width/height` with `Easing.OutBack` overshoot for goey
spring. Content per state in a `Loader`/state-keyed visibility.

**State precedence (highest → lowest):**
`agent-permission` > `agent-status` > `media` > `volume`/`brightness` >
`notification` > `idle`. Implement as a computed `islandState` that picks the
highest-priority active source, not a free-for-all of timers stomping each other.

> Existing `IslandContent.qml` (prior session) has `idle` = *invisible* and triggers
> volume off `GlobalStates.osdVolumeOpen`. **Both must change** in Phase 3: idle =
> minimal clock; trigger off the `Audio` value (the flag flickers during scroll — see
> CLAUDE.md). Treat the existing file as a sketch, not the design.

### 2.3 IslandRight — `modules/ii/island/IslandRight.qml`
Left→right: Resources (CPU/RAM/SWAP via `ResourceUsage`) · clock · battery · system
tray · wifi/bt. Left-click → toggle `GlobalStates.sidebarRightOpen`. Keep ONLY the
performance toggle from `UtilButtons` (user removed keyboard/brightness/darkmode).

### 2.4 Bar removal
In `panelFamilies/IllogicalImpulseFamily.qml`: comment the full-width `Bar`
PanelLoader; add three island PanelLoaders. Keep ALL other panels (sidebars,
overview, lock, notifications, dock, screenCorners, polkit, etc.).

### 2.5 AS-BUILT details (Phases 1–5, user-approved)

**Shared style — `IslandStyle.qml` (singleton, `pragma Singleton` + `Singleton{}`, no
qmldir needed):** `margin 4`, `pillHeight 32`, `hPadding 10`, `radius full`,
`pillColor "#0B0B0E"` (solid space-black — NOT translucent `colLayer0`), `textColor
"#FFFFFF"`, `accent "#8AB4F8"`, `subtextColor`, `inactiveOpacity 0.45`. Every island
uses it.

**`IslandWorkspaces.qml` (left):** custom (NOT end-4 `Workspaces` — fixed slots can't do
the reference's uniform-gap look). A `Row` of dots; the CURRENT workspace is a capsule
the same height as the dots that EXPANDS and pushes neighbours apart (uniform gaps +
fluid). Used=white, unused=faint, current=blue. Dispatch = standard `workspace N` /
`workspace e±1` (end-4's `hl.dsp.focus` is INVALID in vanilla Hyprland).

**`IslandPopup.qml` (right-island tooltips):** the bar's `StyledPopup` is hard-coded to
the full-width bar → lands top-left on our island. So: a `PopupWindow` anchored BELOW
the hovered item (`anchor.window/item/edges:Bottom/gravity:Bottom`). Loader + keep-alive
timer (NOT always-mapped — an always-mapped PopupWindow triggered a Wayland popup
protocol error that CRASHED qs). Content passed as a `Component` (instantiated fresh
inside; reparenting a shared `Item` rendered empty boxes). Drive `shouldShow` from a
`HoverHandler` (composes over MouseAreas; the battery's tiny target + a competing base
MouseArea made plain MouseArea hover unreliable). Slide-in-from-right + fade.

**`IslandNotch.qml` (THE STAR) — top-attached morphing notch:**
- Hangs from top-center: square top corners flush with the screen edge, **rounded
  bottom**, concave `RoundCorner` shoulders (left=`TopRight`, right=`TopLeft`,
  `anchors.*Margin:-1` overlap) that blend it into the top edge. **Borderless** (a
  border drew seam lines).
- Window fixed at MAX size (`maxWidth+2*shoulder` × `maxHeight`); `mask: Region{item:
  notch}` so input passes through everywhere but the notch and the inner notch
  Rectangle animates size smoothly Qt-side (no janky per-frame compositor resize).
- **States:** `idle` (180×36 empty) · `expanded` (fits the active content) · `open`
  (480×300, click-toggled, NO content yet). `targetWidth`/`targetHeight`/`displaySource`
  computed by precedence.
- **Goey morph:** `Behavior on width/height { NumberAnimation { easing.bezierCurve:
  [0.34,1.22,0.64,1,1,1] } }` (reference was 1.275 → too violent on the shrink).
- **Constant 18px bottom radius** (≤ idle-height/2 so Qt never clamps) — animating it
  read as corners "rounding in", rejected. NO radius Behavior.
- **Reserves a 40px top strip** (`exclusionMode: Normal; exclusiveZone: 40`) so
  maximized windows open below the islands.
- **Sources & precedence** (computed `displaySource`): transient OSDs (volume /
  brightness / notification, one `expandedSource` + shared hide-timer, auto-hide) win
  over persistent **media**; `agent` (Phase 6) will be highest. Triggers use the service
  VALUE/signal, never the flicker-prone OSD flags.
- **Media:** shared cava `Process` at the `Scope` root → `visualizerPoints`, downsampled
  to 22 center-anchored **equalizer bars**. Minimal UI = art · bars · play/pause (no
  title). `mediaActive = isPlaying`. Album art downloaded to a stable local cache
  (`Directories.coverArt/Qt.md5(url)`) and only reset on track change (see PROGRESS
  gotcha — fixes the mid-song art vanish).

---

## 3. Quickshell / end-4 facts in use

- **Quickshell 0.2.1.** Panels = `PanelWindow` (Wayland layer-shell) wrapped in
  `Variants` for multi-monitor. Family = a `Scope` of `PanelLoader { component }` in
  `IllogicalImpulseFamily.qml`.
- **Panel module pattern:** folder `modules/ii/<name>/`, imported `qs.modules.ii.<name>`.
  Study `modules/ii/bar/` (ActiveWindow, Workspaces, Resources, SysTray, Media,
  BatteryIndicator, UtilButtons, ClockWidget) — most island content can be reused.
- **Theme tokens (always use, never hardcode):** `Appearance.colors.colLayer0/1/2`,
  `colOnLayer0/1/2`, `colLayer0Border`; `Appearance.rounding.windowRounding (18)` /
  `.full`; `Appearance.sizes.baseBarHeight (40)`; `Appearance.font.pixelSize.*`;
  `Appearance.animation.elementMoveFast.*`.
- **Widgets** (`qs.modules.common.widgets`): `StyledText`, `MaterialSymbol`,
  `RippleButton`, `Revealer`. Must import or "X is not a type".
- **Services (reuse):** `Audio` (`Audio.sink.audio.volume/.muted`), `Brightness`
  (`Brightness.getMonitorForScreen(screen)`), `MprisController`, `Notifications`
  (`.unread/.silent`), `Battery`, `Network`, `BluetoothStatus`, `ResourceUsage`,
  `TimerService`, `DateTime`.
- **GlobalStates** (`GlobalStates.qml`): `sidebarLeftOpen`, `sidebarRightOpen`,
  `osdVolumeOpen` (⚠ flickers on scroll — don't trigger notch from it), `overviewOpen`.
- **Hot reload** on `.qml` save; QML errors show a red panel with `file:line`.

---

## 4. Agent bridge design (Phases 6–8)

Live Claude Code session status in the notch, with Allow/Deny permission approval.
All bridge code in `~/Projects/openagentisland/bridge/` (hook scripts + listener).

### 4.1 Transport — Unix domain socket (mandated)
- Socket path: `$XDG_RUNTIME_DIR/openagentisland.sock`, fallback `/tmp/openagentisland.sock`.
- Claude Code **hooks** in `~/.claude/settings.json` fire on events and send one JSON
  line to the socket. A listener (Quickshell `Quickshell.Io` `Socket`/`SocketServer`,
  or a small helper process) reads lines → updates notch agent state.

### 4.2 Hook events → socket
`SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `Notification`,
`Stop`, plus the permission/approval event.

### 4.3 JSON schema (line-delimited, one object per message) — *draft, finalize in Phase 6*
```json
{
  "event": "PreToolUse",          // hook event name
  "session_id": "abc123",          // Claude session id (key for multi-session)
  "cwd": "/home/topg/Projects/x",  // project dir; notch shows basename
  "tool": "Bash",                  // tool name when relevant
  "message": "running tests",      // human summary / Notification text
  "needs_permission": false,        // true → blocking round-trip
  "request_id": "uuid",            // correlates a permission ask with its reply
  "ts": 0                           // epoch ms
}
```
Notch-side per-session state: `running | idle | waiting-for-input | waiting-for-permission`.

### 4.4 Blocking permission protocol
1. Permission hook writes a `needs_permission:true` message with a `request_id`,
   then **blocks reading the socket** for a reply.
2. Notch enters `agent`/permission state → shows request + Allow/Deny.
3. User click sends `{request_id, decision: "allow"|"deny"}` back over the socket.
4. Hook matches `request_id`, returns the matching **exit code** to Claude Code.

### 4.5 CRITICAL safety (build FIRST, in Phase 6)
A blocking hook can **hang real Claude Code** if the listener is down/crashed. Mandatory:
- **Timeout:** hook waits at most *N* seconds (e.g. 5–10 s); on timeout it falls back
  to Claude Code's **default** behavior (does not block, does not auto-allow unsafely).
- **Graceful absence:** if the socket doesn't exist / connect fails, the hook returns
  immediately with default behavior. Never block on a missing listener.
- **A broken island must NEVER make real Claude Code unusable.** Test this failure
  mode explicitly (listener down, listener crashes mid-wait, slow listener) before
  Phase 7 is "done".

### 4.6 Quickshell IO caveat
Confirm `Quickshell.Io` in 0.2.1 supports a listening socket + bidirectional writes.
If bidirectional/blocking is awkward from QML, a tiny external listener daemon
(socket server) that the QML side talks to via a simpler channel is the fallback —
**flag to the user before committing to an approach.**

### 4.7 Scope ramp
Claude Code only (not Codex/Gemini). One session status → permission approval →
multiple sessions (count / cycle / stack).

---

## 5. Key decisions & rationale

- **Morph via state-driven size + `Behavior`, not a GTK-Stack size-interpolate port.**
  Qt animates property changes natively; cleaner, no tick loop, exact-curve control.
- **Trigger volume/brightness from the *service value*, not `osdVolumeOpen`.** The flag
  flickers during scroll (CLAUDE.md); value changes are the real signal.
- **Split the reference bar into two floating islands.** Hyprfabricated keeps a
  full-width bar + decorative notch corners; our look is three independent islands
  with wallpaper gaps — a deliberate structural divergence.
- **Multi-monitor via `Variants` on every island.** Hyprfabricated renders the notch
  on one output only; `Variants { model: Quickshell.screens }` is our headline
  reliability win.
- **`islandState` is computed by precedence**, so higher-priority sources (agent
  permission) can't be stomped by a volume auto-hide timer.
- **Safety before features in the agent phase.** The timeout/fallback path is built
  and tested before any status rendering, so a broken island can never brick real
  Claude Code.
