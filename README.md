# OpenAgentIsland

A macOS-style **Dynamic Island desktop for Hyprland**, built in **Quickshell/QML** on top of the
[end-4 / illogical-impulse](https://github.com/end-4/dots-hyprland) framework.

Instead of a full-width bar, the desktop is **three floating islands** with the wallpaper breathing
through the gaps. The centerpiece is a **morphing notch**: a minimal clock when idle that expands for
volume, brightness, media (with an audio visualizer), notifications — and the headline feature:

> **Live Claude Code agent status, with permission Allow/Deny directly from the notch.**

When a Claude Code session asks to run a command or edit a file, the request appears in the island and
you approve or deny it without leaving your work — plus jump-to-terminal, multi-session tracking, and a
live view of each session's permission mode.

<!-- TODO: add screenshots / a short gif here -->

---

## What's novel here

The desktop chrome (bar→islands, OSDs, overview, dashboard, launcher) is built on end-4. The genuinely
new part is the **agent bridge**:

- **`bridge/`** — Claude Code hooks → a Unix socket → the island. Safety-first: if the island isn't
  listening or anything goes wrong, the hook falls back to Claude Code's normal prompt. It can **never
  hang or break** your real Claude Code.
- **The notch agent UI** — live status, an Allow / Allow-All / Bypass / Deny permission card, a session
  list, jump-to-terminal, and a live permission-mode indicator.

---

## Requirements

- **Hyprland** with the **end-4 / illogical-impulse** setup installed (this provides the Lua-based
  Hyprland config — `hl.dsp.*` dispatch — plus all the packages, fonts, services, and the Quickshell
  framework this builds on). Arch / Arch-based (CachyOS, EndeavourOS, …) is the smoothest path.
- **Quickshell** ≥ 0.2.1 (installed by the end-4 setup).
- **Python 3** (standard library only) — for the agent bridge.
- **[Claude Code](https://claude.com/claude-code)** — for the agent feature (optional; the desktop
  works fine without it).

---

## Install (this is the "set it up exactly like mine" guide)

### 1. Install the end-4 base first
Follow the official installer: <https://github.com/end-4/dots-hyprland>. This sets up Hyprland (with
the Lua config), Quickshell, and every dependency. Make sure that desktop boots and works on its own
before continuing.

### 2. Clone OpenAgentIsland into your Quickshell configs
```sh
git clone https://github.com/<your-user>/openagentisland.git ~/Projects/openagentisland
ln -s ~/Projects/openagentisland/quickshell ~/.config/quickshell/openagentisland
```
Quickshell only loads configs from `~/.config/quickshell/<name>/`, so the symlink points the
`openagentisland` config at the repo. (You can also clone straight into
`~/.config/quickshell/openagentisland` if you prefer no symlink.)

### 3. Switch your desktop to it
end-4 picks which Quickshell config to load from `~/.config/hypr/hyprland/variables.lua`. Change:
```lua
hl.env("qsConfig", "ii")              -- before
hl.env("qsConfig", "openagentisland") -- after
```
Then reload — log out and back in, or hot-swap without a relogin:
```sh
pkill -f "qs -c ii"; hyprctl dispatch exec "qs -c openagentisland"
```
You should now see the three floating islands instead of the bar. To go back, set `qsConfig` to `"ii"`.

### 4. (Optional) Enable the Claude Code agent feature
With Claude Code installed:
```sh
python3 ~/Projects/openagentisland/bridge/install-hooks.py enable
```
This merges **only** the OpenAgentIsland hooks into `~/.claude/settings.json` (backing it up first), and
auto-resolves paths so it works wherever you cloned the repo. Now start a `claude` session and watch the
notch: status events stream in, and `Bash` / `Write` / `Edit` requests pop a permission card you can
approve from the island.

- Turn it off again: `python3 bridge/install-hooks.py disable`
- Check status: `python3 bridge/install-hooks.py status`
- Prove the safety net (13 checks, no island required): `python3 bridge/test_safety.py`

---

## Notes & gotchas

- **Multi-monitor / scaled / rotated displays:** handled — every island renders per-monitor in *logical*
  coordinates. (Surfaces open only on the monitor you clicked.)
- **Lua-Hyprland dispatch:** this config uses the `hl.dsp.*` Lua dispatch API (the standard
  `dispatch "focuswindow …"` string silently no-ops on a Lua-config Hyprland). All island dispatches use
  the Lua form.
- **Single-process terminals (e.g. Warp):** all their windows share one PID, so jump-to-terminal
  focuses the right *window* by matching the title; it can't switch internal tabs.
- **Design / architecture** lives in `NOTES.md`; the running work log is in `PROGRESS.md`.

---

## Credits & license

- Built on **[end-4 / dots-hyprland (illogical-impulse)](https://github.com/end-4/dots-hyprland)** — GPL-3.0.
- Built with **[Quickshell](https://quickshell.outfoxxed.me/)**.
- Notch interaction techniques studied from **[Hyprfabricated](https://github.com/tr1xem/hyprfabricated)**
  (technique only — re-implemented in Quickshell/QML, no code copied).

This project is a derivative work of end-4 and is therefore released under the **GNU General Public
License v3.0** — see [`LICENSE`](./LICENSE). If you distribute it or a modified version, it must remain
GPL-3.0, keep these notices, and provide source.
