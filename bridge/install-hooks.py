#!/usr/bin/env python3
"""
Enable / disable the OpenAgentIsland bridge hooks in ~/.claude/settings.json.

Reversible and idempotent: enable adds (or refreshes) only our hook entries and
preserves everything else; disable removes only our entries. A timestamped
backup is written before any change. Our entries are identified by the command
containing "oai_hook.py".

Usage:
    python3 install-hooks.py enable     # turn the island on for ALL Claude sessions
    python3 install-hooks.py disable    # turn it off
    python3 install-hooks.py status     # show whether it's enabled
"""
import json
import os
import shutil
import sys
import time

SETTINGS = os.path.expanduser("~/.claude/settings.json")
# Resolve oai_hook.py next to this script, so the repo works wherever it's cloned.
HOOK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "oai_hook.py")

STATUS_EVENTS = ["SessionStart", "UserPromptSubmit", "PostToolUse", "Notification", "Stop", "SessionEnd"]
PERM_MATCHER = "Bash|Write|Edit|MultiEdit|NotebookEdit"


def status_entry():
    return {"matcher": "", "hooks": [
        {"type": "command", "command": f"python3 {HOOK} status", "timeout": 10}]}


def perm_entry():
    return {"matcher": PERM_MATCHER, "hooks": [
        {"type": "command",
         "command": f"OAI_PERMISSION_TIMEOUT=90 python3 {HOOK} permission",
         "timeout": 120}]}


def our_hooks():
    h = {ev: [status_entry()] for ev in STATUS_EVENTS}
    h["PreToolUse"] = [perm_entry()]
    return h


def is_ours(entry):
    return any("oai_hook.py" in hk.get("command", "") for hk in entry.get("hooks", []))


def load():
    if not os.path.exists(SETTINGS):
        return {}
    try:
        with open(SETTINGS) as f:
            return json.load(f)
    except Exception as e:
        print(f"ERROR: {SETTINGS} is not valid JSON ({e}). Refusing to touch it.")
        sys.exit(1)


def backup(orig_text):
    if os.path.exists(SETTINGS):
        b = f"{SETTINGS}.bak-{int(time.time())}"
        shutil.copy2(SETTINGS, b)
        print(f"backup: {b}")


def save(data):
    os.makedirs(os.path.dirname(SETTINGS), exist_ok=True)
    with open(SETTINGS, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")


def enable():
    s = load()
    backup(None)
    hooks = s.setdefault("hooks", {})
    for ev, entries in our_hooks().items():
        kept = [e for e in hooks.get(ev, []) if not is_ours(e)]
        hooks[ev] = kept + entries
    save(s)
    print("ENABLED — the island now sees all Claude Code sessions.")
    print("Status events are fire-and-forget; Bash/Write/Edit ask for approval via the notch.")


def disable():
    s = load()
    if "hooks" not in s:
        print("Already disabled (no hooks block).")
        return
    backup(None)
    for ev in list(s["hooks"].keys()):
        s["hooks"][ev] = [e for e in s["hooks"][ev] if not is_ours(e)]
        if not s["hooks"][ev]:
            del s["hooks"][ev]
    if not s["hooks"]:
        del s["hooks"]
    save(s)
    print("DISABLED — removed the island hooks; everything else preserved.")


def status():
    s = load()
    found = []
    for ev, entries in s.get("hooks", {}).items():
        for e in entries:
            if is_ours(e):
                found.append(ev)
    if found:
        print("ENABLED — island hooks active for:", ", ".join(sorted(set(found))))
    else:
        print("DISABLED — no island hooks in ~/.claude/settings.json")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "enable":
        enable()
    elif cmd == "disable":
        disable()
    else:
        status()
