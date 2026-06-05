# AGENT_UI.md — notch agent surface design (from Vibe Island references)

Pixel-level reading of the reference shots, the state model, and the
notch-contention (song-vs-agent) solution. Backend already built & proven
(see NOTES §5 / `bridge/`). This doc drives the UI build.

## A. What the references show (per image)

- **Compact notch, working** (#50/#59/#61/#63): the notch in its strip form —
  `[animated pixel spinner] [status word…]`, optionally a count on the right.
  The spinner is **two small pixel-art glyphs** (a mascot-ish "invader" + a
  blocky loader) that animate frame-by-frame. **Colour encodes state:**
  - blue  → "Working…"            (#61)
  - green → project name (active) (#59 "vibeisl…")
  - purple→ "Compact…"            (#50, compaction)
  - orange→ project + a "?" glyph  (#60, needs you / permission)
  - orange ★ → "Ebbing…"          (#63, thinking — Claude's gerund words)
  The status word mirrors Claude Code's CLI spinner gerunds; we can't read the
  live word from hooks, so we DERIVE it from events (Working/Waiting/Done/…).
- **Compact notch, session count** (#51, #62): `[green mascot] vibeisl…  6 sessions`
  (or just `[mascot]  6`). So compact can summarise: project + N sessions.
- **Expanded session list** (#49, #53, #54): the notch opened into a panel of
  session rows. Each row:
  `[status dot/mascot]  [project · task-title]   [AgentChip][TerminalChip]  [time]`
  - status dot colours: green (active/ok), blue (running), …
  - chips: **agent** (Claude / Codex / Gemini) + **terminal** (iTerm / Terminal /
    Ghostty); time is relative (28m, 1h, 5h).
  - The **active/selected** row expands to show:
    `You: <the prompt>` (grey) and the **latest line / status**, e.g.
    `Done — click to jump` (green), or the assistant's reply
    (`Edward, I need to push back on this.` + an `★ Insight ──` block #57).
  - Header (#53): usage `Claude 5h 38% … | 7d 77% …` + speaker + gear (settings).
  - Footer: `Show all N sessions` (#56/#57/#58).
- **Single-session detail / done** (#56, #57): one card — mascot + green bar +
  `project · title` + chips + a **jump arrow**; body `You: …  [Done]` then the
  final line (`Done. hello.txt created at the project root.`). Green outline on
  the focused session.
- **Permission prompt** (#58, the headline): mascot turns **orange**, `⚠ Write`
  (warning + tool name), a **preview** box (`hello.txt  new file` + the content/
  diff lines), then a button row:
  `[Deny]  [Allow Once]  [Allow All]  [Bypass]`
  Deny = dark, Allow Once = light, Allow All = orange, Bypass = red.
  Below: `Show all 5 sessions`.
- **Bottom action dock** (#49): `Monitor · Approve · Ask · Jump` — the macOS
  app's global bar. We already have a notch; these map to: open list (Monitor),
  approve permission (Approve), reply/ask, focus terminal (Jump). Not a separate
  bar for us — they're actions inside the notch.

## B. Notch shape / tokens
Matches ours already: top-attached, concave shoulders, rounded bottom, opaque
near-black. Reuse `IslandStyle` + the existing morph. State colours to add:
`agentRunning` (green ~#7EE787), `agentWorking` (blue ~#7AA2F7), `agentAttention`
(orange ~#E8A23D), `agentCompact` (purple ~#B58AF8), `agentDanger` (red ~#E05561).

## C. The animated mascot/spinner
Confirmed (user's Claude-web chat #63): these are **CLI spinners** (ora /
cli-spinners / rich / halo) — frame animations. The pixel "invader" is a custom
mascot. Plan: a small **pixel-art frame animation** in QML (grid of Rectangles or
a tiny Canvas), cycling N frames at ~8–12fps, tinted by the state colour, plus a
second blocky loader glyph. Approximate the green invader mascot; exact sprite
optional.

## D. State model (per session) — maps to our AgentService
We already have: project, cwd, tool, summary, lastEvent, status, ts. Add/derive:
- `status`: `idle | working | waiting | permission | done` (from events:
  UserPromptSubmit/PreToolUse→working, Notification→waiting, permission_request→
  permission, Stop→done→idle).
- `prompt` (from UserPromptSubmit), `lastLine` (latest tool/assistant summary),
  `agent` = "Claude" (Claude-only first pass), `terminal` (best-effort/omit).
- For permission: `tool`, `preview` (Write→file+content; Edit→diff; Bash→command)
  — extend `permission_request` to carry a richer preview.

## E. NOTCH CONTENTION — the song-vs-agent prioritisation (the open question)

The notch is one slot. Sources: media (song), volume/brightness OSD, notification,
agent (working / needs-you). Key idea: separate **AMBIENT** (passive, ongoing:
media, agent-working) from **INTERRUPT** (actionable/transient: permission,
volume, notification). Interrupts briefly take the notch then release; among
ambient, when two want it at once we DON'T drop either — one owns the centre, the
other becomes a small persistent affordance.

**DECIDED — agent-forward.** Any active agent owns the notch; media yields to a
small side indicator while an agent is active. **Precedence (highest first):**
1. **Agent PERMISSION / needs-input** — full takeover + auto-expand, sticky until
   decided/timeout (orange mascot + "?", #58/#60).
2. **Volume / Brightness OSD** — transient (~2s) user-feedback → release back to
   whatever's below (agent or media).
3. **Notification** — transient (~4s) → release.
4. **Agent working** — owns the compact notch (`[spinner] Working…`). If media is
   also playing, the now-playing shows as a **small media glyph on the (right)
   shoulder** (informational; tapping the notch opens the agent list). Agent
   beats media here (agent-forward, per decision).
5. **Media** (no agent) → media owns the notch.
6. **Idle** — minimal clock / mascot + session count.

Most-urgent session drives the compact display (permission > working > idle) + a
session count. The song keeps *playing* throughout; only the notch *display* is
arbitrated.

Multiple sessions: compact shows the most-urgent session (permission > working >
idle) + count; expanded shows the full list.

## F. Build order (after design sign-off)
1. Extend AgentService status derivation + richer permission preview.
2. Animated mascot/spinner component (state-tinted frames).
3. Compact agent state in the notch (working/waiting/idle + count) + coexist-with-
   media side indicator.
4. `agent` open surface = session list (rows, active-row expand).
5. Permission prompt surface (tool + preview + buttons) — top precedence,
   wired to AgentService.allow/deny (+ Allow All / Bypass if in scope).
6. Wire precedence into IslandNotch; install hooks; test with a real session.

## G. Decisions (signed off)
1. **Prioritisation: agent-forward** (Section E) — any active agent owns the notch;
   media yields to a side indicator; permission is top + sticky.
2. **Permission buttons: all four** — Deny / Allow Once / Allow All / Bypass. The
   hook stays dumb (allow/deny only); the FOUR are island-side and set auto-rules:
   - Deny → decision `deny`.
   - Allow Once → decision `allow`.
   - Allow All → decision `allow` + remember `{session, tool}` → auto-allow future
     matching requests this session (no prompt).
   - Bypass → decision `allow` + remember `{session}` → auto-allow ALL tools this
     session. **Footgun** → needs a confirm/hold guard + clear red styling.
   Auto-rules live in AgentService: an incoming `permission_request` matching a
   rule is answered `allow` immediately (no UI).
3. **Mascot: faithful pixel-art**, state-tinted frame animation (+ blocky loader).
4. **Jump: skipped** for now (session→window mapping is fragile).
